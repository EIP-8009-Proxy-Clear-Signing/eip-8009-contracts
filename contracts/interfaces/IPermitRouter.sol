// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {IBalanceProxy} from "./IBalanceProxy.sol";
import {PermitData} from "./IPermit.sol";

/// @title IPermitRouter
/// @notice Interface for router that uses EIP-2612 permits to pull tokens then calls BalanceProxy
interface IPermitRouter {
    /// @notice Error thrown when permits array length doesn't match approvals array length
    /// @param permitsLength The length of the permits array
    /// @param approvalsLength The length of the approvals array
    error PermitsLengthMismatch(uint256 permitsLength, uint256 approvalsLength);

    /// @notice Execute proxyCall with permits
    function permitProxyCall(
        IBalanceProxy balanceProxy,
        IBalanceProxy.Balance[] memory postBalances,
        IBalanceProxy.Approval[] memory approvals,
        PermitData[] memory permits,
        address target,
        bytes memory data,
        IBalanceProxy.Balance[] memory withdrawals
    ) external payable returns (bytes memory);

    /// @notice Execute proxyCallDiffs with permits
    function permitProxyCallDiffs(
        IBalanceProxy balanceProxy,
        IBalanceProxy.Balance[] memory diffs,
        IBalanceProxy.Approval[] memory approvals,
        PermitData[] memory permits,
        address target,
        bytes memory data,
        IBalanceProxy.Balance[] memory withdrawals
    ) external payable returns (bytes memory);
}
