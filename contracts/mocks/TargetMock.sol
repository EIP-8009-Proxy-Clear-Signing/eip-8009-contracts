// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {ERC20Mock} from "./ERC20Mock.sol";

contract TargetMock {
    ERC20Mock public erc20;

    constructor(address _erc20) {
        erc20 = ERC20Mock(_erc20);
    }

    function mint(uint256 take, uint256 give) public {
        erc20.transferFrom(msg.sender, address(this), take);
        erc20.mint(msg.sender, give);
    }

    function mintEth(uint256 take, uint256 give) public {
        erc20.transferFrom(msg.sender, address(this), take);
        payable(msg.sender).transfer(give);
    }

    receive() external payable {}
}
