import { loadFixture } from '@nomicfoundation/hardhat-toolbox-viem/network-helpers';
import { expect } from 'chai';
import { viem, ignition } from 'hardhat';
import { parseEther } from 'viem';

import BalanceProxyModule from '@/ignition/modules/balance-proxy';

describe('✅ BalanceProxy: Token Transfer Integration', function () {
  async function deployFixture() {
    const [owner, user] = await viem.getWalletClients();

    const { balanceProxy } = await ignition.deploy(BalanceProxyModule, {
      defaultSender: owner.account.address,
    });

    const token = await viem.deployContract('ERC20Mock', ['Test', 'TST'], {
      client: { wallet: owner },
    });

    const targetContract = await viem.deployContract(
      'TargetMock',
      [token.address],
      {
        client: { wallet: owner },
      },
    );

    return { owner, user, balanceProxy, token, targetContract };
  }

  it('✅ Should work with useTransferFlags=false (approve mode)', async function () {
    const { user, balanceProxy, token, targetContract } =
      await loadFixture(deployFixture);

    const AMOUNT = parseEther('100');

    // Mint tokens to user
    await token.write.mint([user.account.address, AMOUNT]);

    // Pre-approve for this test (simulating permit)
    await token.write.approve([balanceProxy.address, AMOUNT], {
      account: user.account,
    });

    // Call with useTransferFlags=false (approve mode)
    // In approve mode: proxy takes tokens from user, then approves target to spend them
    await balanceProxy.write.permitAndProxyCall(
      [
        [], // postBalances
        [
          {
            token: token.address,
            target: targetContract.address,
            balance: AMOUNT,
          },
        ], // approvals
        [
          {
            deadline: 0n,
            v: 0,
            r: '0x0000000000000000000000000000000000000000000000000000000000000000' as `0x${string}`,
            s: '0x0000000000000000000000000000000000000000000000000000000000000000' as `0x${string}`,
          },
        ], // permits (empty for pre-approved)
        [false], // useTransferFlags = false (approve mode)
        targetContract.address, // target address
        '0x', // empty calldata - just setup approval
        [], // withdrawals
      ],
      {
        account: user.account,
      },
    );

    // Check: proxy should have the tokens (pulled from user), and approval should be cleared
    const proxyBalance = await token.read.balanceOf([balanceProxy.address]);
    expect(proxyBalance).to.equal(AMOUNT); // Proxy holds tokens

    // User should have 0 tokens left (all transferred to proxy)
    const userBalance = await token.read.balanceOf([user.account.address]);
    expect(userBalance).to.equal(0n);

    // Target allowance should be 0 (cleared after call)
    const allowance = await token.read.allowance([
      balanceProxy.address,
      targetContract.address,
    ]);
    expect(allowance).to.equal(0n); // Approval cleared
  });

  it('✅ Should work with useTransferFlags=true (transfer mode)', async function () {
    const { user, balanceProxy, token, targetContract } =
      await loadFixture(deployFixture);

    const AMOUNT = parseEther('100');

    // Mint tokens to user
    await token.write.mint([user.account.address, AMOUNT]);

    // Pre-approve for this test
    await token.write.approve([balanceProxy.address, AMOUNT], {
      account: user.account,
    });

    // Call with useTransferFlags=true (transfer mode)
    // In transfer mode: proxy transfers tokens directly to target
    await balanceProxy.write.permitAndProxyCall(
      [
        [], // postBalances
        [
          {
            token: token.address,
            target: targetContract.address,
            balance: AMOUNT,
          },
        ], // approvals
        [
          {
            deadline: 0n,
            v: 0,
            r: '0x0000000000000000000000000000000000000000000000000000000000000000' as `0x${string}`,
            s: '0x0000000000000000000000000000000000000000000000000000000000000000' as `0x${string}`,
          },
        ], // permits (empty for pre-approved)
        [true], // useTransferFlags = true (transfer mode)
        targetContract.address, // target address
        '0x', // empty calldata - just transfer tokens
        [], // withdrawals
      ],
      {
        account: user.account,
      },
    );

    // Check that tokens were transferred directly to target
    const targetBalance = await token.read.balanceOf([targetContract.address]);
    expect(targetBalance).to.equal(AMOUNT);

    // User should have 0 tokens left
    const userBalance = await token.read.balanceOf([user.account.address]);
    expect(userBalance).to.equal(0n);
  });
});
