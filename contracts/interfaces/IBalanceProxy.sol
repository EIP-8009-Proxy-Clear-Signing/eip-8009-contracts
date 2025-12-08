// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {BalanceMetadata} from "./IMetadata.sol";

/// @title IBalanceProxy
/// @notice Minimal interface for the BalanceProxy core contract
/// @dev Core is dumb: it never pulls tokens, only uses its own balances
interface IBalanceProxy {
    /// @notice Struct to represent balance or value of specific token by target address
    /// @param target Target address
    /// @param token Token address (address(0) for ETH)
    /// @param balance Expected absolute balance (post) or diff (signed)
    struct Balance {
        address target;
        address token;
        int256 balance;
    }

    /// @notice Approval instruction: either transfer tokens to target or approve target to spend
    struct Approval {
        Balance balance; // token, target, amount(>=0 expected)
        bool useTransfer; // true: transfer to target; false: approve target
    }

    /// @notice Error when actual diff != expected
    error UnexpectedBalanceDiff(
        address token,
        address target,
        int256 expected,
        int256 actual
    );


    /// @notice Error thrown when a balance is insufficient
    error InsufficientBalance(
        address token,
        address target,
        int256 balance,
        uint256 actual
    );

    /// @notice Error thrown when a call fails
    error CallFailed(address target, bytes data, bytes returnData);

    /// @notice Error thrown when trying to approve/transfer to an address other than callTarget
    error MaliciousApproveTarget(address token, address target);

    /// @notice Error thrown when an approval amount is negative
    error NegativeApprovalAmount(int256 amount);

    /// @notice Error thrown when metadata doesn't match actual token properties
    error InvalidMetadata(
        address token,
        string expectedSymbol,
        uint8 expectedDecimals,
        string actualSymbol,
        uint8 actualDecimals
    );

    /// @notice Proxy call to a target contract with specified post-balance checks
    function proxyCall(
        Balance[] memory postBalances,
        Approval[] memory approvals,
        address target,
        bytes memory data,
        Balance[] memory withdrawals
    ) external payable returns (bytes memory);

    /// @notice Proxy call with balance diffs
    function proxyCallDiffs(
        Balance[] memory diffs,
        Approval[] memory approvals,
        address target,
        bytes memory data,
        Balance[] memory withdrawals
    ) external payable returns (bytes memory);

    /// @notice Proxy call with metadata (absolute balances)
    function proxyCallMeta(
        BalanceMetadata[] memory meta,
        Approval[] memory approvals,
        address target,
        bytes memory data,
        Balance[] memory withdrawals
    ) external payable returns (bytes memory);

    /// @notice Proxy call with metadata diffs
    function proxyCallDiffsMeta(
        BalanceMetadata[] memory meta,
        Approval[] memory approvals,
        address target,
        bytes memory data,
        Balance[] memory withdrawals
    ) external payable returns (bytes memory);
}
