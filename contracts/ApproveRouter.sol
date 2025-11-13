// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {IBalanceProxy} from "./interfaces/IBalanceProxy.sol";
import {IApproveRouter} from "./interfaces/IApproveRouter.sol";
import {BalanceMetadata} from "./interfaces/IMetadata.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title ApproveRouter
/// @notice Handles allowance + pull tokens then delegates to BalanceProxy core
contract ApproveRouter is IApproveRouter {
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
        meta; // ignored on-chain
        for (uint256 i = 0; i < approvals.length; i++) {
            IBalanceProxy.Balance memory bal = approvals[i].balance;
            uint256 amount = uint256(bal.balance);
            IERC20(bal.token).transferFrom(
                msg.sender,
                address(balanceProxy),
                amount
            );
        }
        IBalanceProxy.Balance[] memory empty;
        return
            balanceProxy.proxyCall{value: msg.value}(
                empty,
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
        meta; // ignored on-chain
        for (uint256 i = 0; i < approvals.length; i++) {
            IBalanceProxy.Balance memory bal = approvals[i].balance;
            uint256 amount = uint256(bal.balance);
            IERC20(bal.token).transferFrom(
                msg.sender,
                address(balanceProxy),
                amount
            );
        }
        IBalanceProxy.Balance[] memory empty;
        return
            balanceProxy.proxyCallDiffs{value: msg.value}(
                empty,
                approvals,
                target,
                data,
                withdrawals
            );
    }
}
