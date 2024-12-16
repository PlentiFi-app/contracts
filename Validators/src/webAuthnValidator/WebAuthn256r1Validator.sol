// SPDX-License-Identifier: GNU Public License v3.0
pragma solidity >=0.8.19 <0.9.0;

import {IValidator, IModule, PackedUserOperation} from "../interfaces/IERC7579Modules.sol";
import {SclVerifier} from "./SclVerifier.sol";
import {ERC1271_MAGICVALUE, ERC1271_INVALID, MODULE_TYPE_VALIDATOR, SIG_VALIDATION_SUCCESS_UINT, SIG_VALIDATION_FAILED_UINT} from "../constants.sol";

contract WebAuthn256r1Validator is IValidator {
    bytes32 public constant initializedKey = bytes32(0);
    string public constant name = "PlentiFi.WebAuthn256r1Validator-v0.0.1";
    SclVerifier public immutable sclVerifier;

    // number of signers per smart account
    mapping(address => uint256) public signerCount;
    // mapping of signers for each smart account
    // signers[smartAccount][credId] = publicKey
    mapping(address => mapping(bytes32 => uint256[2])) public signers;

    error InvalidAuthenticatorData();
    error InvalidClientData();
    error InvalidChallenge();

    // Create a struct to hold signature data to avoid stack too deep
    struct SignatureData {
        bytes32 credId;
        bytes1 authenticatorDataFlagMask;
        bytes authenticatorData;
        bytes clientData;
        bytes clientChallenge;
        uint256 clientChallengeOffset;
        uint256[2] rs;
        uint256[2] q2p128;
    }

    event SignerAdded(address indexed smartAccount, bytes32 indexed credId);
    event SignerRemoved(address indexed smartAccount, bytes32 indexed credId);

    constructor(address sclVerifier_) {
        sclVerifier = SclVerifier(sclVerifier_);
    }

    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    ) external payable returns (uint256) {
        return _verify(userOp.sender, userOpHash, userOp.signature);
    }

    function isValidSignatureWithSender(
        address sender,
        bytes32 hash,
        bytes calldata data
    ) external view returns (bytes4) {
        if (_verify(sender, hash, data) == SIG_VALIDATION_SUCCESS_UINT) {
            return ERC1271_MAGICVALUE;
        } else {
            return ERC1271_INVALID;
        }
    }

    function onInstall(bytes calldata data) external payable override {
        require(signerCount[msg.sender] == 0, "Validator already installed");
        (bytes32 credId, uint256[2] memory publicKey) = abi.decode(
            data,
            (bytes32, uint256[2])
        );
        _addSigner(credId, publicKey);
    }

    function onUninstall(bytes calldata data) external payable override {
        delete signers[msg.sender][initializedKey];

        if (data.length == 0) return;

        bytes32[] memory credIds = abi.decode(data, (bytes32[]));
        for (uint256 i = 0; i < credIds.length; i++) {
            _removeSigner(credIds[i]);
        }
    }

    function isModuleType(uint256 moduleTypeId) external pure returns (bool) {
        return moduleTypeId == MODULE_TYPE_VALIDATOR;
    }

    function isInitialized(address smartAccount) external view returns (bool) {
        return signerCount[smartAccount] > 0;
    }

    function addSigner(bytes32 credId, uint256[2] calldata publicKey) external {
        _addSigner(credId, publicKey);
    }

    function removeSigner(bytes32 credId) external {
        _removeSigner(credId);
    }

    function addSigners(bytes calldata data) external {
        (bytes32[] memory credIds, uint256[2][] memory publicKeys) = abi.decode(
            data,
            (bytes32[], uint256[2][])
        );

        for (uint256 i = 0; i < credIds.length; i++) {
            _addSigner(credIds[i], publicKeys[i]);
        }
    }

    function removeSigners(bytes calldata data) external {
        bytes32[] memory credIds = abi.decode(data, (bytes32[]));
        for (uint256 i = 0; i < credIds.length; i++) {
            _removeSigner(credIds[i]);
        }
    }

    function _verify(
        address sender,
        bytes32 hash,
        bytes calldata signatureData
    ) internal view returns (uint256) {
        bool dryRun = signatureData[0] == 0x01;

        // Parse signature data into struct to avoid stack too deep
        SignatureData memory sigData = _parseSigData(signatureData);

        // check if the provided signed message is the same as the hash
        if (!dryRun && hash != bytes32(sigData.clientChallenge)) {
            revert("UserOp hash & challenge mismatch");
        }

        // check if the provided public key is known
        uint256[2] storage publicKey = signers[sender][sigData.credId];

        if (!dryRun && publicKey[0] == 0 && publicKey[1] == 0) {
            revert("Unknown public key");
        }

        uint256 isValid = sclVerifier.verify(
            sigData.authenticatorDataFlagMask,
            sigData.authenticatorData,
            sigData.clientData,
            sigData.clientChallenge,
            sigData.clientChallengeOffset,
            sigData.rs,
            publicKey,
            sigData.q2p128
        );

        return dryRun ? SIG_VALIDATION_FAILED_UINT : isValid;
    }

    function _parseSigData(
        bytes calldata signature
    ) internal pure returns (SignatureData memory) {
        (
            bytes32 credId,
            bytes1 authenticatorDataFlagMask,
            bytes memory authenticatorData,
            bytes memory clientData,
            bytes memory clientChallenge,
            uint256 clientChallengeOffset,
            uint256[2] memory rs,
            uint256[2] memory q2p128
        ) = abi.decode(
                signature,
                (
                    bytes32,
                    bytes1,
                    bytes,
                    bytes,
                    bytes,
                    uint256,
                    uint256[2],
                    uint256[2]
                )
            );

        return
            SignatureData({
                credId: credId,
                authenticatorDataFlagMask: authenticatorDataFlagMask,
                authenticatorData: authenticatorData,
                clientData: clientData,
                clientChallenge: clientChallenge,
                clientChallengeOffset: clientChallengeOffset,
                rs: rs,
                q2p128: q2p128
            });
    }

    function _addSigner(bytes32 credId, uint256[2] memory publicKey) internal {
        signers[msg.sender][credId] = publicKey;
        signerCount[msg.sender]++;
        emit SignerAdded(msg.sender, credId);
    }

    function _removeSigner(bytes32 credId) internal {
        if (
            signers[msg.sender][credId][0] == 0 &&
            signers[msg.sender][credId][1] == 0
        ) {
            revert("Unknown public key");
        }
        delete signers[msg.sender][credId];
        signerCount[msg.sender]--;
        emit SignerRemoved(msg.sender, credId);
    }
}
