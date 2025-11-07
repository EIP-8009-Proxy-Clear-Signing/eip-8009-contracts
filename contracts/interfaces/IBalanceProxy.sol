// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {PermitData} from "./IPermit.sol";

/// @title IBalanceProxy
/// @notice Interface for the BalanceProxy contract
/// @dev This interface is used to proxy calls to a target contract with specified balances and approvals
interface IBalanceProxy {
    /// @notice Struct to represent balance or value of specific token by target address
    /// @param target Target address
    /// @param token Token address
    /// @param balance Balance
    struct Balance {
        address target;
        address token;
        int256 balance;
    }

    /// @notice Error when actual diff != expected
    /// @param token    Token address
    /// @param target   Target address
    /// @param expected Expected diff
    /// @param actual   Actual diff
    error UnexpectedBalanceDiff(
        address token,
        address target,
        int256 expected,
        int256 actual
    );
    error PermitExpired(uint256 deadline);
    error PermitFailed(address owner, address token);
    error InvalidPermitLength(uint256 permitsLength, uint256 approvalsLength);

    /// @notice Error thrown when allowance is insufficient for transferFrom
    /// @param token Token address
    /// @param owner Token owner address
    /// @param required Required allowance amount
    /// @param actual Actual allowance amount
    error InsufficientAllowance(
        address token,
        address owner,
        uint256 required,
        uint256 actual
    );

    /// @notice Struct to represent metadata of a balance
    /// @param target Target address
    /// @param token Token address
    /// @param balance Balance struct
    /// @param symbol Symbol of the token
    /// @param decimals Decimals of the token
    struct BalanceMetadata {
        Balance balance;
        string symbol;
        uint8 decimals;
    }

    /// @notice Error thrown when a balance is insufficient
    /// @param token Token address
    /// @param target Target address
    /// @param balance Balance
    error InsufficientBalance(
        address token,
        address target,
        int256 balance,
        uint256 actual
    );

    /// @notice Error thrown when a call fails
    /// @param target Target address
    /// @param data Data passed to the target contract
    /// @param returnData Return data from the target contract
    error CallFailed(address target, bytes data, bytes returnData);

    /// @notice Error thrown when metadata is invalid
    /// @param token Token address
    /// @param expectedSymbol Expected symbol of the token
    /// @param expectedDecimals Expected decimals of the token
    /// @param actualSymbol Actual symbol of the token
    /// @param actualDecimals Actual decimals of the token
    error InvalidMetadata(
        address token,
        string expectedSymbol,
        uint8 expectedDecimals,
        string actualSymbol,
        uint8 actualDecimals
    );

    /// @notice Error thrown when trying to approve tokens to an address other than callTarget
    /// @param token Token address
    /// @param target Malicious target address
    error MaliciousApproveTarget(address token, address target);

    /// @notice Error thrown when useTransferFlags length does not match approvals length
    /// @param flagsLength Length of useTransferFlags array
    /// @param approvalsLength Length of approvals array
    error InvalidTransferFlagsLength(
        uint256 flagsLength,
        uint256 approvalsLength
    );

    // Legacy proxyCall* functions removed in dev build; use permitAndProxyCall* only

    /// @notice Proxy call to a target contract with specified balances and approvals using permits
    /// @param postBalances Balances to check after the call
    /// @param approvals Approvals to make before the call
    /// @param permits Permit data for each approval
    /// @param useTransferFlags Flags to determine whether to transfer or approve for each approval
    /// @param target Target contract to call
    /// @param data Data to pass to the target contract
    /// @param withdrawals Withdrawals to make after the call
    /// @return Result of the call
    function permitAndProxyCall(
        Balance[] memory postBalances,
        Balance[] memory approvals,
        PermitData[] memory permits,
        bool[] memory useTransferFlags,
        address target,
        bytes memory data,
        Balance[] memory withdrawals
    ) external payable returns (bytes memory);

    /// @notice Calldata version of proxyCall with permits
    function permitAndProxyCallCalldata(
        Balance[] calldata postBalances,
        Balance[] calldata approvals,
        PermitData[] calldata permits,
        bool[] calldata useTransferFlags,
        address target,
        bytes calldata data,
        Balance[] calldata withdrawals
    ) external payable returns (bytes memory);

    /// @notice Proxy call with metadata and permits
    function permitAndProxyCallMetadata(
        BalanceMetadata[] memory postBalances,
        BalanceMetadata[] memory approvals,
        PermitData[] memory permits,
        bool[] memory useTransferFlags,
        address target,
        bytes memory data,
        BalanceMetadata[] memory withdrawals
    ) external payable returns (bytes memory);

    /// @notice Calldata version of proxyCall with metadata and permits
    function permitAndProxyCallMetadataCalldata(
        BalanceMetadata[] calldata postBalances,
        BalanceMetadata[] calldata approvals,
        PermitData[] calldata permits,
        bool[] calldata useTransferFlags,
        address target,
        bytes calldata data,
        BalanceMetadata[] calldata withdrawals
    ) external payable returns (bytes memory);

    /// @notice Proxy call with balance diffs and permits
    function permitAndProxyCallDiffs(
        Balance[] memory diffs,
        Balance[] memory approvals,
        PermitData[] memory permits,
        bool[] memory useTransferFlags,
        address target,
        bytes memory data,
        Balance[] memory withdrawals
    ) external payable returns (bytes memory);

    /// @notice Calldata version of proxyCall with balance diffs and permits
    function permitAndProxyCallCalldataDiffs(
        Balance[] calldata diffs,
        Balance[] calldata approvals,
        PermitData[] calldata permits,
        bool[] calldata useTransferFlags,
        address target,
        bytes calldata data,
        Balance[] calldata withdrawals
    ) external payable returns (bytes memory);

    /// @notice Proxy call with metadata diffs and permits
    function permitAndProxyCallMetadataDiffs(
        BalanceMetadata[] memory diffs,
        BalanceMetadata[] memory approvals,
        PermitData[] memory permits,
        bool[] memory useTransferFlags,
        address target,
        bytes memory data,
        BalanceMetadata[] memory withdrawals
    ) external payable returns (bytes memory);

    /// @notice Calldata version of proxyCall with metadata diffs and permits
    function permitAndProxyCallMetadataCalldataDiffs(
        BalanceMetadata[] calldata diffs,
        BalanceMetadata[] calldata approvals,
        PermitData[] calldata permits,
        bool[] calldata useTransferFlags,
        address target,
        bytes calldata data,
        BalanceMetadata[] calldata withdrawals
    ) external payable returns (bytes memory);

    /// @notice Proxy call for pre-approved tokens (without permit)
    /// @param postBalances Balances to check after the call
    /// @param approvals Approvals to make before the call
    /// @param useTransferFlags Flags to determine whether to transfer or approve for each approval
    /// @param target Target contract to call
    /// @param data Data to pass to the target contract
    /// @param withdrawals Withdrawals to make after the call
    /// @return Result of the call
    function approveAndProxyCall(
        Balance[] memory postBalances,
        Balance[] memory approvals,
        bool[] memory useTransferFlags,
        address target,
        bytes memory data,
        Balance[] memory withdrawals
    ) external payable returns (bytes memory);

    /// @notice Calldata version of approveAndProxyCall
    function approveAndProxyCallCalldata(
        Balance[] calldata postBalances,
        Balance[] calldata approvals,
        bool[] calldata useTransferFlags,
        address target,
        bytes calldata data,
        Balance[] calldata withdrawals
    ) external payable returns (bytes memory);
}
