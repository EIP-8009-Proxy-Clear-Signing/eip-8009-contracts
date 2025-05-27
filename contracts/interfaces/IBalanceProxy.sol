// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

/// @title IBalanceProxy
/// @notice Interface for the BalanceProxy contract
/// @dev This interface is used to proxy calls to a target contract with specified balances and approvals
interface IBalanceProxy {
    /// @notice Struct to represent balance or value of specific token by target address
    struct Balance {
        address target;
        address token;
        uint256 balance;
    }

    /// @notice Error thrown when a balance is insufficient
    /// @param token Token address
    /// @param target Target address
    /// @param balance Balance
    error InsufficientBalance(
        address token,
        address target,
        uint256 balance,
        uint256 actual
    );

    /// @notice Error thrown when a call fails
    /// @param target Target address
    /// @param data Data passed to the target contract
    error CallFailed(address target, bytes data);

    /// @notice Proxy call to a target contract with specified balances and approvals
    /// @param preBalances Balances to check before the call
    /// @param approvals Approvals to make before the call
    /// @param target Target contract to call
    /// @param data Data to pass to the target contract
    /// @param withdrawals Withdrawals to make after the call
    /// @param postBalances Balances to check after the call
    /// @return Result of the call
    function proxyCall(
        Balance[] memory preBalances,
        Balance[] memory approvals,
        address target,
        bytes memory data,
        Balance[] memory withdrawals,
        Balance[] memory postBalances
    ) external payable returns (bytes memory);

    /// @notice Calldata version of proxy call to a target contract with specified balances and approvals
    /// @param preBalances Balances to check before the call
    /// @param approvals Approvals to make before the call
    /// @param target Target contract to call
    /// @param data Data to pass to the target contract
    /// @param withdrawals Withdrawals to make after the call
    /// @param postBalances Balances to check after the call
    /// @return result Result of the call
    function proxyCallCalldata(
        Balance[] calldata preBalances,
        Balance[] calldata approvals,
        address target,
        bytes calldata data,
        Balance[] calldata withdrawals,
        Balance[] calldata postBalances
    ) external payable returns (bytes memory);
}
