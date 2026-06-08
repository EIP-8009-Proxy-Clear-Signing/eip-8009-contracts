// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Enum} from "@safe-global/safe-smart-account/contracts/libraries/Enum.sol";

contract SafeMock {
    bytes32 private constant DOMAIN_SEPARATOR_TYPEHASH =
        0x47e79534a245952e8b16893a336b85a3d9ea9fa8c573f3d803afb92a79469218;
    bytes32 private constant SAFE_TX_TYPEHASH =
        0xbb8310d486368db6bd6f849402fdd73ad53d316b5a4b2644ad6efe0f941286d8;

    mapping(address => bool) private _owners;
    mapping(address => mapping(bytes32 => uint256)) public approvedHashes;
    uint256 private _threshold = 1;
    uint256 public nonce;
    uint256 public lastSignaturesLength;
    address public lastSignatureOwner;

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

    function approveHash(bytes32 safeTxHash) external {
        require(_owners[msg.sender], "GS030");
        approvedHashes[msg.sender][safeTxHash] = 1;
    }

    function getTransactionHash(
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address refundReceiver,
        uint256 _nonce
    ) external view returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    bytes1(0x19),
                    bytes1(0x01),
                    domainSeparator(),
                    keccak256(
                        abi.encode(
                            SAFE_TX_TYPEHASH,
                            to,
                            value,
                            keccak256(data),
                            operation,
                            safeTxGas,
                            baseGas,
                            gasPrice,
                            gasToken,
                            refundReceiver,
                            _nonce
                        )
                    )
                )
            );
    }

    function domainSeparator() public view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    DOMAIN_SEPARATOR_TYPEHASH,
                    block.chainid,
                    address(this)
                )
            );
    }

    function checkNSignatures(
        bytes32 safeTxHash,
        bytes memory,
        bytes memory signatures,
        uint256 requiredSignatures
    ) external view {
        _checkNSignatures(
            msg.sender,
            safeTxHash,
            signatures,
            requiredSignatures
        );
    }

    function _checkNSignatures(
        address executor,
        bytes32 safeTxHash,
        bytes memory signatures,
        uint256 requiredSignatures
    ) internal view {
        require(signatures.length >= requiredSignatures * 65, "GS020");

        address lastOwner = address(0);
        for (uint256 i = 0; i < requiredSignatures; i++) {
            bytes32 r;
            uint8 v;
            uint256 offset = 32 + i * 65;

            assembly {
                r := mload(add(signatures, offset))
                v := byte(0, mload(add(signatures, add(offset, 64))))
            }

            require(v == 1, "SafeMock: only approved hash signatures");
            address currentOwner = address(uint160(uint256(r)));
            require(
                executor == currentOwner ||
                    approvedHashes[currentOwner][safeTxHash] != 0,
                "GS025"
            );
            require(currentOwner > lastOwner && _owners[currentOwner], "GS026");
            lastOwner = currentOwner;
        }
    }

    function execTransaction(
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address payable refundReceiver,
        bytes memory signatures
    ) external payable returns (bool success) {
        require(operation == Enum.Operation.Call, "SafeMock: only Call");
        bytes32 safeTxHash = this.getTransactionHash(
            to,
            value,
            data,
            operation,
            safeTxGas,
            baseGas,
            gasPrice,
            gasToken,
            refundReceiver,
            nonce
        );
        _checkNSignatures(msg.sender, safeTxHash, signatures, _threshold);
        lastSignaturesLength = signatures.length;
        lastSignatureOwner = _lastSignatureOwner(signatures);
        nonce++;
        bytes memory returnData;
        (success, returnData) = to.call{value: value}(data);
        if (!success) {
            assembly {
                revert(add(returnData, 0x20), mload(returnData))
            }
        }
    }

    function _lastSignatureOwner(
        bytes memory signatures
    ) internal pure returns (address owner) {
        if (signatures.length < 65) return address(0);

        bytes32 r;
        uint256 offset = signatures.length - 65 + 32;
        assembly {
            r := mload(add(signatures, offset))
        }
        return address(uint160(uint256(r)));
    }

    receive() external payable {}
}
