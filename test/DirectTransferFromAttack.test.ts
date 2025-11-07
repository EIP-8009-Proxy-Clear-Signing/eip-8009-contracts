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

    // Pre-approve for this test (user approves proxy to spend tokens)
    await token.write.approve([balanceProxy.address, AMOUNT], {
      account: user.account,
    });

    // Call with useTransferFlags=false (approve mode)
    // In approve mode: proxy takes tokens from user, then approves target to spend them
    await balanceProxy.write.approveAndProxyCall(
      [
        [], // postBalances
        [
          {
            token: token.address,
            target: targetContract.address,
            balance: AMOUNT,
          },
        ], // approvals
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

    // Target allowance should still be set (target hasn't spent tokens yet)
    const allowance = await token.read.allowance([
      balanceProxy.address,
      targetContract.address,
    ]);
    expect(allowance).to.equal(AMOUNT); // Approval set for target
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
    await balanceProxy.write.approveAndProxyCall(
      [
        [], // postBalances
        [
          {
            token: token.address,
            target: targetContract.address,
            balance: AMOUNT,
          },
        ], // approvals
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

  it('✅ Should work with permitAndProxyCall and useTransferFlags=false (approve mode with permit)', async function () {
    const { user, balanceProxy, token, targetContract } =
      await loadFixture(deployFixture);

    const AMOUNT = parseEther('100');

    // Mint tokens to user
    await token.write.mint([user.account.address, AMOUNT]);

    // Get permit signature data
    const deadline = BigInt(Math.floor(Date.now() / 1000) + 3600); // 1 hour from now
    const nonce = await token.read.nonces([user.account.address]);

    // For this test, we'll use signTypedData to create a proper permit signature
    const domain = {
      name: await token.read.name(),
      version: '1',
      chainId: await user.getChainId(),
      verifyingContract: token.address,
    };

    const types = {
      Permit: [
        { name: 'owner', type: 'address' },
        { name: 'spender', type: 'address' },
        { name: 'value', type: 'uint256' },
        { name: 'nonce', type: 'uint256' },
        { name: 'deadline', type: 'uint256' },
      ],
    };

    const message = {
      owner: user.account.address,
      spender: balanceProxy.address,
      value: AMOUNT,
      nonce,
      deadline,
    };

    const signature = await user.signTypedData({
      domain,
      types,
      primaryType: 'Permit',
      message,
    });

    // Split signature into v, r, s
    const r = `0x${signature.slice(2, 66)}` as `0x${string}`;
    const s = `0x${signature.slice(66, 130)}` as `0x${string}`;
    const v = parseInt(signature.slice(130, 132), 16);

    // Call with permitAndProxyCall using real permit signature
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
            deadline,
            v,
            r,
            s,
          },
        ], // permits with real signature
        [false], // useTransferFlags = false (approve mode)
        targetContract.address, // target address
        '0x', // empty calldata
        [], // withdrawals
      ],
      {
        account: user.account,
      },
    );

    // Check: proxy should have the tokens
    const proxyBalance = await token.read.balanceOf([balanceProxy.address]);
    expect(proxyBalance).to.equal(AMOUNT);

    // User should have 0 tokens left
    const userBalance = await token.read.balanceOf([user.account.address]);
    expect(userBalance).to.equal(0n);

    // Target allowance should be set
    const allowance = await token.read.allowance([
      balanceProxy.address,
      targetContract.address,
    ]);
    expect(allowance).to.equal(AMOUNT);
  });

  it('✅ Should work with permitAndProxyCall and useTransferFlags=true (transfer mode with permit)', async function () {
    const { user, balanceProxy, token, targetContract } =
      await loadFixture(deployFixture);

    const AMOUNT = parseEther('100');

    // Mint tokens to user
    await token.write.mint([user.account.address, AMOUNT]);

    // Get permit signature data
    const deadline = BigInt(Math.floor(Date.now() / 1000) + 3600);
    const nonce = await token.read.nonces([user.account.address]);

    const domain = {
      name: await token.read.name(),
      version: '1',
      chainId: await user.getChainId(),
      verifyingContract: token.address,
    };

    const types = {
      Permit: [
        { name: 'owner', type: 'address' },
        { name: 'spender', type: 'address' },
        { name: 'value', type: 'uint256' },
        { name: 'nonce', type: 'uint256' },
        { name: 'deadline', type: 'uint256' },
      ],
    };

    const message = {
      owner: user.account.address,
      spender: balanceProxy.address,
      value: AMOUNT,
      nonce,
      deadline,
    };

    const signature = await user.signTypedData({
      domain,
      types,
      primaryType: 'Permit',
      message,
    });

    const r = `0x${signature.slice(2, 66)}` as `0x${string}`;
    const s = `0x${signature.slice(66, 130)}` as `0x${string}`;
    const v = parseInt(signature.slice(130, 132), 16);

    // Call with permitAndProxyCall using real permit signature
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
            deadline,
            v,
            r,
            s,
          },
        ], // permits with real signature
        [true], // useTransferFlags = true (transfer mode)
        targetContract.address, // target address
        '0x', // empty calldata
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
