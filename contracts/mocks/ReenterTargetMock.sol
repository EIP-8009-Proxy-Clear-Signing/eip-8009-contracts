// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {IBalanceProxy} from "../interfaces/IBalanceProxy.sol";

contract ReenterTargetMock {
    IBalanceProxy public proxy;

    constructor(address _proxy) {
        proxy = IBalanceProxy(_proxy);
    }

    function attack() external {
        IBalanceProxy.Balance[] memory postBalances;
        IBalanceProxy.Approval[] memory approvals;
        IBalanceProxy.Balance[] memory withdrawals;
        proxy.proxyCall(
            postBalances,
            approvals,
            address(this),
            "",
            withdrawals
        );
    }

    fallback() external payable {}
    receive() external payable {}
}
