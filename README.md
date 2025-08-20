# Proxy Clear Signing

## Abstract

Introduce a singleton, stateless contract that proxies arbitrary smart‑contract calls and enforces user‑supplied outcome constraints. The proxy supports absolute post‑balance thresholds and balance‑difference (delta) checks over native ETH and ERC‑20 balances. Calls that violate the declared constraints MUST revert. The contract is available at "0xTODO".

## Contract Overview

A singleton, stateless permissionless proxy contract deployed once per network.

The contract accepts transaction execution requests containing:

1. **Target call data** — Encoded calldata for the intended interaction.
2. **Approvals** — Optional ERC‑20 pull‑and‑approve instructions executed **before** the target call (pull from `msg.sender` into the proxy, then `approve` a spender).
3. **Withdrawals** — Optional ETH/ERC‑20 transfers executed **after** the target call (from the proxy to specified recipients).
4. **Balance rules** — One of:
   - **Post‑balance rules:** minimum absolute balances after execution; or
   - **Balance‑difference rules:** minimum required deltas between pre‑ and post‑execution balances.

The contract MUST NOT store persistent state. Multiple independent users MAY reuse the same instance without interference.

## Development

### Prerequisites 

1. Install dependencies:

    ```shell
    npm ci
    ```

1. Create `.env` file based on `.env.example`:

    ```shell
    INFURA_KEY="<string?>"
    MNEMONIC_DEV="<string?>"
    MNEMONIC_PROD="<string?>"
    FORKING_NETWORK="<main | sepolia?>"
    ETHERSCAN_API_KEY="<string?>"
    ```

1. Compile contracts:

    ```shell
    npm run compile
    ```

### Run tests

```shell
npm run test
```

### Coverage report

```shell
npm run coverage
```

### Deploy contracts

```shell
npm run deploy ./ignition/modules/balance-proxy.ts -- --network <network-name>
```

### Run code analyzers

```shell
npm run codestyle
```

## Learn more

The guides in the [documentation site](https://eip-xxxx-doc.ilya-kubariev.workers.dev/docs/intro) will teach about different concepts, and how to use the related contracts that EIP-XXXX Contracts provides.

## Contribute
EIP-XXXX Contracts exists thanks to its contributors. There are many ways you can participate and help build high quality software. Check out the [contribution guide](https://github.com/RedDuck-Software/eip-xxxx-contracts/blob/main/CONTRIBUTING.md)!

## License
EIP-XXXX Contracts is released under the [MIT License](https://github.com/RedDuck-Software/eip-xxxx-contracts/blob/main/LICENSE).
