// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IBalanceProxy} from "./interfaces/IBalanceProxy.sol";

/// @title BalanceProxy
/// @notice Proxy contract for calling contracts with specified balances and approvals
/// @dev This contract is used to proxy calls to a target contract with specified balances and approvals
contract BalanceProxy is IBalanceProxy {
    /// @inheritdoc IBalanceProxy
    function proxyCall(
        Balance[] memory preBalances,
        Balance[] memory approvals,
        address target,
        bytes memory data,
        Balance[] memory withdrawals,
        Balance[] memory postBalances
    ) external payable returns (bytes memory) {
        uint256 i;
        for (i = 0; i < preBalances.length; i++) {
            _balanceCheck(preBalances[i]);
        }
        for (i = 0; i < approvals.length; i++) {
            _transferAndApprove(approvals[i]);
        }
        (bool success, bytes memory result) = target.call{value: msg.value}(
            data
        );
        if (!success) {
            revert CallFailed(target, data);
        }
        for (i = 0; i < withdrawals.length; i++) {
            _transfer(withdrawals[i]);
        }
        for (i = 0; i < postBalances.length; i++) {
            _balanceCheck(postBalances[i]);
        }

        return result;
    }

    /// @inheritdoc IBalanceProxy
    function proxyCallCalldata(
        Balance[] calldata preBalances,
        Balance[] calldata approvals,
        address target,
        bytes calldata data,
        Balance[] calldata withdrawals,
        Balance[] calldata postBalances
    ) external payable returns (bytes memory) {
        uint256 i;
        for (i = 0; i < preBalances.length; i++) {
            _balanceCheckCalldata(preBalances[i]);
        }
        for (i = 0; i < approvals.length; i++) {
            _transferAndApproveCalldata(approvals[i]);
        }
        (bool success, bytes memory result) = target.call{value: msg.value}(
            data
        );
        if (!success) {
            revert CallFailed(target, data);
        }
        for (i = 0; i < withdrawals.length; i++) {
            _transferCalldata(withdrawals[i]);
        }
        for (i = 0; i < postBalances.length; i++) {
            _balanceCheckCalldata(postBalances[i]);
        }

        return result;
    }

    /// @dev Internal function to check if a balance is sufficient
    /// @param balance Balance to check
    function _balanceCheck(Balance memory balance) internal view {
        if (IERC20(balance.token).balanceOf(balance.target) < balance.balance) {
            revert InsufficientBalance(
                balance.token,
                balance.target,
                balance.balance
            );
        }
    }

    /// @dev Calldata version of internal function to check if a balance is sufficient
    /// @param balance Balance to check
    function _balanceCheckCalldata(Balance calldata balance) internal view {
        if (IERC20(balance.token).balanceOf(balance.target) < balance.balance) {
            revert InsufficientBalance(
                balance.token,
                balance.target,
                balance.balance
            );
        }
    }

    /// @dev Internal function to transfer and approve a balance
    /// @param balance Balance to transfer and approve
    function _transferAndApprove(Balance memory balance) internal {
        IERC20(balance.token).transferFrom(
            msg.sender,
            address(this),
            balance.balance
        );
        IERC20(balance.token).approve(balance.target, balance.balance);
    }

    /// @dev Calldata version of internal function to transfer and approve a balance
    /// @param balance Balance to transfer and approve
    function _transferAndApproveCalldata(Balance calldata balance) internal {
        IERC20(balance.token).transferFrom(
            msg.sender,
            address(this),
            balance.balance
        );
        IERC20(balance.token).approve(balance.target, balance.balance);
    }

    /// @dev Internal function to transfer a balance
    /// @param balance Balance to transfer
    function _transfer(Balance memory balance) internal {
        if (balance.token == address(0)) {
            payable(balance.target).transfer(balance.balance);
        } else {
            IERC20(balance.token).transfer(balance.target, balance.balance);
        }
    }

    /// @dev Calldata version of internal function to transfer a balance
    /// @param balance Balance to transfer
    function _transferCalldata(Balance calldata balance) internal {
        if (balance.token == address(0)) {
            payable(balance.target).transfer(balance.balance);
        } else {
            IERC20(balance.token).transfer(balance.target, balance.balance);
        }
    }
}
