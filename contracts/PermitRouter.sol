// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {IBalanceProxy} from "./interfaces/IBalanceProxy.sol";
import {IPermitRouter} from "./interfaces/IPermitRouter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit, PermitData} from "./interfaces/IPermit.sol";

/// @title PermitRouter
/// @notice Handles permit + pull tokens then delegates to BalanceProxy core
contract PermitRouter is IPermitRouter {
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
        if (permits.length != len) revert PermitsLengthMismatch(permits.length, len);
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
        if (permits.length != len) revert PermitsLengthMismatch(permits.length, len);
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
}
