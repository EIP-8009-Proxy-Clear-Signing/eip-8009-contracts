// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {IBalanceProxy} from "./IBalanceProxy.sol";

/// @title BalanceMetadata struct used for UI-friendly calldata
/// @notice Passed as a first argument to router functions for easier off-chain decoding; ignored by contracts logic
struct BalanceMetadata {
    IBalanceProxy.Balance balance;
    string symbol;
    uint8 decimals;
}
