// SPDX-License-Identifier: GNU Public License v3.0
pragma solidity >=0.8.19 <0.9.0;

import {IValidator, IModule, PackedUserOperation} from "../../common/interfaces/IERC7579Modules.sol";
import {ERC1271_MAGICVALUE, ERC1271_INVALID, MODULE_TYPE_VALIDATOR, SIG_VALIDATION_SUCCESS_UINT, SIG_VALIDATION_FAILED_UINT} from "./constants.sol";

contract WebAuthn256r1Validator is IValidator {
    string public constant name = "PlentiFi.ECDSAValidator-v0.0.1";

    // number of signers per smart account
    mapping(address => uint256) public signerCount;

    // account => signer => approved or not
    mapping(address => mapping(address => bool)) public signers;

    event SignerAdded(address indexed smartAccount, bytes32 indexed credId);
    event SignerRemoved(address indexed smartAccount, bytes32 indexed credId);

    constructor() {}

    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    ) external payable returns (uint256) {
        // todo
    }

    function isValidSignatureWithSender(
        address sender,
        bytes32 hash,
        bytes calldata data
    ) external view returns (bytes4) {
        // todo
    }

    function onInstall(bytes calldata data) external payable override {
        require(signerCount[msg.sender] == 0, "Validator already installed");
        // todo
    }

    function onUninstall(bytes calldata data) external payable override {
        // todo
    }

    function isModuleType(uint256 moduleTypeId) external pure returns (bool) {
        return moduleTypeId == MODULE_TYPE_VALIDATOR;
    }

    function isInitialized(address smartAccount) external view returns (bool) {
        return signerCount[smartAccount] > 0;
    }

    function addSigner(bytes32 credId, uint256[2] calldata publicKey) external {
        // todo
    }

    function removeSigner(bytes32 credId) external {
        // todo
    }

    function addSigners(bytes calldata data) external {
        // todo
    }

    function removeSigners(bytes calldata data) external {
        // todo
    }

    function _addSigner(bytes32 credId, uint256[2] memory publicKey) internal {
        // todo
        emit SignerAdded(msg.sender, credId);
    }

    function _removeSigner(bytes32 credId) internal {
        // todo
        emit SignerRemoved(msg.sender, credId);
    }

    function _verify(
        bytes32 hash,
        bytes calldata signatureData
    ) internal view returns (uint256) {
       
       
    }
}
