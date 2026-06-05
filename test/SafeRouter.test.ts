import { loadFixture } from '@nomicfoundation/hardhat-toolbox-viem/network-helpers';
import safeProxyArtifact from '@safe-global/safe-smart-account/build/artifacts/contracts/proxies/SafeProxy.sol/SafeProxy.json';
import safeArtifact from '@safe-global/safe-smart-account/build/artifacts/contracts/Safe.sol/Safe.json';
import { expect } from 'chai';
import { ignition, viem } from 'hardhat';
import {
  encodeFunctionData,
  padHex,
  parseEther,
  type Address,
  type Hex,
  zeroAddress,
} from 'viem';

import BalanceProxyModule from '@/ignition/modules/balance-proxy';

const ZERO_ADDRESS = zeroAddress;

const mintAbi = [
  {
    name: 'mint',
    type: 'function',
    inputs: [
      { type: 'uint256', name: 'take' },
      { type: 'uint256', name: 'give' },
    ],
    outputs: [],
    stateMutability: 'nonpayable',
  },
] as const;

const mintEthAbi = [
  {
    name: 'mintEth',
    type: 'function',
    inputs: [
      { type: 'uint256', name: 'take' },
      { type: 'uint256', name: 'give' },
    ],
    outputs: [],
    stateMutability: 'payable',
  },
] as const;

type SafeTx = {
  to: Address;
  value: bigint;
  data: Hex;
  operation: number;
  safeTxGas: bigint;
  baseGas: bigint;
  gasPrice: bigint;
  gasToken: Address;
  refundReceiver: Address;
  signatures: Hex;
  routerSigPosition: bigint;
};

function safeTx(params: {
  to: Address;
  data: Hex;
  value?: bigint;
  operation?: number;
  signatures?: Hex;
  routerSigPosition?: bigint;
  safeTxGas?: bigint;
  baseGas?: bigint;
  gasPrice?: bigint;
  gasToken?: Address;
  refundReceiver?: Address;
}): SafeTx {
  return {
    to: params.to,
    value: params.value ?? 0n,
    data: params.data,
    operation: params.operation ?? 0,
    safeTxGas: params.safeTxGas ?? 0n,
    baseGas: params.baseGas ?? 0n,
    gasPrice: params.gasPrice ?? 0n,
    gasToken: params.gasToken ?? ZERO_ADDRESS,
    refundReceiver: params.refundReceiver ?? ZERO_ADDRESS,
    signatures: params.signatures ?? '0x',
    routerSigPosition: params.routerSigPosition ?? 0n,
  };
}

function approvedHashSignature(owner: Address): Hex {
  return `${padHex(owner, { size: 32 })}${'0'.repeat(64)}01` as Hex;
}

function routerSignaturePosition(
  existingOwners: Address[],
  router: Address,
): bigint {
  const routerValue = BigInt(router);
  return BigInt(
    existingOwners.filter((owner) => BigInt(owner) < routerValue).length,
  );
}

function approvedHashSignatures(owners: Address[]): Hex {
  const sortedOwners = [...owners].sort((left, right) =>
    BigInt(left) < BigInt(right) ? -1 : 1,
  );
  return `0x${sortedOwners
    .map((owner) => approvedHashSignature(owner).slice(2))
    .join('')}` as Hex;
}

async function deployFixture() {
  const [owner, signer, executor, stranger] = await viem.getWalletClients();
  const publicClient = await viem.getPublicClient();

  const { balanceProxy } = await ignition.deploy(BalanceProxyModule, {
    defaultSender: owner.account.address,
  });

  const token = await viem.deployContract('ERC20Mock', ['MockToken', 'MTK']);
  const target = await viem.deployContract('TargetMock', [token.address]);
  const safe = await viem.deployContract('SafeMock', []);
  const safeRouter = await viem.deployContract('SafeRouter', []);

  await safe.write.addOwner([owner.account.address]);
  await safe.write.addOwner([safeRouter.address]);

  return {
    owner,
    signer,
    executor,
    stranger,
    publicClient,
    balanceProxy,
    token,
    target,
    safe,
    safeRouter,
  };
}

async function deployRealSafeFixture() {
  const base = await deployFixture();
  const { owner, signer, executor, publicClient, safeRouter } = base;

  const singletonHash = await owner.deployContract({
    abi: safeArtifact.abi,
    bytecode: safeArtifact.bytecode as Hex,
  });
  const singletonReceipt = await publicClient.waitForTransactionReceipt({
    hash: singletonHash,
  });
  if (!singletonReceipt.contractAddress) {
    throw new Error('Safe singleton deployment did not return an address');
  }

  const proxyHash = await owner.deployContract({
    abi: safeProxyArtifact.abi,
    bytecode: safeProxyArtifact.bytecode as Hex,
    args: [singletonReceipt.contractAddress],
  });
  const proxyReceipt = await publicClient.waitForTransactionReceipt({
    hash: proxyHash,
  });
  if (!proxyReceipt.contractAddress) {
    throw new Error('Safe proxy deployment did not return an address');
  }

  const realSafe = await viem.getContractAt(
    'ISafe',
    proxyReceipt.contractAddress,
  );

  await realSafe.write.setup(
    [
      [signer.account.address, executor.account.address, safeRouter.address],
      2n,
      ZERO_ADDRESS,
      '0x',
      ZERO_ADDRESS,
      ZERO_ADDRESS,
      0n,
      ZERO_ADDRESS,
    ],
    { account: owner.account },
  );

  return { ...base, realSafe };
}

describe('SafeRouter', function () {
  this.timeout(120_000);

  it('executes original tx via Safe then verifies post-balances via BalanceProxy', async () => {
    const { owner, balanceProxy, token, target, safe, safeRouter } =
      await loadFixture(deployFixture);

    const GIVE = parseEther('100');
    const swapData = encodeFunctionData({
      abi: mintAbi,
      functionName: 'mint',
      args: [0n, GIVE],
    });

    await safeRouter.write.safeExecuteWithPostBalances(
      [
        balanceProxy.address,
        safe.address,
        [{ target: safe.address, token: token.address, balance: GIVE }],
        safeTx({ to: target.address, data: swapData }),
      ],
      { account: owner.account },
    );

    expect(await token.read.balanceOf([safe.address])).to.equal(GIVE);
  });

  it('executes original tx via Safe then verifies balance diffs for that tx', async () => {
    const { owner, balanceProxy, token, target, safe, safeRouter } =
      await loadFixture(deployFixture);

    const GIVE = parseEther('25');
    const swapData = encodeFunctionData({
      abi: mintAbi,
      functionName: 'mint',
      args: [0n, GIVE],
    });

    await safeRouter.write.safeExecuteWithDiffs(
      [
        balanceProxy.address,
        safe.address,
        [{ target: safe.address, token: token.address, balance: GIVE }],
        safeTx({ to: target.address, data: swapData }),
      ],
      { account: owner.account },
    );

    expect(await token.read.balanceOf([safe.address])).to.equal(GIVE);
  });

  it('executes ETH flow: Safe receives ETH, BalanceProxy verifies post-balance', async () => {
    const { owner, balanceProxy, publicClient, target, safe, safeRouter } =
      await loadFixture(deployFixture);

    const GIVE_ETH = parseEther('2');
    await owner.sendTransaction({ to: target.address, value: GIVE_ETH });

    const swapData = encodeFunctionData({
      abi: mintEthAbi,
      functionName: 'mintEth',
      args: [0n, GIVE_ETH],
    });

    await safeRouter.write.safeExecuteWithPostBalances(
      [
        balanceProxy.address,
        safe.address,
        [{ target: safe.address, token: ZERO_ADDRESS, balance: GIVE_ETH }],
        safeTx({ to: target.address, data: swapData }),
      ],
      { account: owner.account },
    );

    expect(await publicClient.getBalance({ address: safe.address })).to.equal(
      GIVE_ETH,
    );
  });

  it('reverts and rolls back original tx when post-balance check fails', async () => {
    const { owner, balanceProxy, token, target, safe, safeRouter } =
      await loadFixture(deployFixture);

    const GIVE = parseEther('100');
    const swapData = encodeFunctionData({
      abi: mintAbi,
      functionName: 'mint',
      args: [0n, GIVE],
    });

    await expect(
      safeRouter.write.safeExecuteWithPostBalances(
        [
          balanceProxy.address,
          safe.address,
          [{ target: safe.address, token: token.address, balance: GIVE + 1n }],
          safeTx({ to: target.address, data: swapData }),
        ],
        { account: owner.account },
      ),
    ).to.be.rejectedWith('ERC8009BalanceConstraintViolation');

    expect(await token.read.balanceOf([safe.address])).to.equal(0n);
  });

  it('reverts and rolls back original tx when diff check fails', async () => {
    const { owner, balanceProxy, token, target, safe, safeRouter } =
      await loadFixture(deployFixture);

    const GIVE = parseEther('100');
    const swapData = encodeFunctionData({
      abi: mintAbi,
      functionName: 'mint',
      args: [0n, GIVE],
    });

    await expect(
      safeRouter.write.safeExecuteWithDiffs(
        [
          balanceProxy.address,
          safe.address,
          [{ target: safe.address, token: token.address, balance: GIVE + 1n }],
          safeTx({ to: target.address, data: swapData }),
        ],
        { account: owner.account },
      ),
    ).to.be.rejectedWith('ERC8009BalanceDiffConstraintViolation');

    expect(await token.read.balanceOf([safe.address])).to.equal(0n);
  });

  it('reverts with NotSafeOwner when caller is not a Safe owner', async () => {
    const { stranger, balanceProxy, token, target, safe, safeRouter } =
      await loadFixture(deployFixture);

    const swapData = encodeFunctionData({
      abi: mintAbi,
      functionName: 'mint',
      args: [0n, parseEther('1')],
    });

    await expect(
      safeRouter.write.safeExecuteWithPostBalances(
        [
          balanceProxy.address,
          safe.address,
          [
            {
              target: safe.address,
              token: token.address,
              balance: parseEther('1'),
            },
          ],
          safeTx({ to: target.address, data: swapData }),
        ],
        { account: stranger.account },
      ),
    ).to.be.rejectedWith('NotSafeOwner');
  });

  it('reverts with RouterNotSafeOwner when Safe did not install the router owner', async () => {
    const { owner, token, target, balanceProxy } =
      await loadFixture(deployFixture);
    const safeWithoutRouter = await viem.deployContract('SafeMock', []);
    const safeRouter = await viem.deployContract('SafeRouter', []);
    await safeWithoutRouter.write.addOwner([owner.account.address]);

    const swapData = encodeFunctionData({
      abi: mintAbi,
      functionName: 'mint',
      args: [0n, parseEther('1')],
    });

    await expect(
      safeRouter.write.safeExecuteWithPostBalances(
        [
          balanceProxy.address,
          safeWithoutRouter.address,
          [
            {
              target: safeWithoutRouter.address,
              token: token.address,
              balance: parseEther('1'),
            },
          ],
          safeTx({ to: target.address, data: swapData }),
        ],
        { account: owner.account },
      ),
    ).to.be.rejectedWith('RouterNotSafeOwner');
  });

  it('reverts before Safe execution when existing signatures plus router cannot meet threshold', async () => {
    const { owner, balanceProxy, token, target, safe, safeRouter } =
      await loadFixture(deployFixture);
    await safe.write.setThreshold([2n]);

    const swapData = encodeFunctionData({
      abi: mintAbi,
      functionName: 'mint',
      args: [0n, parseEther('1')],
    });

    await expect(
      safeRouter.write.safeExecuteWithPostBalances(
        [
          balanceProxy.address,
          safe.address,
          [
            {
              target: safe.address,
              token: token.address,
              balance: parseEther('1'),
            },
          ],
          safeTx({ to: target.address, data: swapData }),
        ],
        { account: owner.account },
      ),
    ).to.be.rejectedWith('InsufficientSafeSignatures');
  });

  it('reverts before Safe execution when operation is not Call', async () => {
    const { owner, balanceProxy, token, target, safe, safeRouter } =
      await loadFixture(deployFixture);

    const GIVE = parseEther('1');
    const swapData = encodeFunctionData({
      abi: mintAbi,
      functionName: 'mint',
      args: [0n, GIVE],
    });

    await expect(
      safeRouter.write.safeExecuteWithPostBalances(
        [
          balanceProxy.address,
          safe.address,
          [{ target: safe.address, token: token.address, balance: GIVE }],
          safeTx({ to: target.address, data: swapData, operation: 1 }),
        ],
        { account: owner.account },
      ),
    ).to.be.rejectedWith('UnsupportedSafeOperation');

    expect(await token.read.balanceOf([safe.address])).to.equal(0n);
  });

  it('validates metadata, executes tx, verifies via BalanceProxy', async () => {
    const { owner, balanceProxy, token, target, safe, safeRouter } =
      await loadFixture(deployFixture);

    const GIVE = parseEther('50');
    const swapData = encodeFunctionData({
      abi: mintAbi,
      functionName: 'mint',
      args: [0n, GIVE],
    });

    await safeRouter.write.safeExecuteWithPostBalancesMeta(
      [
        balanceProxy.address,
        safe.address,
        [{ symbol: 'MTK', decimals: 18 }],
        [{ target: safe.address, token: token.address, balance: GIVE }],
        safeTx({ to: target.address, data: swapData }),
      ],
      { account: owner.account },
    );

    expect(await token.read.balanceOf([safe.address])).to.equal(GIVE);
  });

  it('reverts with InvalidMetadata on symbol mismatch', async () => {
    const { owner, balanceProxy, token, target, safe, safeRouter } =
      await loadFixture(deployFixture);

    const swapData = encodeFunctionData({
      abi: mintAbi,
      functionName: 'mint',
      args: [0n, parseEther('1')],
    });

    await expect(
      safeRouter.write.safeExecuteWithPostBalancesMeta(
        [
          balanceProxy.address,
          safe.address,
          [{ symbol: 'WRONG', decimals: 18 }],
          [
            {
              target: safe.address,
              token: token.address,
              balance: parseEther('1'),
            },
          ],
          safeTx({ to: target.address, data: swapData }),
        ],
        { account: owner.account },
      ),
    ).to.be.rejectedWith('InvalidMetadata');
  });

  it('reverts with InvalidMetadata on decimals mismatch', async () => {
    const { owner, balanceProxy, token, target, safe, safeRouter } =
      await loadFixture(deployFixture);

    const swapData = encodeFunctionData({
      abi: mintAbi,
      functionName: 'mint',
      args: [0n, parseEther('1')],
    });

    await expect(
      safeRouter.write.safeExecuteWithPostBalancesMeta(
        [
          balanceProxy.address,
          safe.address,
          [{ symbol: 'MTK', decimals: 6 }],
          [
            {
              target: safe.address,
              token: token.address,
              balance: parseEther('1'),
            },
          ],
          safeTx({ to: target.address, data: swapData }),
        ],
        { account: owner.account },
      ),
    ).to.be.rejectedWith('InvalidMetadata');
  });

  it('ETH metadata flow via BalanceProxy skip', async () => {
    const { owner, balanceProxy, publicClient, target, safe, safeRouter } =
      await loadFixture(deployFixture);

    const GIVE_ETH = parseEther('1');
    await owner.sendTransaction({ to: target.address, value: GIVE_ETH });

    const swapData = encodeFunctionData({
      abi: mintEthAbi,
      functionName: 'mintEth',
      args: [0n, GIVE_ETH],
    });

    await safeRouter.write.safeExecuteWithPostBalancesMeta(
      [
        balanceProxy.address,
        safe.address,
        [{ symbol: 'ETH', decimals: 18 }],
        [{ target: safe.address, token: ZERO_ADDRESS, balance: GIVE_ETH }],
        safeTx({ to: target.address, data: swapData }),
      ],
      { account: owner.account },
    );

    expect(await publicClient.getBalance({ address: safe.address })).to.equal(
      GIVE_ETH,
    );
  });

  it('executes through the real Safe using one human approval plus the router owner slot', async () => {
    const {
      signer,
      executor,
      balanceProxy,
      token,
      target,
      safeRouter,
      realSafe,
    } = await loadFixture(deployRealSafeFixture);

    const GIVE = parseEther('77');
    const swapData = encodeFunctionData({
      abi: mintAbi,
      functionName: 'mint',
      args: [0n, GIVE],
    });
    const nonce = await realSafe.read.nonce();
    const safeTxHash = await realSafe.read.getTransactionHash([
      target.address,
      0n,
      swapData,
      0,
      0n,
      0n,
      0n,
      ZERO_ADDRESS,
      ZERO_ADDRESS,
      nonce,
    ]);

    await realSafe.write.approveHash([safeTxHash], {
      account: signer.account,
    });

    await safeRouter.write.safeExecuteWithDiffs(
      [
        balanceProxy.address,
        realSafe.address,
        [{ target: realSafe.address, token: token.address, balance: GIVE }],
        safeTx({
          to: target.address,
          data: swapData,
          signatures: approvedHashSignature(signer.account.address),
          routerSigPosition: routerSignaturePosition(
            [signer.account.address],
            safeRouter.address,
          ),
        }),
      ],
      { account: executor.account },
    );

    expect(await token.read.balanceOf([realSafe.address])).to.equal(GIVE);
    expect(await realSafe.read.nonce()).to.equal(nonce + 1n);
  });

  it('allows execution when the human threshold was already satisfied before wrapping', async () => {
    const {
      signer,
      executor,
      balanceProxy,
      token,
      target,
      safeRouter,
      realSafe,
    } = await loadFixture(deployRealSafeFixture);

    const GIVE = parseEther('33');
    const swapData = encodeFunctionData({
      abi: mintAbi,
      functionName: 'mint',
      args: [0n, GIVE],
    });
    const nonce = await realSafe.read.nonce();
    const safeTxHash = await realSafe.read.getTransactionHash([
      target.address,
      0n,
      swapData,
      0,
      0n,
      0n,
      0n,
      ZERO_ADDRESS,
      ZERO_ADDRESS,
      nonce,
    ]);

    await realSafe.write.approveHash([safeTxHash], {
      account: signer.account,
    });
    await realSafe.write.approveHash([safeTxHash], {
      account: executor.account,
    });

    const humanOwners = [signer.account.address, executor.account.address];
    await safeRouter.write.safeExecuteWithDiffs(
      [
        balanceProxy.address,
        realSafe.address,
        [{ target: realSafe.address, token: token.address, balance: GIVE }],
        safeTx({
          to: target.address,
          data: swapData,
          signatures: approvedHashSignatures(humanOwners),
          routerSigPosition: routerSignaturePosition(
            humanOwners,
            safeRouter.address,
          ),
        }),
      ],
      { account: executor.account },
    );

    expect(await token.read.balanceOf([realSafe.address])).to.equal(GIVE);
    expect(await realSafe.read.nonce()).to.equal(nonce + 1n);
  });
});
