import { loadFixture } from '@nomicfoundation/hardhat-toolbox-viem/network-helpers';
import { expect } from 'chai';
import { viem, ignition } from 'hardhat';
import {
  type Address,
  encodeFunctionData,
  erc20Abi,
  parseEther,
  zeroAddress,
} from 'viem';

import BalanceProxyModule from '@/ignition/modules/balance-proxy';

const targetAbi = [
  {
    inputs: [
      {
        internalType: 'address',
        name: '_erc20',
        type: 'address',
      },
    ],
    stateMutability: 'nonpayable',
    type: 'constructor',
  },
  {
    inputs: [],
    name: 'erc20',
    outputs: [
      {
        internalType: 'contract ERC20Mock',
        name: '',
        type: 'address',
      },
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [
      {
        internalType: 'uint256',
        name: 'take',
        type: 'uint256',
      },
      {
        internalType: 'uint256',
        name: 'give',
        type: 'uint256',
      },
    ],
    name: 'mint',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [
      {
        internalType: 'uint256',
        name: 'take',
        type: 'uint256',
      },
      {
        internalType: 'uint256',
        name: 'give',
        type: 'uint256',
      },
    ],
    name: 'mintEth',
    outputs: [],
    stateMutability: 'payable',
    type: 'function',
  },
  {
    stateMutability: 'payable',
    type: 'receive',
  },
] as const;

async function deployFixture() {
  const [owner, other] = await viem.getWalletClients();

  // Deploy BalanceProxy using ignition
  const { balanceProxy } = await ignition.deploy(BalanceProxyModule, {
    defaultSender: owner.account.address,
  });

  // Deploy ERC20 using viem
  const erc20 = await viem.deployContract('ERC20Mock', ['MockToken', 'MTK'], {
    client: { wallet: owner },
  });

  const target = await viem.deployContract('TargetMock', [erc20.address], {
    client: { wallet: owner },
  });

  const testClient = await viem.getTestClient();
  const publicClient = await viem.getPublicClient();

  return {
    owner,
    other,
    balanceProxy,
    erc20,
    target,
    testClient,
    publicClient,
  };
}

const encodeTransfer = (to: Address, amount: bigint) => {
  return encodeFunctionData({
    abi: erc20Abi,
    functionName: 'transfer',
    args: [to, amount],
  });
};

const encodeMint = (take: bigint, give: bigint) => {
  return encodeFunctionData({
    abi: targetAbi,
    functionName: 'mint',
    args: [take, give],
  });
};

const encodeMintEth = (take: bigint, give: bigint) => {
  return encodeFunctionData({
    abi: targetAbi,
    functionName: 'mintEth',
    args: [take, give],
  });
};

// Helper to create empty permit data (for use with pre-approved tokens)
const createEmptyPermits = (count: number) => {
  return Array(count).fill({
    deadline: 0n,
    v: 0,
    r: '0x0000000000000000000000000000000000000000000000000000000000000000' as `0x${string}`,
    s: '0x0000000000000000000000000000000000000000000000000000000000000000' as `0x${string}`,
  });
};

describe('BalanceProxy', function () {
  it('should deploy and be callable', async function () {
    const { balanceProxy } = await loadFixture(deployFixture);
    expect(balanceProxy.address).to.be.a('string');
  });

  describe('approveAndProxyCall', function () {
    it('should call a target contract', async function () {
      const { balanceProxy, erc20, owner, other } =
        await loadFixture(deployFixture);

      const amount = parseEther('1');
      await erc20.write.mint([owner.account.address, amount]);
      await erc20.write.approve([balanceProxy.address, amount]);

      const data = encodeTransfer(other.account.address, amount);

      await balanceProxy.write.approveAndProxyCall([
        [],
        [
          {
            balance: amount,
            token: erc20.address,
            target: erc20.address,
          },
        ],
        [false], // useTransferFlags
        erc20.address,
        data,
        [],
      ]);

      const balance = await erc20.read.balanceOf([other.account.address]);
      expect(balance).to.equal(amount);
    });

    it('should transfer eth', async function () {
      const { balanceProxy, owner, other, publicClient } =
        await loadFixture(deployFixture);

      const balanceBeforeOwner = await publicClient.getBalance({
        address: owner.account.address,
      });
      const balanceBeforeOther = await publicClient.getBalance({
        address: other.account.address,
      });
      const gasCost = parseEther('0.1');
      const amount = parseEther('1');

      await balanceProxy.write.approveAndProxyCall(
        [
          [
            {
              token: zeroAddress,
              balance: balanceBeforeOwner - gasCost - amount,
              target: owner.account.address,
            },
            {
              token: zeroAddress,
              balance: balanceBeforeOther + amount,
              target: other.account.address,
            },
          ],
          [
            {
              token: zeroAddress,
              balance: amount,
              target: other.account.address,
            },
          ],
          [false], // useTransferFlags
          other.account.address,
          '0x00',
          [],
        ],
        { value: amount },
      );
    });

    it('should revert if target call fails', async function () {
      const { balanceProxy, erc20, owner, target, other } =
        await loadFixture(deployFixture);

      const amount = parseEther('1');
      await erc20.write.mint([owner.account.address, amount]);
      await erc20.write.approve([balanceProxy.address, amount]);

      const data = encodeTransfer(other.account.address, amount);

      await expect(
        balanceProxy.write.approveAndProxyCall([
          [],
          [
            {
              balance: amount,
              token: erc20.address,
              target: target.address,
            },
          ],
          [false], // useTransferFlags
          target.address,
          data,
          [],
        ]),
      ).rejectedWith('CallFailed');
    });

    it('should withdraw tokens', async function () {
      const { balanceProxy, erc20, owner, target, other } =
        await loadFixture(deployFixture);

      const amount = parseEther('1');
      await erc20.write.mint([owner.account.address, amount]);
      await erc20.write.approve([balanceProxy.address, amount]);

      const data = encodeMint(amount, amount * 2n);

      await balanceProxy.write.approveAndProxyCall([
        [
          {
            balance: amount * 2n,
            target: other.account.address,
            token: erc20.address,
          },
          {
            balance: 0n,
            target: owner.account.address,
            token: erc20.address,
          },
        ],
        [
          {
            balance: amount,
            target: target.address,
            token: erc20.address,
          },
        ],
        [false], // useTransferFlags
        target.address,
        data,
        [
          {
            balance: amount * 2n,
            target: other.account.address,
            token: erc20.address,
          },
        ],
      ]);
    });

    it('should withdraw eth', async function () {
      const { balanceProxy, erc20, owner, target, other, publicClient } =
        await loadFixture(deployFixture);

      const amount = parseEther('1');
      await erc20.write.mint([owner.account.address, amount]);
      await erc20.write.approve([balanceProxy.address, amount]);
      await owner.sendTransaction({ to: target.address, value: amount * 2n });

      const balanceBefore = await publicClient.getBalance({
        address: other.account.address,
      });

      const data = encodeMintEth(amount, amount * 2n);

      await balanceProxy.write.approveAndProxyCall([
        [
          {
            balance: balanceBefore + amount * 2n,
            target: other.account.address,
            token: zeroAddress,
          },
          {
            balance: 0n,
            target: owner.account.address,
            token: erc20.address,
          },
        ],
        [
          {
            balance: amount,
            target: target.address,
            token: erc20.address,
          },
        ],
        [false], // useTransferFlags
        target.address,
        data,
        [
          {
            balance: amount * 2n,
            target: other.account.address,
            token: zeroAddress,
          },
        ],
      ]);
    });
  });

  describe('approveAndProxyCallCalldata', function () {
    it('should call a target contract', async function () {
      const { balanceProxy, erc20, owner, other } =
        await loadFixture(deployFixture);

      const amount = parseEther('1');
      await erc20.write.mint([owner.account.address, amount]);
      await erc20.write.approve([balanceProxy.address, amount]);

      const data = encodeTransfer(other.account.address, amount);

      await balanceProxy.write.approveAndProxyCallCalldata([
        [],
        [
          {
            balance: amount,
            token: erc20.address,
            target: erc20.address,
          },
        ],
        [false], // useTransferFlags
        erc20.address,
        data,
        [],
      ]);

      const balance = await erc20.read.balanceOf([other.account.address]);
      expect(balance).to.equal(amount);
    });

    it('should transfer eth', async function () {
      const { balanceProxy, owner, other, publicClient } =
        await loadFixture(deployFixture);

      const balanceBeforeOwner = await publicClient.getBalance({
        address: owner.account.address,
      });
      const balanceBeforeOther = await publicClient.getBalance({
        address: other.account.address,
      });
      const gasCost = parseEther('0.1');
      const amount = parseEther('1');

      await balanceProxy.write.approveAndProxyCallCalldata(
        [
          [
            {
              token: zeroAddress,
              balance: balanceBeforeOwner - gasCost - amount,
              target: owner.account.address,
            },
            {
              token: zeroAddress,
              balance: balanceBeforeOther + amount,
              target: other.account.address,
            },
          ],
          [
            {
              token: zeroAddress,
              balance: amount,
              target: other.account.address,
            },
          ],
          [false], // useTransferFlags
          other.account.address,
          '0x00',
          [],
        ],
        { value: amount },
      );
    });

    it('should revert if target call fails', async function () {
      const { balanceProxy, erc20, owner, target, other } =
        await loadFixture(deployFixture);

      const amount = parseEther('1');
      await erc20.write.mint([owner.account.address, amount]);
      await erc20.write.approve([balanceProxy.address, amount]);

      const data = encodeTransfer(other.account.address, amount);

      await expect(
        balanceProxy.write.approveAndProxyCallCalldata([
          [],
          [
            {
              balance: amount,
              token: erc20.address,
              target: target.address,
            },
          ],
          [false], // useTransferFlags
          target.address,
          data,
          [],
        ]),
      ).rejectedWith('CallFailed');
    });

    it('should withdraw tokens', async function () {
      const { balanceProxy, erc20, owner, target, other } =
        await loadFixture(deployFixture);

      const amount = parseEther('1');
      await erc20.write.mint([owner.account.address, amount]);
      await erc20.write.approve([balanceProxy.address, amount]);

      const data = encodeMint(amount, amount * 2n);

      await balanceProxy.write.approveAndProxyCallCalldata([
        [
          {
            balance: amount * 2n,
            target: other.account.address,
            token: erc20.address,
          },
          {
            balance: 0n,
            target: owner.account.address,
            token: erc20.address,
          },
        ],
        [
          {
            balance: amount,
            target: target.address,
            token: erc20.address,
          },
        ],
        [false], // useTransferFlags
        target.address,
        data,
        [
          {
            balance: amount * 2n,
            target: other.account.address,
            token: erc20.address,
          },
        ],
      ]);
    });

    it('should withdraw eth', async function () {
      const { balanceProxy, erc20, owner, target, other, publicClient } =
        await loadFixture(deployFixture);

      const amount = parseEther('1');
      await erc20.write.mint([owner.account.address, amount]);
      await erc20.write.approve([balanceProxy.address, amount]);
      await owner.sendTransaction({ to: target.address, value: amount * 2n });

      const balanceBefore = await publicClient.getBalance({
        address: other.account.address,
      });

      const data = encodeMintEth(amount, amount * 2n);

      await balanceProxy.write.approveAndProxyCallCalldata([
        [
          {
            balance: balanceBefore + amount * 2n,
            target: other.account.address,
            token: zeroAddress,
          },
          {
            balance: 0n,
            target: owner.account.address,
            token: erc20.address,
          },
        ],
        [
          {
            balance: amount,
            target: target.address,
            token: erc20.address,
          },
        ],
        [false], // useTransferFlags
        target.address,
        data,
        [
          {
            balance: amount * 2n,
            target: other.account.address,
            token: zeroAddress,
          },
        ],
      ]);
    });
  });

  describe('permitAndProxyCallMetadata', function () {
    it('should fail if metadata symbol is wrong', async function () {
      const { balanceProxy, erc20, owner, other } =
        await loadFixture(deployFixture);

      const amount = parseEther('1');
      await erc20.write.mint([owner.account.address, amount]);
      await erc20.write.approve([balanceProxy.address, amount]);

      const data = encodeTransfer(other.account.address, amount);

      await expect(
        balanceProxy.write.permitAndProxyCallMetadata([
          [],
          [
            {
              balance: {
                balance: amount,
                target: other.account.address,
                token: erc20.address,
              },
              symbol: 'WRONG',
              decimals: 18,
            },
          ],
          createEmptyPermits(1),
          [false], // useTransferFlags
          erc20.address,
          data,
          [],
        ]),
      ).to.be.rejectedWith('InvalidMetadata');
    });

    it('should fail if metadata decimals is wrong', async function () {
      const { balanceProxy, erc20, owner, other } =
        await loadFixture(deployFixture);

      const amount = parseEther('1');
      await erc20.write.mint([owner.account.address, amount]);
      await erc20.write.approve([balanceProxy.address, amount]);

      const data = encodeTransfer(other.account.address, amount);

      await expect(
        balanceProxy.write.permitAndProxyCallMetadata([
          [],
          [
            {
              balance: {
                balance: amount,
                target: other.account.address,
                token: erc20.address,
              },
              symbol: 'MTK',
              decimals: 6,
            },
          ],
          createEmptyPermits(1),
          [false], // useTransferFlags
          erc20.address,
          data,
          [],
        ]),
      ).to.be.rejectedWith('InvalidMetadata');
    });
  });

  describe('permitAndProxyCallCalldata', function () {
    it('should transfer eth', async function () {
      const { balanceProxy, owner, other, publicClient } =
        await loadFixture(deployFixture);

      const balanceBeforeOwner = await publicClient.getBalance({
        address: owner.account.address,
      });
      const balanceBeforeOther = await publicClient.getBalance({
        address: other.account.address,
      });
      const gasCost = parseEther('0.1');
      const amount = parseEther('1');

      await balanceProxy.write.permitAndProxyCallCalldata(
        [
          [
            {
              token: zeroAddress,
              balance: balanceBeforeOwner - gasCost - amount,
              target: owner.account.address,
            },
            {
              token: zeroAddress,
              balance: balanceBeforeOther + amount,
              target: other.account.address,
            },
          ],
          [
            {
              token: zeroAddress,
              balance: amount,
              target: other.account.address,
            },
          ],
          createEmptyPermits(1), // Empty permit for 1 approval
          [false], // useTransferFlags
          other.account.address,
          '0x00',
          [],
        ],
        { value: amount },
      );
    });
  });

  describe('permitAndProxyCallMetadataCalldata', function () {
    it('should fail if metadata is wrong', async function () {
      const { balanceProxy, erc20, owner, other } =
        await loadFixture(deployFixture);

      const amount = parseEther('1');
      await erc20.write.mint([owner.account.address, amount]);
      await erc20.write.approve([balanceProxy.address, amount]);

      const data = encodeTransfer(other.account.address, amount);

      await expect(
        balanceProxy.write.permitAndProxyCallMetadataCalldata([
          [],
          [
            {
              balance: {
                balance: amount,
                target: other.account.address,
                token: erc20.address,
              },
              symbol: 'WRONG',
              decimals: 18,
            },
          ],
          createEmptyPermits(1),
          [false], // useTransferFlags
          erc20.address,
          data,
          [],
        ]),
      ).to.be.rejectedWith('InvalidMetadata');
    });

    it('should fail if metadata decimals is wrong', async function () {
      const { balanceProxy, erc20, owner, other } =
        await loadFixture(deployFixture);

      const amount = parseEther('1');
      await erc20.write.mint([owner.account.address, amount]);
      await erc20.write.approve([balanceProxy.address, amount]);

      const data = encodeTransfer(other.account.address, amount);

      await expect(
        balanceProxy.write.permitAndProxyCallMetadataCalldata([
          [],
          [
            {
              balance: {
                balance: amount,
                target: other.account.address,
                token: erc20.address,
              },
              symbol: 'MTK',
              decimals: 6,
            },
          ],
          createEmptyPermits(1),
          [false], // useTransferFlags
          erc20.address,
          data,
          [],
        ]),
      ).to.be.rejectedWith('InvalidMetadata');
    });
  });

  describe('Allowance Security', function () {
    it('should revert if allowance is insufficient (without permit)', async function () {
      const { balanceProxy, erc20, target, owner } =
        await loadFixture(deployFixture);

      const approvedAmount = parseEther('50');
      const requestedAmount = parseEther('100'); // More than approved!

      await erc20.write.mint([owner.account.address, requestedAmount]);

      // User approves only 50, but contract tries to take 100
      await erc20.write.approve([balanceProxy.address, approvedAmount]);

      const data = encodeMint(requestedAmount, requestedAmount);

      await expect(
        balanceProxy.write.approveAndProxyCall([
          [],
          [
            {
              balance: requestedAmount,
              target: target.address,
              token: erc20.address,
            },
          ],
          [false], // useTransferFlags
          target.address,
          data,
          [],
        ]),
      ).to.be.rejectedWith('InsufficientAllowance');
    });

    it('should succeed if allowance is sufficient (without permit)', async function () {
      const { balanceProxy, erc20, target, owner } =
        await loadFixture(deployFixture);

      const amount = parseEther('100');

      await erc20.write.mint([owner.account.address, amount]);

      await erc20.write.approve([balanceProxy.address, amount]);

      const data = encodeMint(amount, amount);

      await expect(
        balanceProxy.write.approveAndProxyCall([
          [],
          [
            {
              balance: amount,
              target: target.address,
              token: erc20.address,
            },
          ],
          [false],
          target.address,
          data,
          [],
        ]),
      ).to.not.be.rejected;
    });
  });
});
