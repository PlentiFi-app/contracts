// SPDX-License-Identifier: GNU Public License v3.0
pragma solidity >=0.8.19 <0.9.0;

import {IValidator, IModule, PackedUserOperation} from "./interfaces/IERC7579Modules.sol";
import {ERC1271_MAGICVALUE, ERC1271_INVALID, MODULE_TYPE_VALIDATOR, SIG_VALIDATION_SUCCESS_UINT, SIG_VALIDATION_FAILED_UINT} from "./constants.sol";

contract DummyValidator is IValidator {
    string public constant name = "PlentiFi.DummyValidator-v0.0.1";

    mapping(address => bool) public initialized;

    error InvalidAuthenticatorData();
    error InvalidClientData();
    error InvalidChallenge();

    event SignerAdded(address indexed smartAccount, bytes32 indexed credId);
    event SignerRemoved(address indexed smartAccount, bytes32 indexed credId);

    constructor() {}

    /**
     * @inheritdoc IValidator
     */
    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32
    ) external payable returns (uint256) {

      bytes memory validSignature = new bytes(1);

      validSignature[0] = 0x12;

        if (compareBytes(validSignature, userOp.signature)) {
            return SIG_VALIDATION_SUCCESS_UINT;
        }
        return SIG_VALIDATION_FAILED_UINT;
    }

    //////////////////////
    function test(bytes calldata data) external pure returns (bool) {
        
      bytes memory validSignature = new bytes(1);

      validSignature[0] = 0x12;

       return compareBytes(validSignature, data);
   
    }
    //////////////////////

    /**
     * @inheritdoc IValidator
     */
    function isValidSignatureWithSender(
        address,
        bytes32,
        bytes calldata data
    ) external pure returns (bytes4) {
        bytes memory validSignature = new bytes(1);

        validSignature[0] = 0x34;

        if (compareBytes(validSignature, data)) {
            return ERC1271_MAGICVALUE;
        } else {
            return ERC1271_INVALID;
        }
    }

    /**
     * @inheritdoc IModule
     */
    function onInstall(bytes calldata data) external payable override {
      bytes memory validData = new bytes(1);

      validData[0] = 0x56;

        if (compareBytes(validData, data)) {
            initialized[msg.sender] = true;
        }

        revert("Dummy validator: Invalid install data");
    }

    /**
     * @inheritdoc IModule
     */
    function onUninstall(bytes calldata data) external payable override {
      bytes memory validData = new bytes(1);

      validData[0] = 0x78;

        if (compareBytes(validData, data)) {
            delete initialized[msg.sender];
        }

        revert("Dummy validator: Invalid uninstall data");
    }

    /**
     * @inheritdoc IModule
     */
    function isModuleType(uint256 moduleTypeId) external pure returns (bool) {
        return moduleTypeId == MODULE_TYPE_VALIDATOR;
    }

    /**
     * @inheritdoc IModule
     */
    function isInitialized(address smartAccount) external view returns (bool) {
        return initialized[smartAccount];
    }

    function compareBytes(bytes memory storageBytes, bytes calldata calldataBytes) public pure returns (bool) {
        // Check if the lengths are the same
        if (storageBytes.length != calldataBytes.length) {
            return false;
        }
        
        // Compare each byte
        for (uint i = 0; i < storageBytes.length; i++) {
            if (storageBytes[i] != calldataBytes[i]) {
                return false;
            }
        }
        
        // All bytes are the same
        return true;
    }
}
