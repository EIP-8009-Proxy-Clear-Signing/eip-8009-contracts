// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {IBalanceProxy} from "./IBalanceProxy.sol";
import {BalanceMetadata} from "./IMetadata.sol";

/// @title IApproveRouter
/// @notice Interface for router that uses pre-approvals (allowance to router) to pull tokens then calls BalanceProxy
interface IApproveRouter {
    /// @notice Execute proxyCall with pre-approved tokens (router as spender)
    function approveProxyCall(
        IBalanceProxy balanceProxy,
        IBalanceProxy.Balance[] memory postBalances,
        IBalanceProxy.Approval[] memory approvals,
        address target,
        bytes memory data,
        IBalanceProxy.Balance[] memory withdrawals
    ) external payable returns (bytes memory);

    /// @notice Execute proxyCall with pre-approved tokens (router as spender) and calldata metadata as the first arg
    function approveProxyCallWithMeta(
        IBalanceProxy balanceProxy,
        BalanceMetadata[] memory meta,
        IBalanceProxy.Balance[] memory balances,
        IBalanceProxy.Approval[] memory approvals,
        address target,
        bytes memory data,
        IBalanceProxy.Balance[] memory withdrawals
    ) external payable returns (bytes memory);

    /// @notice Execute proxyCallDiffs with pre-approved tokens
    function approveProxyCallDiffs(
        IBalanceProxy balanceProxy,
        IBalanceProxy.Balance[] memory diffs,
        IBalanceProxy.Approval[] memory approvals,
        address target,
        bytes memory data,
        IBalanceProxy.Balance[] memory withdrawals
    ) external payable returns (bytes memory);

    /// @notice Execute proxyCallDiffs with pre-approved tokens and calldata metadata as the first arg
    function approveProxyCallDiffsWithMeta(
        IBalanceProxy balanceProxy,
        BalanceMetadata[] memory meta,
        IBalanceProxy.Balance[] memory diffs,
        IBalanceProxy.Approval[] memory approvals,
        address target,
        bytes memory data,
        IBalanceProxy.Balance[] memory withdrawals
    ) external payable returns (bytes memory);
}
