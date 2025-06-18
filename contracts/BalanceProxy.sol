// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IBalanceProxy} from "./interfaces/IBalanceProxy.sol";

/// @title BalanceProxy
/// @notice Proxy contract for calling contracts with specified balances and approvals
/// @dev This contract is used to proxy calls to a target contract with specified balances and approvals
contract BalanceProxy is IBalanceProxy {
    /// @inheritdoc IBalanceProxy
    function proxyCall(
        Balance[] memory postBalances,
        Balance[] memory preBalances,
        Balance[] memory approvals,
        address target,
        bytes memory data,
        Balance[] memory withdrawals
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
        Balance[] calldata postBalances,
        Balance[] calldata preBalances,
        Balance[] calldata approvals,
        address target,
        bytes calldata data,
        Balance[] calldata withdrawals
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

    /// @inheritdoc IBalanceProxy
    function proxyCallMetadata(
        BalanceMetadata[] memory postBalances,
        BalanceMetadata[] memory preBalances,
        BalanceMetadata[] memory approvals,
        address target,
        bytes memory data,
        BalanceMetadata[] memory withdrawals
    ) external payable returns (bytes memory) {
        uint256 i;
        for (i = 0; i < preBalances.length; i++) {
            _checkMetadata(preBalances[i]);
            _balanceCheck(preBalances[i].balance);
        }
        for (i = 0; i < approvals.length; i++) {
            _checkMetadata(approvals[i]);
            _transferAndApprove(approvals[i].balance);
        }
        (bool success, bytes memory result) = target.call{value: msg.value}(
            data
        );
        if (!success) {
            revert CallFailed(target, data);
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
        BalanceMetadata[] calldata preBalances,
        BalanceMetadata[] calldata approvals,
        address target,
        bytes calldata data,
        BalanceMetadata[] calldata withdrawals
    ) external payable returns (bytes memory) {
        uint256 i;
        for (i = 0; i < preBalances.length; i++) {
            _checkMetadataCalldata(preBalances[i]);
            _balanceCheckCalldata(preBalances[i].balance);
        }
        for (i = 0; i < approvals.length; i++) {
            _checkMetadataCalldata(approvals[i]);
            _transferAndApproveCalldata(approvals[i].balance);
        }
        (bool success, bytes memory result) = target.call{value: msg.value}(
            data
        );
        if (!success) {
            revert CallFailed(target, data);
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
        if (actual < balance.balance) {
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
        if (actual < balance.balance) {
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
    /// @dev If the token is ETH, this function does nothing
    function _transferAndApprove(Balance memory balance) internal {
        if (balance.token == address(0)) {
            return;
        }
        IERC20(balance.token).transferFrom(
            msg.sender,
            address(this),
            balance.balance
        );
        IERC20(balance.token).approve(balance.target, balance.balance);
    }

    /// @dev Calldata version of internal function to transfer and approve a balance
    /// @param balance Balance to transfer and approve
    /// @dev If the token is ETH, this function does nothing
    function _transferAndApproveCalldata(Balance calldata balance) internal {
        if (balance.token == address(0)) {
            return;
        }
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

    receive() external payable {}
}
