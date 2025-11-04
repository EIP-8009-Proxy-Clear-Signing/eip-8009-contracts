// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IBalanceProxy} from "./interfaces/IBalanceProxy.sol";
import {SignedMath} from "@openzeppelin/contracts/utils/math/SignedMath.sol";

/// @title BalanceProxy
/// @notice Proxy contract for calling contracts with specified balances and approvals
/// @dev This contract is used to proxy calls to a target contract with specified balances and approvals
contract BalanceProxy is IBalanceProxy {
    bytes4 private constant _TRANSFER_FROM_SELECTOR =
        IERC20.transferFrom.selector;

    /// @dev Check if calling dangerous token functions directly
    /// @param target The target address being called
    /// @param data The call data
    function _checkDangerousCall(
        address target,
        bytes memory data,
        Balance[] memory
    ) internal pure {
        if (data.length < 4) return;

        bytes4 selector = bytes4(data);

        if (selector == _TRANSFER_FROM_SELECTOR) {
            revert DangerousTokenCall(target, selector);
        }
    }

    /// @dev Calldata version - check if calling dangerous token functions directly
    /// @param target The target address being called
    /// @param data The call data
    function _checkDangerousCallCalldata(
        address target,
        bytes calldata data,
        Balance[] calldata
    ) internal pure {
        if (data.length < 4) return;

        bytes4 selector = bytes4(data);

        if (selector == _TRANSFER_FROM_SELECTOR) {
            revert DangerousTokenCall(target, selector);
        }
    }

    /// @dev BalanceMetadata version - check if calling dangerous token functions directly
    /// @param target The target address being called
    /// @param data The call data
    function _checkDangerousCallMetadata(
        address target,
        bytes memory data,
        BalanceMetadata[] memory
    ) internal pure {
        if (data.length < 4) return;

        bytes4 selector = bytes4(data);

        if (selector == _TRANSFER_FROM_SELECTOR) {
            revert DangerousTokenCall(target, selector);
        }
    }

    /// @dev BalanceMetadata calldata version
    /// @param target The target address being called
    /// @param data The call data
    function _checkDangerousCallMetadataCalldata(
        address target,
        bytes calldata data,
        BalanceMetadata[] calldata
    ) internal pure {
        if (data.length < 4) return;

        bytes4 selector = bytes4(data);

        if (selector == _TRANSFER_FROM_SELECTOR) {
            revert DangerousTokenCall(target, selector);
        }
    }

    /// @inheritdoc IBalanceProxy
    function proxyCallDiffs(
        Balance[] memory diffs,
        Balance[] memory approvals,
        bool[] memory useTransferFlags,
        address target,
        bytes memory data,
        Balance[] memory withdrawals
    ) external payable returns (bytes memory) {
        if (useTransferFlags.length != approvals.length) {
            revert InvalidTransferFlagsLength(useTransferFlags.length, approvals.length);
        }
        _checkDangerousCall(target, data, approvals);
        uint256 i;
        uint256 len = diffs.length;
        uint256[] memory before = new uint256[](len);
        for (i = 0; i < len; i++) {
            before[i] = _currentBalance(diffs[i].token, diffs[i].target);
        }
        for (i = 0; i < approvals.length; i++) {
            _transferAndApprove(approvals[i], target, useTransferFlags[i]);
        }
        (bool success, bytes memory result) = target.call{value: msg.value}(
            data
        );
        if (!success) {
            revert CallFailed(target, data, result);
        }
        for (i = 0; i < withdrawals.length; i++) {
            _transfer(withdrawals[i]);
        }
        for (i = 0; i < len; i++) {
            uint256 afterBal = _currentBalance(diffs[i].token, diffs[i].target);
            int256 actualDiff = int256(afterBal) - int256(before[i]);
            if (actualDiff < diffs[i].balance) {
                revert UnexpectedBalanceDiff(
                    diffs[i].token,
                    diffs[i].target,
                    diffs[i].balance,
                    actualDiff
                );
            }
        }

        return result;
    }

    /// @inheritdoc IBalanceProxy
    function proxyCallCalldataDiffs(
        Balance[] calldata diffs,
        Balance[] calldata approvals,
        bool[] calldata useTransferFlags,
        address target,
        bytes calldata data,
        Balance[] calldata withdrawals
    ) external payable returns (bytes memory) {
        if (useTransferFlags.length != approvals.length) {
            revert InvalidTransferFlagsLength(useTransferFlags.length, approvals.length);
        }
        _checkDangerousCallCalldata(target, data, approvals);
        uint256 i;
        uint256 len = diffs.length;
        uint256[] memory before = new uint256[](len);
        for (i = 0; i < len; i++) {
            before[i] = _currentBalance(diffs[i].token, diffs[i].target);
        }
        for (i = 0; i < approvals.length; i++) {
            _transferAndApproveCalldata(approvals[i], target, useTransferFlags[i]);
        }
        (bool success, bytes memory result) = target.call{value: msg.value}(
            data
        );
        if (!success) {
            revert CallFailed(target, data, result);
        }
        for (i = 0; i < withdrawals.length; i++) {
            _transferCalldata(withdrawals[i]);
        }
        for (i = 0; i < len; i++) {
            uint256 afterBal = _currentBalance(diffs[i].token, diffs[i].target);
            int256 actualDiff = int256(afterBal) - int256(before[i]);
            if (actualDiff < diffs[i].balance) {
                revert UnexpectedBalanceDiff(
                    diffs[i].token,
                    diffs[i].target,
                    diffs[i].balance,
                    actualDiff
                );
            }
        }

        return result;
    }

    /// @inheritdoc IBalanceProxy
    function proxyCallMetadataDiffs(
        BalanceMetadata[] memory diffs,
        BalanceMetadata[] memory approvals,
        bool[] memory useTransferFlags,
        address target,
        bytes memory data,
        BalanceMetadata[] memory withdrawals
    ) external payable returns (bytes memory) {
        if (useTransferFlags.length != approvals.length) {
            revert InvalidTransferFlagsLength(useTransferFlags.length, approvals.length);
        }
        _checkDangerousCallMetadata(target, data, approvals);
        uint256 i;
        uint256 len = diffs.length;
        uint256[] memory before = new uint256[](len);
        for (i = 0; i < len; i++) {
            before[i] = _currentBalance(
                diffs[i].balance.token,
                diffs[i].balance.target
            );
        }
        for (i = 0; i < approvals.length; i++) {
            _checkMetadata(approvals[i]);
            _transferAndApprove(approvals[i].balance, target, useTransferFlags[i]);
        }
        (bool success, bytes memory result) = target.call{value: msg.value}(
            data
        );
        if (!success) {
            revert CallFailed(target, data, result);
        }
        for (i = 0; i < withdrawals.length; i++) {
            _checkMetadata(withdrawals[i]);
            _transfer(withdrawals[i].balance);
        }
        for (i = 0; i < len; i++) {
            uint256 afterBal = _currentBalance(
                diffs[i].balance.token,
                diffs[i].balance.target
            );
            int256 actualDiff = int256(afterBal) - int256(before[i]);
            if (actualDiff < diffs[i].balance.balance) {
                revert UnexpectedBalanceDiff(
                    diffs[i].balance.token,
                    diffs[i].balance.target,
                    diffs[i].balance.balance,
                    actualDiff
                );
            }
        }

        return result;
    }

    /// @inheritdoc IBalanceProxy
    function proxyCallMetadataCalldataDiffs(
        BalanceMetadata[] calldata diffs,
        BalanceMetadata[] calldata approvals,
        bool[] calldata useTransferFlags,
        address target,
        bytes calldata data,
        BalanceMetadata[] calldata withdrawals
    ) external payable returns (bytes memory) {
        if (useTransferFlags.length != approvals.length) {
            revert InvalidTransferFlagsLength(useTransferFlags.length, approvals.length);
        }
        _checkDangerousCallMetadataCalldata(target, data, approvals);
        uint256 i;
        uint256 len = diffs.length;
        uint256[] memory before = new uint256[](len);
        for (i = 0; i < len; i++) {
            before[i] = _currentBalance(
                diffs[i].balance.token,
                diffs[i].balance.target
            );
        }
        for (i = 0; i < approvals.length; i++) {
            _checkMetadataCalldata(approvals[i]);
            _transferAndApproveCalldata(approvals[i].balance, target, useTransferFlags[i]);
        }
        (bool success, bytes memory result) = target.call{value: msg.value}(
            data
        );
        if (!success) {
            revert CallFailed(target, data, result);
        }
        for (i = 0; i < withdrawals.length; i++) {
            _checkMetadataCalldata(withdrawals[i]);
            _transferCalldata(withdrawals[i].balance);
        }
        for (i = 0; i < len; i++) {
            uint256 afterBal = _currentBalance(
                diffs[i].balance.token,
                diffs[i].balance.target
            );
            int256 actualDiff = int256(afterBal) - int256(before[i]);
            if (
                SignedMath.abs(actualDiff) <
                SignedMath.abs(diffs[i].balance.balance)
            ) {
                revert UnexpectedBalanceDiff(
                    diffs[i].balance.token,
                    diffs[i].balance.target,
                    diffs[i].balance.balance,
                    actualDiff
                );
            }
        }

        return result;
    }

    /// @inheritdoc IBalanceProxy
    function proxyCall(
        Balance[] memory postBalances,
        Balance[] memory approvals,
        bool[] memory useTransferFlags,
        address target,
        bytes memory data,
        Balance[] memory withdrawals
    ) external payable returns (bytes memory) {
        if (useTransferFlags.length != approvals.length) {
            revert InvalidTransferFlagsLength(useTransferFlags.length, approvals.length);
        }
        _checkDangerousCall(target, data, approvals);
        uint256 i;
        for (i = 0; i < approvals.length; i++) {
            _transferAndApprove(approvals[i], target, useTransferFlags[i]);
        }
        (bool success, bytes memory result) = target.call{value: msg.value}(
            data
        );
        if (!success) {
            revert CallFailed(target, data, result);
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
        Balance[] calldata postBalances,
        Balance[] calldata approvals,
        bool[] calldata useTransferFlags,
        address target,
        bytes calldata data,
        Balance[] calldata withdrawals
    ) external payable returns (bytes memory) {
        if (useTransferFlags.length != approvals.length) {
            revert InvalidTransferFlagsLength(useTransferFlags.length, approvals.length);
        }
        _checkDangerousCallCalldata(target, data, approvals);
        uint256 i;
        for (i = 0; i < approvals.length; i++) {
            _transferAndApproveCalldata(approvals[i], target, useTransferFlags[i]);
        }
        (bool success, bytes memory result) = target.call{value: msg.value}(
            data
        );
        if (!success) {
            revert CallFailed(target, data, result);
        }
        for (i = 0; i < withdrawals.length; i++) {
            _transferCalldata(withdrawals[i]);
        }
        for (i = 0; i < postBalances.length; i++) {
            _balanceCheckCalldata(postBalances[i]);
        }

        return result;
    }

    /// @inheritdoc IBalanceProxy
    function proxyCallMetadata(
        BalanceMetadata[] memory postBalances,
        BalanceMetadata[] memory approvals,
        bool[] memory useTransferFlags,
        address target,
        bytes memory data,
        BalanceMetadata[] memory withdrawals
    ) external payable returns (bytes memory) {
        if (useTransferFlags.length != approvals.length) {
            revert InvalidTransferFlagsLength(useTransferFlags.length, approvals.length);
        }
        _checkDangerousCallMetadata(target, data, approvals);
        uint256 i;
        for (i = 0; i < approvals.length; i++) {
            _checkMetadata(approvals[i]);
            _transferAndApprove(approvals[i].balance, target, useTransferFlags[i]);
        }
        (bool success, bytes memory result) = target.call{value: msg.value}(
            data
        );
        if (!success) {
            revert CallFailed(target, data, result);
        }
        for (i = 0; i < withdrawals.length; i++) {
            _checkMetadata(withdrawals[i]);
            _transfer(withdrawals[i].balance);
        }
        for (i = 0; i < postBalances.length; i++) {
            _checkMetadata(postBalances[i]);
            _balanceCheck(postBalances[i].balance);
        }

        return result;
    }

    /// @inheritdoc IBalanceProxy
    function proxyCallMetadataCalldata(
        BalanceMetadata[] calldata postBalances,
        BalanceMetadata[] calldata approvals,
        bool[] calldata useTransferFlags,
        address target,
        bytes calldata data,
        BalanceMetadata[] calldata withdrawals
    ) external payable returns (bytes memory) {
        if (useTransferFlags.length != approvals.length) {
            revert InvalidTransferFlagsLength(useTransferFlags.length, approvals.length);
        }
        _checkDangerousCallMetadataCalldata(target, data, approvals);
        uint256 i;
        for (i = 0; i < approvals.length; i++) {
            _checkMetadataCalldata(approvals[i]);
            _transferAndApproveCalldata(approvals[i].balance, target, useTransferFlags[i]);
        }
        (bool success, bytes memory result) = target.call{value: msg.value}(
            data
        );
        if (!success) {
            revert CallFailed(target, data, result);
        }
        for (i = 0; i < withdrawals.length; i++) {
            _checkMetadataCalldata(withdrawals[i]);
            _transferCalldata(withdrawals[i].balance);
        }
        for (i = 0; i < postBalances.length; i++) {
            _checkMetadataCalldata(postBalances[i]);
            _balanceCheckCalldata(postBalances[i].balance);
        }

        return result;
    }

    /// @dev Internal function to check if a balance is sufficient
    /// @param balance Balance to check
    function _balanceCheck(Balance memory balance) internal view {
        uint256 actual = balance.token == address(0)
            ? balance.target.balance
            : IERC20(balance.token).balanceOf(balance.target);
        if (actual < SignedMath.abs(balance.balance)) {
            revert InsufficientBalance(
                balance.token,
                balance.target,
                balance.balance,
                actual
            );
        }
    }

    /// @dev Calldata version of internal function to check if a balance is sufficient
    /// @param balance Balance to check
    function _balanceCheckCalldata(Balance calldata balance) internal view {
        uint256 actual = balance.token == address(0)
            ? balance.target.balance
            : IERC20(balance.token).balanceOf(balance.target);
        if (actual < SignedMath.abs(balance.balance)) {
            revert InsufficientBalance(
                balance.token,
                balance.target,
                balance.balance,
                actual
            );
        }
    }

    /// @dev Internal function to transfer and approve a balance
    /// @param balance Balance to transfer and approve
    /// @param callTarget The target address for the proxy call
    /// @param useTransfer Whether to transfer tokens to target or approve target to spend them
    /// @dev If the token is ETH, this function does nothing
    function _transferAndApprove(
        Balance memory balance,
        address callTarget,
        bool useTransfer
    ) internal {
        if (balance.token == address(0)) {
            return;
        }

        if (balance.target != callTarget) {
            revert MaliciousApproveTarget(balance.token, balance.target);
        }

        IERC20(balance.token).transferFrom(
            msg.sender,
            address(this),
            SignedMath.abs(balance.balance)
        );
        
        if (useTransfer) {
            // Transfer tokens directly to target (for Uniswap, Curve, etc.)
            IERC20(balance.token).transfer(
                balance.target,
                SignedMath.abs(balance.balance)
            );
        } else {
            // Approve target to spend tokens (default behavior)
            IERC20(balance.token).approve(
                balance.target,
                SignedMath.abs(balance.balance)
            );
        }
    }

    /// @dev Calldata version of internal function to transfer and approve a balance
    /// @param balance Balance to transfer and approve
    /// @param callTarget The target address for the proxy call
    /// @param useTransfer Whether to transfer tokens to target or approve target to spend them
    /// @dev If the token is ETH, this function does nothing
    function _transferAndApproveCalldata(
        Balance calldata balance,
        address callTarget,
        bool useTransfer
    ) internal {
        if (balance.token == address(0)) {
            return;
        }

        if (balance.target != callTarget) {
            revert MaliciousApproveTarget(balance.token, balance.target);
        }

        IERC20(balance.token).transferFrom(
            msg.sender,
            address(this),
            SignedMath.abs(balance.balance)
        );
        
        if (useTransfer) {
            // Transfer tokens directly to target (for Uniswap, Curve, etc.)
            IERC20(balance.token).transfer(
                balance.target,
                SignedMath.abs(balance.balance)
            );
        } else {
            // Approve target to spend tokens (default behavior)
            IERC20(balance.token).approve(
                balance.target,
                SignedMath.abs(balance.balance)
            );
        }
    }

    /// @dev Internal function to transfer a balance
    /// @param balance Balance to transfer
    function _transfer(Balance memory balance) internal {
        if (balance.token == address(0)) {
            payable(balance.target).transfer(SignedMath.abs(balance.balance));
        } else {
            IERC20(balance.token).transfer(
                balance.target,
                SignedMath.abs(balance.balance)
            );
        }
    }

    /// @dev Calldata version of internal function to transfer a balance
    /// @param balance Balance to transfer
    function _transferCalldata(Balance calldata balance) internal {
        if (balance.token == address(0)) {
            payable(balance.target).transfer(SignedMath.abs(balance.balance));
        } else {
            IERC20(balance.token).transfer(
                balance.target,
                SignedMath.abs(balance.balance)
            );
        }
    }

    /// @dev Internal function to check if metadata is valid
    /// @param balance Balance to check
    function _checkMetadata(BalanceMetadata memory balance) internal view {
        string memory symbol;
        uint8 decimals;
        if (balance.balance.token == address(0)) {
            symbol = "ETH";
            decimals = 18;
        } else {
            symbol = IERC20Metadata(balance.balance.token).symbol();
            decimals = IERC20Metadata(balance.balance.token).decimals();
        }

        if (
            bytes32(abi.encodePacked(symbol)) !=
            bytes32(abi.encodePacked(balance.symbol)) ||
            decimals != balance.decimals
        ) {
            revert InvalidMetadata(
                balance.balance.token,
                balance.symbol,
                balance.decimals,
                symbol,
                decimals
            );
        }
    }

    /// @dev Calldata version of internal function to check if metadata is valid
    /// @param balance Balance to check
    function _checkMetadataCalldata(
        BalanceMetadata calldata balance
    ) internal view {
        string memory symbol;
        uint8 decimals;
        if (balance.balance.token == address(0)) {
            symbol = "ETH";
            decimals = 18;
        } else {
            symbol = IERC20Metadata(balance.balance.token).symbol();
            decimals = IERC20Metadata(balance.balance.token).decimals();
        }

        if (
            keccak256(abi.encodePacked(symbol)) !=
            keccak256(abi.encodePacked(balance.symbol)) ||
            decimals != balance.decimals
        ) {
            revert InvalidMetadata(
                balance.balance.token,
                balance.symbol,
                balance.decimals,
                symbol,
                decimals
            );
        }
    }

    function _currentBalance(
        address token,
        address who
    ) internal view returns (uint256) {
        return token == address(0) ? who.balance : IERC20(token).balanceOf(who);
    }

    receive() external payable {}
}
