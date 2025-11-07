import { loadFixture } from '@nomicfoundation/hardhat-toolbox-viem/network-helpers';
import { expect } from 'chai';
import { viem, ignition } from 'hardhat';
import { encodeFunctionData, erc20Abi, parseEther } from 'viem';

import BalanceProxyModule from '@/ignition/modules/balance-proxy';

// TargetMock ABI subset used for encoding
const targetAbi = [
  {
    inputs: [{ internalType: 'address', name: '_erc20', type: 'address' }],
    stateMutability: 'nonpayable',
    type: 'constructor',
  },
  {
    inputs: [
      { internalType: 'uint256', name: 'take', type: 'uint256' },
      { internalType: 'uint256', name: 'give', type: 'uint256' },
    ],
    name: 'mint',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [
      { internalType: 'uint256', name: 'take', type: 'uint256' },
      { internalType: 'uint256', name: 'give', type: 'uint256' },
    ],
    name: 'mintEth',
    outputs: [],
    stateMutability: 'payable',
    type: 'function',
  },
] as const;

function encodeMint(take: bigint, give: bigint) {
  return encodeFunctionData({
    abi: targetAbi,
    functionName: 'mint',
    args: [take, give],
  });
}

async function deployFixture() {
  const [owner, user, other] = await viem.getWalletClients();
  const { balanceProxy } = await ignition.deploy(BalanceProxyModule, {
    defaultSender: owner.account.address,
  });
  const token = await viem.deployContract('ERC20Mock', ['MockToken', 'MTK'], {
    client: { wallet: owner },
  });
  const target = await viem.deployContract('TargetMock', [token.address], {
    client: { wallet: owner },
  });
  const approveRouter = await viem.deployContract('ApproveRouter', [], {
    client: { wallet: owner },
  });
  const permitRouter = await viem.deployContract('PermitRouter', [], {
    client: { wallet: owner },
  });
  const publicClient = await viem.getPublicClient();
  return {
    owner,
    user,
    other,
    balanceProxy,
    token,
    target,
    approveRouter,
    permitRouter,
    publicClient,
  };
}

describe('BalanceProxy + Routers (updated API)', function () {
  this.timeout(120000);
  it('deploys core & routers', async () => {
    const { balanceProxy, approveRouter, permitRouter } =
      await loadFixture(deployFixture);
    expect(balanceProxy.address).to.be.a('string');
    expect(approveRouter.address).to.be.a('string');
    expect(permitRouter.address).to.be.a('string');
  });

  describe('ApproveRouter.approveProxyCall', () => {
    it('approve mode (useTransfer=false) sets allowance & retains balance', async () => {
      const { user, token, target, balanceProxy, approveRouter } =
        await loadFixture(deployFixture);
      const AMOUNT = parseEther('100');
      await token.write.mint([user.account.address, AMOUNT]);
      // user approves router (NOT proxy) to pull tokens
      await token.write.approve([approveRouter.address, AMOUNT], {
        account: user.account,
      });
      await approveRouter.write.approveProxyCall(
        [
          balanceProxy.address,
          [], // postBalances
          [
            {
              balance: {
                target: target.address,
                token: token.address,
                balance: AMOUNT,
              },
              useTransfer: false,
            },
          ],
          target.address,
          encodeMint(0n, 0n), // no mint action, just approval
          [],
        ],
        { account: user.account },
      );
      const proxyBal = await token.read.balanceOf([balanceProxy.address]);
      expect(proxyBal).to.equal(AMOUNT);
      const allowance = await token.read.allowance([
        balanceProxy.address,
        target.address,
      ]);
      expect(allowance).to.equal(AMOUNT);
    });

    it('transfer mode (useTransfer=true) moves tokens directly to target', async () => {
      const { user, token, target, balanceProxy, approveRouter } =
        await loadFixture(deployFixture);
      const AMOUNT = parseEther('50');
      await token.write.mint([user.account.address, AMOUNT]);
      await token.write.approve([approveRouter.address, AMOUNT], {
        account: user.account,
      });
      await approveRouter.write.approveProxyCall(
        [
          balanceProxy.address,
          [],
          [
            {
              balance: {
                target: target.address,
                token: token.address,
                balance: AMOUNT,
              },
              useTransfer: true,
            },
          ],
          target.address,
          '0x',
          [],
        ],
        { account: user.account },
      );
      const targetBal = await token.read.balanceOf([target.address]);
      expect(targetBal).to.equal(AMOUNT);
    });

    it('reverts when approval target != call target (MaliciousApproveTarget)', async () => {
      const { user, token, target, balanceProxy, approveRouter, other } =
        await loadFixture(deployFixture);
      const AMOUNT = parseEther('10');
      await token.write.mint([user.account.address, AMOUNT]);
      await token.write.approve([approveRouter.address, AMOUNT], {
        account: user.account,
      });
      await expect(
        approveRouter.write.approveProxyCall(
          [
            balanceProxy.address,
            [],
            [
              {
                balance: {
                  target: other.account.address,
                  token: token.address,
                  balance: AMOUNT,
                },
                useTransfer: false,
              },
            ],
            target.address, // call target differs from approval balance.target
            '0x',
            [],
          ],
          { account: user.account },
        ),
      ).to.be.rejectedWith('MaliciousApproveTarget');
    });

    it('reverts on insufficient allowance to router', async () => {
      const { user, token, target, balanceProxy, approveRouter } =
        await loadFixture(deployFixture);
      const NEED = parseEther('100');
      const HAVE = parseEther('40');
      await token.write.mint([user.account.address, NEED]);
      await token.write.approve([approveRouter.address, HAVE], {
        account: user.account,
      });
      await expect(
        approveRouter.write.approveProxyCall(
          [
            balanceProxy.address,
            [],
            [
              {
                balance: {
                  target: target.address,
                  token: token.address,
                  balance: NEED,
                },
                useTransfer: false,
              },
            ],
            target.address,
            '0x',
            [],
          ],
          { account: user.account },
        ),
      ).to.be.rejectedWith('ERC20InsufficientAllowance');
    });

    it('executes target call and withdraws tokens', async () => {
      const { user, token, target, balanceProxy, approveRouter, other } =
        await loadFixture(deployFixture);
      const TAKE = parseEther('10');
      const GIVE = parseEther('30');
      await token.write.mint([user.account.address, TAKE]);
      await token.write.approve([approveRouter.address, TAKE], {
        account: user.account,
      });
      await approveRouter.write.approveProxyCall(
        [
          balanceProxy.address,
          [
            { target: balanceProxy.address, token: token.address, balance: 0n }, // after withdraw expect zero
            {
              target: other.account.address,
              token: token.address,
              balance: GIVE,
            },
          ],
          [
            {
              balance: {
                target: target.address,
                token: token.address,
                balance: TAKE,
              },
              useTransfer: false,
            },
          ],
          target.address,
          encodeMint(TAKE, GIVE),
          [
            {
              target: other.account.address,
              token: token.address,
              balance: GIVE,
            },
          ],
        ],
        { account: user.account },
      );
      const otherBal = await token.read.balanceOf([other.account.address]);
      expect(otherBal).to.equal(GIVE);
    });
  });

  describe('PermitRouter.permitProxyCall', () => {
    // Narrow interfaces to avoid using `any`
    type PermitToken = {
      address: `0x${string}`;
      read: {
        name: () => Promise<string>;
        nonces: (args: [`0x${string}`]) => Promise<bigint>;
      };
    };
    type TestWallet = {
      account: { address: `0x${string}` };
      getChainId: () => Promise<number>;
      signTypedData: (args: {
        domain: {
          name: string;
          version: string;
          chainId: number;
          verifyingContract: `0x${string}`;
        };
        types: {
          Permit: Array<{ name: string; type: string }>;
        };
        primaryType: 'Permit';
        message: {
          owner: `0x${string}`;
          spender: `0x${string}`;
          value: bigint;
          nonce: bigint;
          deadline: bigint;
        };
      }) => Promise<`0x${string}`>; // viem wallet client signature helper
    };
    async function buildPermit(
      user: TestWallet,
      token: PermitToken,
      spender: `0x${string}`,
      value: bigint,
    ) {
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
        spender,
        value,
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
      return { deadline, v, r, s };
    }

    it('approve mode with permit pulls tokens & sets allowance', async () => {
      const { user, token, target, balanceProxy, permitRouter } =
        await loadFixture(deployFixture);
      const AMOUNT = parseEther('25');
      await token.write.mint([user.account.address, AMOUNT]);
      const permit = await buildPermit(
        user,
        token,
        permitRouter.address,
        AMOUNT,
      );
      await permitRouter.write.permitProxyCall(
        [
          balanceProxy.address,
          [],
          [
            {
              balance: {
                target: target.address,
                token: token.address,
                balance: AMOUNT,
              },
              useTransfer: false,
            },
          ],
          [permit],
          target.address,
          '0x',
          [],
        ],
        { account: user.account },
      );
      const proxyBal = await token.read.balanceOf([balanceProxy.address]);
      expect(proxyBal).to.equal(AMOUNT);
      const allowance = await token.read.allowance([
        balanceProxy.address,
        target.address,
      ]);
      expect(allowance).to.equal(AMOUNT);
    });

    it('transfer mode with permit moves tokens to target', async () => {
      const { user, token, target, balanceProxy, permitRouter } =
        await loadFixture(deployFixture);
      const AMOUNT = parseEther('40');
      await token.write.mint([user.account.address, AMOUNT]);
      const permit = await buildPermit(
        user,
        token,
        permitRouter.address,
        AMOUNT,
      );
      await permitRouter.write.permitProxyCall(
        [
          balanceProxy.address,
          [],
          [
            {
              balance: {
                target: target.address,
                token: token.address,
                balance: AMOUNT,
              },
              useTransfer: true,
            },
          ],
          [permit],
          target.address,
          '0x',
          [],
        ],
        { account: user.account },
      );
      const targetBal = await token.read.balanceOf([target.address]);
      expect(targetBal).to.equal(AMOUNT);
    });
  });

  describe('Error: CallFailed', () => {
    it('reverts when calling non-existent function on target', async () => {
      const { user, token, target, balanceProxy, approveRouter } =
        await loadFixture(deployFixture);
      const AMOUNT = parseEther('5');
      await token.write.mint([user.account.address, AMOUNT]);
      await token.write.approve([approveRouter.address, AMOUNT], {
        account: user.account,
      });
      // encode ERC20 transfer (target does not implement) => should revert
      const data = encodeFunctionData({
        abi: erc20Abi,
        functionName: 'transfer',
        args: [target.address, AMOUNT],
      });
      await expect(
        approveRouter.write.approveProxyCall(
          [
            balanceProxy.address,
            [],
            [
              {
                balance: {
                  target: target.address,
                  token: token.address,
                  balance: AMOUNT,
                },
                useTransfer: false,
              },
            ],
            target.address,
            data,
            [],
          ],
          { account: user.account },
        ),
      ).to.be.rejectedWith('CallFailed');
    });
  });

  describe('proxyCallDiffs via ApproveRouter', () => {
    it('checks expected diffs (positive balance increase)', async () => {
      const { user, token, target, balanceProxy, approveRouter } =
        await loadFixture(deployFixture);
      const TAKE = parseEther('10');
      const GIVE = parseEther('15');
      await token.write.mint([user.account.address, TAKE]);
      await token.write.approve([approveRouter.address, TAKE], {
        account: user.account,
      });
      // Expect proxy balance diff >= GIVE (after mint it receives GIVE tokens)
      await approveRouter.write.approveProxyCallDiffs(
        [
          balanceProxy.address,
          [
            {
              target: balanceProxy.address,
              token: token.address,
              balance: GIVE - TAKE, // net balance increase expected (GIVE - TAKE)
            },
          ],
          [
            {
              balance: {
                target: target.address,
                token: token.address,
                balance: TAKE,
              },
              useTransfer: false,
            },
          ],
          target.address,
          encodeMint(TAKE, GIVE),
          [],
        ],
        { account: user.account },
      );
      const bal = await token.read.balanceOf([balanceProxy.address]);
      expect(bal).to.equal(GIVE); // TAKE was spent, GIVE minted
    });
  });
});
