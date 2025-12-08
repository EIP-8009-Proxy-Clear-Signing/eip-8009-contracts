# EIP-8009: Clear Signing Proxy Contracts

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Hardhat](https://img.shields.io/badge/Built%20with-Hardhat-FFDB1C.svg)](https://hardhat.org/)
[![Solidity](https://img.shields.io/badge/Solidity-0.8.27-e6e6e6?logo=solidity)](https://soliditylang.org/)

> **Stateless, singleton contracts for transparent transaction execution with user-defined balance constraints.**

## Overview

EIP-8009 introduces a proxy system that enables **clear signing** - users can verify exactly what tokens they'll spend and receive before signing a transaction. The system consists of three core contracts working together to provide secure, transparent, and user-friendly transaction execution.

### What Problem Does This Solve?

Traditional blockchain transactions are opaque:
- ❌ Users can't see final balance changes before signing
- ❌ Complex DeFi interactions hide actual outcomes
- ❌ Slippage and MEV can cause unexpected losses
- ❌ Users must trust dApp UIs for transaction details

**EIP-8009 Solution**:
- ✅ **Explicit Balance Constraints**: Users define minimum acceptable outcomes
- ✅ **Transparent Execution**: Transactions revert if constraints aren't met
- ✅ **Universal Compatibility**: Works with any smart contract
- ✅ **Stateless & Permissionless**: No stored state, no admin keys, multi-user safe

## Architecture

### Three-Contract System

**Execution Flow:**

1. **USER** signs transaction with balance constraints
   
2. **Router Selection** (choose one):
   - **PermitRouter**: Accepts EIP-2612 permit signatures (gasless approval)
   - **ApproveRouter**: Uses standard ERC-20 pre-approvals
   
3. **Token Transfer**: Router pulls tokens from user to BalanceProxy

4. **BalanceProxy** (Core execution engine):
   - Manages token approvals for target contract
   - Executes the target contract call
   - Validates balance constraints
   
5. **Target Contract**: Executes the actual operation (swap, transfer, etc.)

6. **Balance Validation**: BalanceProxy checks post-execution balances

7. **Result**: Transaction succeeds if all constraints are met, reverts otherwise

### Contract Responsibilities

#### 1️⃣ **BalanceProxy** (Core)
The stateless execution engine that:
- Manages approvals (approve target OR transfer to target)
- Executes target contract calls
- Validates balance constraints (absolute OR diffs)
- Handles post-execution withdrawals
- **Never pulls tokens** - only uses its own balance

**Key Methods**:
- `proxyCall()` - Execute with absolute post-balance checks
- `proxyCallDiffs()` - Execute with balance difference checks
- `proxyCallMeta()` / `proxyCallDiffsMeta()` - Metadata-enhanced versions

#### 2️⃣ **PermitRouter** (Gasless Approvals)
Handles EIP-2612 permit-based token approvals:
- Accepts off-chain permit signatures
- Pulls tokens from user to BalanceProxy
- Single transaction (approve + execute combined)
- **Best UX**: No separate approval transaction

**Key Methods**:
- `permitProxyCall()` - With absolute balances
- `permitProxyCallDiffs()` - With balance diffs
- `permitProxyCallWithMeta()` / `permitProxyCallDiffsWithMeta()` - With UI metadata

#### 3️⃣ **ApproveRouter** (Traditional Approvals)
Handles standard ERC-20 approvals:
- Uses pre-approved token allowances
- Pulls tokens from user to BalanceProxy
- Two-transaction flow (approve first, then execute)
- **Universal**: Works with all ERC-20 tokens

**Key Methods**:
- `approveProxyCall()` - With absolute balances
- `approveProxyCallDiffs()` - With balance diffs
- `approveProxyCallWithMeta()` / `approveProxyCallDiffsWithMeta()` - With UI metadata

## Key Concepts

### Balance Validation Modes

#### Absolute Balances (`proxyCall`)
Check that final balances meet minimum thresholds:
```solidity
Balance[] memory postBalances = [
  Balance({
    target: userAddress,
    token: USDC,
    balance: 1000000 // User must have ≥1 USDC after execution
  })
];
```

#### Balance Diffs (`proxyCallDiffs`)
Check that balance changes meet minimum requirements:
```solidity
Balance[] memory diffs = [
  Balance({
    target: userAddress,
    token: ETH,
    balance: 1000000000000000000 // User must gain ≥1 ETH
  })
];
```

### Approval Modes

#### Approve Mode (`useTransfer: false`)
Set token allowance for target contract:
```solidity
Approval({
  balance: Balance({ target: uniswapRouter, token: USDC, balance: 1000000 }),
  useTransfer: false // Approve uniswapRouter to spend 1 USDC
})
```

#### Transfer Mode (`useTransfer: true`)
Directly transfer tokens to target:
```solidity
Approval({
  balance: Balance({ target: recipient, token: DAI, balance: 1000000000000000000 }),
  useTransfer: true // Transfer 1 DAI to recipient
})
```

### Metadata Support

Metadata provides UI-friendly information without affecting on-chain execution:
```solidity
BalanceMetadata({
  balance: Balance({ target: user, token: USDC, balance: 1000000 }),
  symbol: "USDC",
  decimals: 6
})
```

**Benefits**:
- Easier transaction decoding for wallets
- Clear display in block explorers
- No on-chain storage cost (metadata ignored in execution)

## Contract Overview

## Smart Contract Details

### BalanceProxy.sol

**Purpose**: Core stateless execution engine

**Key Features**:
- ✅ Reentrancy protection via OpenZeppelin's `ReentrancyGuard`
- ✅ Supports both ETH and ERC-20 tokens
- ✅ Two validation modes: absolute balances or diffs
- ✅ Withdrawal support for post-execution transfers
- ✅ Malicious target protection

**Core Data Structures**:
```solidity
struct Balance {
  address target;   // Address to check
  address token;    // Token address (address(0) for ETH)
  int256 balance;   // Expected amount (absolute or diff)
}

struct Approval {
  Balance balance;     // Token, target, amount
  bool useTransfer;    // true: transfer, false: approve
}
```

**Security Guards**:
- `MaliciousApproveTarget`: Approval target must match call target
- `NegativeApprovalAmount`: Approval amounts must be non-negative
- `InsufficientBalance`: Post-balance check failed
- `UnexpectedBalanceDiff`: Balance diff check failed
- `CallFailed`: Target contract call reverted

### PermitRouter.sol

**Purpose**: EIP-2612 permit-based token pulling

**Workflow**:
1. Validate permit signatures match approval array length
2. For each approval:
   - Execute `permit()` on token contract
   - Pull tokens from user to BalanceProxy
3. Delegate execution to BalanceProxy

**Advantages**:
- Single transaction (no separate approval needed)
- Better UX (one signature for everything)
- Gas savings (no approval transaction)

**Requirements**:
- Tokens must support EIP-2612 `permit()`
- Permit signatures must not be expired
- Nonces must be valid

### ApproveRouter.sol

**Purpose**: Traditional allowance-based token pulling

**Workflow**:
1. User approves ApproveRouter for token spending (separate transaction)
2. ApproveRouter pulls approved tokens to BalanceProxy
3. Delegate execution to BalanceProxy

**Advantages**:
- Works with ALL ERC-20 tokens
- No permit support required
- Simpler integration for some dApps

**Requirements**:
- User must pre-approve ApproveRouter as spender
- Sufficient allowance must exist

## Usage Examples

### Example 1: Token Swap with Balance Diff Validation

Swap 1 USDC for at least 0.001 ETH:

```typescript
const diffs = [
  {
    target: userAddress,
    token: USDC,
    balance: -1000000n, // Spend exactly 1 USDC
  },
  {
    target: userAddress,
    token: ethAddress,
    balance: 1000000000000000n, // Gain at least 0.001 ETH
  },
];

const approvals = [
  {
    balance: {
      target: uniswapRouter,
      token: USDC,
      balance: 1000000n,
    },
    useTransfer: false, // Approve Uniswap to spend
  },
];

// Using PermitRouter (with permit signature)
await permitRouter.permitProxyCallDiffs(
  balanceProxy,
  diffs,
  approvals,
  [permitSignature],
  uniswapRouter,
  swapCalldata,
  []
);
```

### Example 2: Token Transfer with Absolute Balance Check

Transfer 10 DAI ensuring user has at least 5 DAI remaining:

```typescript
const postBalances = [
  {
    target: userAddress,
    token: DAI,
    balance: 5000000000000000000n, // Must have ≥5 DAI after
  },
];

const approvals = [
  {
    balance: {
      target: recipient,
      token: DAI,
      balance: 10000000000000000000n,
    },
    useTransfer: true, // Direct transfer to recipient
  },
];

// Using ApproveRouter (requires pre-approval)
await approveRouter.approveProxyCall(
  balanceProxy,
  postBalances,
  approvals,
  zeroAddress, // No target contract call
  '0x',
  []
);
```

### Example 3: Complex DeFi Interaction with Metadata

Execute Uniswap swap with UI-friendly metadata:

```typescript
const metadata = [
  {
    balance: { target: user, token: USDC, balance: -1000000n },
    symbol: "USDC",
    decimals: 6,
  },
  {
    balance: { target: user, token: WETH, balance: 500000000000000n },
    symbol: "WETH",
    decimals: 18,
  },
];

await permitRouter.permitProxyCallDiffsWithMeta(
  balanceProxy,
  metadata,
  approvals,
  permits,
  uniswapRouter,
  swapCalldata,
  []
);
```

## Security Considerations

### Stateless Design
- **No storage variables**: Cannot be exploited via storage manipulation
- **No admin keys**: Fully permissionless and trustless
- **Multi-user safe**: Users cannot interfere with each other

### Reentrancy Protection
- Uses OpenZeppelin's `ReentrancyGuard`
- All public functions marked `nonReentrant`
- Prevents reentrancy attacks during execution

### Approval Safety
- **Target validation**: Approval target must match call target
- **Amount validation**: Approval amounts must be non-negative
- **Transfer isolation**: Each approval executed independently

### Balance Validation
- **Atomic checks**: All balance checks in single transaction
- **Explicit constraints**: User defines exact requirements
- **Automatic revert**: Transaction fails if any check fails

## Testing

Comprehensive test suite covering:
- ✅ Absolute balance validation (ETH & ERC-20)
- ✅ Balance diff validation (positive & negative)
- ✅ Permit-based approvals (EIP-2612)
- ✅ Standard allowance-based approvals
- ✅ Transfer mode vs approve mode
- ✅ Withdrawal functionality
- ✅ Metadata support
- ✅ Error cases and reverts
- ✅ Reentrancy attack prevention
- ✅ Edge cases (zero amounts, ETH handling)

## Development

## Development

### Project Structure

```
eip-8009-contracts/
├── contracts/
│   ├── BalanceProxy.sol          # Core stateless proxy
│   ├── PermitRouter.sol          # EIP-2612 permit router
│   ├── ApproveRouter.sol         # Standard approval router
│   ├── interfaces/
│   │   ├── IBalanceProxy.sol     # Core interface
│   │   ├── IPermitRouter.sol     # Permit router interface
│   │   ├── IApproveRouter.sol    # Approve router interface
│   │   ├── IPermit.sol           # EIP-2612 interfaces
│   │   └── IMetadata.sol         # Metadata struct
│   └── mocks/
│       ├── ERC20Mock.sol         # Test ERC-20 token
│       └── TargetMock.sol        # Test target contract
├── test/
│   └── BalanceProxy.test.ts      # Comprehensive test suite
├── ignition/
│   └── modules/
│       ├── core.ts               # Deploy all contracts
│       ├── balance-proxy.ts      # Deploy BalanceProxy only
│       ├── permit-router.ts      # Deploy PermitRouter only
│       └── approve-router.ts     # Deploy ApproveRouter only
├── config/
│   ├── networks.ts               # Network configurations
│   └── types.ts                  # TypeScript types
└── hardhat.config.ts             # Hardhat configuration
```

### Prerequisites 

1. **Install dependencies**:

    ```shell
    npm ci
    ```

2. **Create `.env` file** based on `.env.example`:

    ```shell
    INFURA_KEY="<your-infura-api-key>"
    MNEMONIC_DEV="<mnemonic-for-testnet>"
    MNEMONIC_PROD="<mnemonic-for-mainnet>"
    FORKING_NETWORK="<main | sepolia>"
    ETHERSCAN_API_KEY="<your-etherscan-api-key>"
    ```

3. **Compile contracts**:

    ```shell
    npm run compile
    ```

### Run tests

Run the full test suite:

```shell
npm run test
```

Run specific test file:

```shell
npx hardhat test test/BalanceProxy.test.ts
```

### Coverage report

Generate code coverage report:

```shell
npm run coverage
```

View coverage in browser:
```shell
open coverage/index.html
```

### Deploy contracts

Deploy all contracts (BalanceProxy + PermitRouter + ApproveRouter):

```shell
npm run deploy ./ignition/modules/core.ts -- --network <network-name>
```

Deploy individual contracts:

```shell
# BalanceProxy only
npm run deploy ./ignition/modules/balance-proxy.ts -- --network sepolia

# PermitRouter only
npm run deploy ./ignition/modules/permit-router.ts -- --network sepolia

# ApproveRouter only
npm run deploy ./ignition/modules/approve-router.ts -- --network sepolia
```

**Supported networks**: 
- `localhost` (Hardhat node)
- `sepolia` (Sepolia testnet)
- `mainnet` (Ethereum mainnet)

**After deployment**:
Deployment addresses are saved in `ignition/deployments/<chain-id>/deployed_addresses.json`

### Run code analyzers

Run all code quality checks (linting + formatting):

```shell
npm run codestyle
```

Auto-fix issues:

```shell
npm run codestyle:fix
```

Individual commands:

```shell
# Solidity linting
npm run lint:sol

# TypeScript linting
npm run lint:ts

# Solidity formatting
npm run format:sol

# TypeScript formatting
npm run format:ts
```

### Static Analysis

Run Slither security analyzer:

```shell
npm run slither
```

Generate human-readable summary:

```shell
npm run slither:summary
```

## Integration Guide

### For dApp Developers

**Step 1**: Deploy or use existing contracts
```typescript
import CoreModule from './ignition/modules/core';

const { balanceProxy, permitRouter, approveRouter } = await ignition.deploy(CoreModule);
```

**Step 2**: Build transaction data
```typescript
// User wants to swap 1 USDC for ETH
const diffs = [
  { target: userAddress, token: USDC, balance: -1000000n },
  { target: userAddress, token: ETH, balance: minEthOut },
];

const approvals = [
  {
    balance: { target: uniswapRouter, token: USDC, balance: 1000000n },
    useTransfer: false,
  },
];
```

**Step 3**: Get permit signature (for PermitRouter)
```typescript
const permit = await signPermit(
  userSigner,
  USDC,
  permitRouter.address,
  1000000n,
  deadline
);
```

**Step 4**: Execute transaction
```typescript
// Option A: Using PermitRouter (recommended)
await permitRouter.permitProxyCallDiffs(
  balanceProxy.address,
  diffs,
  approvals,
  [permit],
  uniswapRouter,
  swapCalldata,
  []
);

// Option B: Using ApproveRouter (requires pre-approval)
await USDC.approve(approveRouter.address, 1000000n);
await approveRouter.approveProxyCallDiffs(
  balanceProxy.address,
  diffs,
  approvals,
  uniswapRouter,
  swapCalldata,
  []
);
```

### For Wallet Developers

Decode metadata for user-friendly display:

```typescript
import { decodeAbiParameters } from 'viem';

// Decode metadata from calldata
const [metadata] = decodeAbiParameters(
  [{ type: 'tuple[]', components: [
    { name: 'balance', type: 'tuple', components: [
      { name: 'target', type: 'address' },
      { name: 'token', type: 'address' },
      { name: 'balance', type: 'int256' },
    ]},
    { name: 'symbol', type: 'string' },
    { name: 'decimals', type: 'uint8' },
  ]}],
  metadataBytes
);

// Display to user
metadata.forEach(m => {
  const amount = formatUnits(m.balance.balance, m.decimals);
  console.log(`${amount} ${m.symbol}`);
});
```

## Gas Optimization

### Typical Gas Costs

| Operation | Gas Cost | Notes |
|-----------|----------|-------|
| `proxyCall` (1 token) | ~150k | Including balance check |
| `proxyCallDiffs` (2 tokens) | ~180k | Pre + post checks |
| `permitProxyCallDiffs` | ~220k | + permit signature |
| `approveProxyCall` | ~160k | Assumes prior approval |

**Optimization tips**:
- Use `proxyCallDiffs` for better UX (shows intent)
- Batch multiple operations in single call
- Minimize number of balance checks
- Use transfer mode when possible (cheaper than approve)

## Audit Status

🔒 **Security**: This code is currently unaudited. Use at your own risk.

**Recommended audits**:
- [ ] Formal verification of balance validation logic
- [ ] Reentrancy attack testing
- [ ] Permit signature replay protection
- [ ] Gas optimization review

## Learn more

The guides in the [documentation site](https://eip-xxxx-doc.ilya-kubariev.workers.dev/docs/intro) will teach about different concepts, and how to use the related contracts that EIP-8009 provides.

## Contribute

EIP-8009 Contracts exists thanks to its contributors. There are many ways you can participate and help build high quality software:

- 🐛 **Report bugs**: Open an issue describing the problem
- 💡 **Suggest features**: Share ideas for improvements  
- 🔧 **Submit PRs**: Fix bugs or add features
- 📚 **Improve docs**: Help make documentation clearer
- 🧪 **Add tests**: Increase code coverage

Check out the [contribution guide](CONTRIBUTING.md) for more details!

## Related Projects

- **[EIP-8009 Frontend](https://github.com/RedDuck-Software/eip-8009-front)**: React dApp for interacting with these contracts
- **[Universal Router Integration](https://github.com/Uniswap/universal-router)**: Example integration with Uniswap

## License

EIP-8009 Contracts is released under the [MIT License](LICENSE).

---

**Built with ❤️ by [RedDuck Software](https://redduck.io)**
