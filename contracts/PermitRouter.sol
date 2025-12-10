// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {IBalanceProxy} from "./interfaces/IBalanceProxy.sol";
import {IPermitRouter} from "./interfaces/IPermitRouter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC20Permit, PermitData} from "./interfaces/IPermit.sol";
import {BalanceMetadata} from "./interfaces/IMetadata.sol";

/// @title PermitRouter
/// @notice Handles permit + pull tokens then delegates to BalanceProxy core
contract PermitRouter is IPermitRouter {
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

    /// @notice Execute proxyCall with permits
    function permitProxyCall(
        IBalanceProxy balanceProxy,
        IBalanceProxy.Balance[] memory postBalances,
        IBalanceProxy.Approval[] memory approvals,
        PermitData[] memory permits,
        address target,
        bytes memory data,
        IBalanceProxy.Balance[] memory withdrawals
    ) external payable returns (bytes memory) {
        uint256 len = approvals.length;
        if (permits.length != len)
            revert PermitsLengthMismatch(permits.length, len);
        for (uint256 i = 0; i < len; i++) {
            IBalanceProxy.Balance memory bal = approvals[i].balance;
            uint256 amount = uint256(bal.balance);
            PermitData memory p = permits[i];
            IERC20Permit(bal.token).permit(
                msg.sender,
                address(this),
                amount,
                p.deadline,
                p.v,
                p.r,
                p.s
            );
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

    /// @notice proxyCallDiffs with permits
    function permitProxyCallDiffs(
        IBalanceProxy balanceProxy,
        IBalanceProxy.Balance[] memory diffs,
        IBalanceProxy.Approval[] memory approvals,
        PermitData[] memory permits,
        address target,
        bytes memory data,
        IBalanceProxy.Balance[] memory withdrawals
    ) external payable returns (bytes memory) {
        uint256 len = approvals.length;
        if (permits.length != len)
            revert PermitsLengthMismatch(permits.length, len);
        for (uint256 i = 0; i < len; i++) {
            IBalanceProxy.Balance memory bal = approvals[i].balance;
            uint256 amount = uint256(bal.balance);
            PermitData memory p = permits[i];
            IERC20Permit(bal.token).permit(
                msg.sender,
                address(this),
                amount,
                p.deadline,
                p.v,
                p.r,
                p.s
            );
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

    /// @notice Execute proxyCall with permits and calldata metadata (metadata is ignored on-chain)
    function permitProxyCallWithMeta(
        IBalanceProxy balanceProxy,
        BalanceMetadata[] memory meta,
        IBalanceProxy.Approval[] memory approvals,
        PermitData[] memory permits,
        address target,
        bytes memory data,
        IBalanceProxy.Balance[] memory withdrawals
    ) external payable returns (bytes memory) {
        // Validate all metadata first
        for (uint256 i = 0; i < meta.length; i++) {
            _checkMetadata(meta[i]);
        }
        // metadata forwarded to BalanceProxy for absolute balance checks
        uint256 len = approvals.length;
        if (permits.length != len)
            revert PermitsLengthMismatch(permits.length, len);
        for (uint256 i = 0; i < len; i++) {
            IBalanceProxy.Balance memory bal = approvals[i].balance;
            uint256 amount = uint256(bal.balance);
            PermitData memory p = permits[i];
            IERC20Permit(bal.token).permit(
                msg.sender,
                address(this),
                amount,
                p.deadline,
                p.v,
                p.r,
                p.s
            );
            IERC20(bal.token).transferFrom(
                msg.sender,
                address(balanceProxy),
                amount
            );
        }
        return
            balanceProxy.proxyCallMeta{value: msg.value}(
                meta,
                approvals,
                target,
                data,
                withdrawals
            );
    }

    /// @notice proxyCallDiffs with permits and calldata metadata (metadata is ignored on-chain)
    function permitProxyCallDiffsWithMeta(
        IBalanceProxy balanceProxy,
        BalanceMetadata[] memory meta,
        IBalanceProxy.Approval[] memory approvals,
        PermitData[] memory permits,
        address target,
        bytes memory data,
        IBalanceProxy.Balance[] memory withdrawals
    ) external payable returns (bytes memory) {
        // Validate all metadata first
        for (uint256 i = 0; i < meta.length; i++) {
            _checkMetadata(meta[i]);
        }
        // metadata forwarded to BalanceProxy for diff balance checks
        uint256 len = approvals.length;
        if (permits.length != len)
            revert PermitsLengthMismatch(permits.length, len);
        for (uint256 i = 0; i < len; i++) {
            IBalanceProxy.Balance memory bal = approvals[i].balance;
            uint256 amount = uint256(bal.balance);
            PermitData memory p = permits[i];
            IERC20Permit(bal.token).permit(
                msg.sender,
                address(this),
                amount,
                p.deadline,
                p.v,
                p.r,
                p.s
            );
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
