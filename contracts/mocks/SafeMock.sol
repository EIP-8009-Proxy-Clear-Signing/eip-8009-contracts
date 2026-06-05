// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Enum} from "@safe-global/safe-smart-account/contracts/libraries/Enum.sol";

contract SafeMock {
    mapping(address => bool) private _owners;
    uint256 private _threshold = 1;

    function addOwner(address owner) external {
        _owners[owner] = true;
    }

    function isOwner(address owner) external view returns (bool) {
        return _owners[owner];
    }

    function setThreshold(uint256 threshold) external {
        _threshold = threshold;
    }

    function getThreshold() external view returns (uint256) {
        return _threshold;
    }

    /// @dev Mirrors Safe.execTransaction. Skips signature verification.
    ///      Propagates reverts so BalanceProxy errors bubble up in tests.
    function execTransaction(
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation,
        uint256,
        uint256,
        uint256,
        address,
        address payable,
        bytes memory
    ) external payable returns (bool success) {
        require(operation == Enum.Operation.Call, "SafeMock: only Call");
        bytes memory returnData;
        (success, returnData) = to.call{value: value}(data);
        if (!success) {
            assembly {
                revert(add(returnData, 0x20), mload(returnData))
            }
        }
    }

    receive() external payable {}
}
