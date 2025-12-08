// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {BalanceProxy} from "../BalanceProxy.sol";
import {IBalanceProxy} from "../interfaces/IBalanceProxy.sol";

/// @notice Test helper exposing internal view checks for coverage
contract BalanceProxyTester is BalanceProxy {
    function exposeBalanceCheckCalldata(
        IBalanceProxy.Balance calldata balance
    ) external view {
        _balanceCheckCalldata(balance);
    }
}
