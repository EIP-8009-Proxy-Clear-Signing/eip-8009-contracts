// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {IBalanceProxy} from "./interfaces/IBalanceProxy.sol";
import {IApproveRouter} from "./interfaces/IApproveRouter.sol";
import {BalanceMetadata} from "./interfaces/IMetadata.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/// @title ApproveRouter
/// @notice Handles allowance + pull tokens then delegates to BalanceProxy core
contract ApproveRouter is IApproveRouter {
    /// @dev Internal function to validate metadata matches actual token properties
    /// @param meta Metadata to validate
    function _checkMetadata(BalanceMetadata memory meta) internal view {
        string memory actualSymbol;
        uint8 actualDecimals;

        if (meta.balance.token == address(0)) {
            actualSymbol = "ETH";
            actualDecimals = 18;
        } else {
            actualSymbol = IERC20Metadata(meta.balance.token).symbol();
            actualDecimals = IERC20Metadata(meta.balance.token).decimals();
        }

        if (
            keccak256(abi.encodePacked(actualSymbol)) !=
            keccak256(abi.encodePacked(meta.symbol)) ||
            actualDecimals != meta.decimals
        ) {
            revert IBalanceProxy.InvalidMetadata(
                meta.balance.token,
                meta.symbol,
                meta.decimals,
                actualSymbol,
                actualDecimals
            );
        }
    }

    /// @notice Execute proxyCall with pre-approved tokens (router as spender)
    function approveProxyCall(
        IBalanceProxy balanceProxy,
        IBalanceProxy.Balance[] memory postBalances,
        IBalanceProxy.Approval[] memory approvals,
        address target,
        bytes memory data,
        IBalanceProxy.Balance[] memory withdrawals
    ) external payable returns (bytes memory) {
        for (uint256 i = 0; i < approvals.length; i++) {
            IBalanceProxy.Balance memory bal = approvals[i].balance;
            uint256 amount = uint256(bal.balance);
            IERC20(bal.token).transferFrom(
                msg.sender,
                address(balanceProxy),
                amount
            );
        }
        return
            balanceProxy.proxyCall{value: msg.value}(
                postBalances,
                approvals,
                target,
                data,
                withdrawals
            );
    }

    /// @notice proxyCallDiffs with pre-approved tokens
    function approveProxyCallDiffs(
        IBalanceProxy balanceProxy,
        IBalanceProxy.Balance[] memory diffs,
        IBalanceProxy.Approval[] memory approvals,
        address target,
        bytes memory data,
        IBalanceProxy.Balance[] memory withdrawals
    ) external payable returns (bytes memory) {
        for (uint256 i = 0; i < approvals.length; i++) {
            IBalanceProxy.Balance memory bal = approvals[i].balance;
            uint256 amount = uint256(bal.balance);
            IERC20(bal.token).transferFrom(
                msg.sender,
                address(balanceProxy),
                amount
            );
        }
        return
            balanceProxy.proxyCallDiffs{value: msg.value}(
                diffs,
                approvals,
                target,
                data,
                withdrawals
            );
    }

    /// @notice Execute proxyCall with pre-approved tokens and calldata metadata (metadata is ignored on-chain)
    function approveProxyCallWithMeta(
        IBalanceProxy balanceProxy,
        BalanceMetadata[] memory meta,
        IBalanceProxy.Approval[] memory approvals,
        address target,
        bytes memory data,
        IBalanceProxy.Balance[] memory withdrawals
    ) external payable returns (bytes memory) {
        // Validate all metadata first
        for (uint256 i = 0; i < meta.length; i++) {
            _checkMetadata(meta[i]);
        }
        // Pull tokens for approvals
        for (uint256 i = 0; i < approvals.length; i++) {
            IBalanceProxy.Balance memory bal = approvals[i].balance;
            uint256 amount = uint256(bal.balance);
            IERC20(bal.token).transferFrom(
                msg.sender,
                address(balanceProxy),
                amount
            );
        }
        // Call direct meta variant (uses meta[i].balance internally)
        return
            balanceProxy.proxyCallMeta{value: msg.value}(
                meta,
                approvals,
                target,
                data,
                withdrawals
            );
    }

    /// @notice proxyCallDiffs with pre-approved tokens and calldata metadata (metadata is ignored on-chain)
    function approveProxyCallDiffsWithMeta(
        IBalanceProxy balanceProxy,
        BalanceMetadata[] memory meta,
        IBalanceProxy.Approval[] memory approvals,
        address target,
        bytes memory data,
        IBalanceProxy.Balance[] memory withdrawals
    ) external payable returns (bytes memory) {
        // Validate all metadata first
        for (uint256 i = 0; i < meta.length; i++) {
            _checkMetadata(meta[i]);
        }
        for (uint256 i = 0; i < approvals.length; i++) {
            IBalanceProxy.Balance memory bal = approvals[i].balance;
            uint256 amount = uint256(bal.balance);
            IERC20(bal.token).transferFrom(
                msg.sender,
                address(balanceProxy),
                amount
            );
        }
        return
            balanceProxy.proxyCallDiffsMeta{value: msg.value}(
                meta,
                approvals,
                target,
                data,
                withdrawals
            );
    }
}
