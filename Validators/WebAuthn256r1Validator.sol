// SPDX-License-Identifier: GNU Public License v3.0
pragma solidity ^0.8.0; // >=0.8.19 <0.9.0;

import {IValidator, IModule, PackedUserOperation} from "../../interfaces/IERC7579Modules.sol";
import { WebAuthn256r1 } from "./verifier.sol";
import {ERC1271_MAGICVALUE, ERC1271_INVALID, MODULE_TYPE_VALIDATOR, SIG_VALIDATION_SUCCESS_UINT, SIG_VALIDATION_FAILED_UINT} from "../../constants.sol";

contract FCLValidator is IValidator {
    bytes32 public constant initializedKey = bytes32(0);
    string public constant name = "PlentiFi.WebAuthn256r1Validator-v0.0.1";
    WebAuthn256r1 public immutable webAuthn256r1;

    // Struct to hold signature components to reduce stack usage
    struct SignatureComponents {
        bytes32 credId;
        bytes1 authenticatorDataFlagMask;
        bytes authenticatorData;
        bytes clientData;
        bytes clientChallenge;
        uint256 clientChallengeOffset;
        uint256[2] rs;
        uint256[2] q2p128;
    }

    // number of signers per smart account
    mapping(address => uint256) public signerCount;
    // mapping of signers for each smart account
    // signers[smartAccount][credId] = publicKey
    mapping(address => mapping(bytes32 => uint256[2])) public signers;

    error InvalidAuthenticatorData();
    error InvalidClientData();
    error InvalidChallenge();
    error UnknownPublicKey();
    error ValidatorAlreadyInstalled();
    error UserOpHashChallengeMismatch();

    event SignerAdded(address indexed smartAccount, bytes32 indexed credId);
    event SignerRemoved(address indexed smartAccount, bytes32 indexed credId);

    constructor(address sclVerifier_) {
        webAuthn256r1 = WebAuthn256r1(sclVerifier_);
    }

    /**
     * @inheritdoc IValidator
     */
    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    ) external payable returns (uint256) {
        return _verify(userOp.sender, userOpHash, userOp.signature);
    }

    /**
     * @inheritdoc IValidator
     */
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

    function _verify(
        address sender,
        bytes32 hash,
        bytes calldata signatureData
    ) internal view returns (uint256) {
        // /////
        // return SIG_VALIDATION_SUCCESS_UINT;
        // /////

        bool dryRun = signatureData[0] == 0x01;

        // Parse signature data into a struct to reduce stack usage
        SignatureComponents memory components = _parseSigData(
            signatureData[1:]
        );

        // Validate the hash matches the challenge
        if (!dryRun && hash != bytes32(components.clientChallenge)) {
            revert UserOpHashChallengeMismatch();
        }

        // Get the public key
        uint256[2] storage publicKey = signers[sender][components.credId];

        // Verify the public key exists
        if (!dryRun && publicKey[0] == 0 && publicKey[1] == 0) {
            revert UnknownPublicKey();
        }

        // Verify the signature
        bool isValid = webAuthn256r1.verify(
        // bytes1 authenticatorDataFlagMask,
        // bytes calldata authenticatorData,
        // bytes calldata clientData,
        // bytes calldata clientChallenge,
        // uint256 clientChallengeOffset,
        // uint256[2] calldata rs,
        // uint256[2] calldata Q
            components.authenticatorDataFlagMask,
            components.authenticatorData,
            components.clientData,
            components.clientChallenge,
            components.clientChallengeOffset,
            components.rs,
            publicKey
        );

        if (dryRun) return SIG_VALIDATION_FAILED_UINT;

        return isValid ? SIG_VALIDATION_SUCCESS_UINT : SIG_VALIDATION_FAILED_UINT;
    }

        function _parseSigData(
            bytes calldata signature
        ) internal pure returns (SignatureComponents memory) {
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
                SignatureComponents({
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

    /**
     * @inheritdoc IModule
     */
    function onInstall(bytes calldata data) external payable override {
        if (signerCount[msg.sender] != 0) revert ValidatorAlreadyInstalled();

        // add the first signer
        (bytes32 credId, uint256[2] memory publicKey) = abi.decode(
            data,
            (bytes32, uint256[2])
        );
        _addSigner(credId, publicKey);
        /// _addSigner content
        // signers[msg.sender][credId] = publicKey;
        // signerCount[msg.sender]++;
        // emit SignerAdded(msg.sender, credId);
        ///
    }

    // function onInstall(bytes calldata _data) external payable override {
    //     address owner = address(bytes20(_data[0:20]));
    //     ecdsaValidatorStorage[msg.sender].owner = owner;
    //     emit OwnerRegistered(msg.sender, owner);
    // }

    /**
     * @inheritdoc IModule
     */
    function onUninstall(bytes calldata data) external payable override {
        delete signers[msg.sender][initializedKey];

        if (data.length == 0) return;

        // if the user wants to remove some credIds
        bytes32[] memory credIds = abi.decode(data, (bytes32[]));

        for (uint256 i = 0; i < credIds.length; i++) {
            // _removeSigner(credIds[i]);
        }
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
        return signerCount[smartAccount] > 0;
    }

    //     function addSigner(bytes32 credId, uint256[2] calldata publicKey) external {
    //         _addSigner(credId, publicKey);
    //     }

    //     function removeSigner(bytes32 credId) external {
    //         _removeSigner(credId);
    //     }

    //     function addSigners(bytes calldata data) external {
    //         (bytes32[] memory credIds, uint256[2][] memory publicKeys) = abi.decode(
    //             data,
    //             (bytes32[], uint256[2][])
    //         );

    //         for (uint256 i = 0; i < credIds.length; i++) {
    //             _addSigner(credIds[i], publicKeys[i]);
    //         }
    //     }

    //     function removeSigners(bytes calldata data) external {
    //         bytes32[] memory credIds = abi.decode(data, (bytes32[]));

    //         for (uint256 i = 0; i < credIds.length; i++) {
    //             _removeSigner(credIds[i]);
    //         }
    //     }

    function _addSigner(bytes32 credId, uint256[2] memory publicKey) internal {
        signers[msg.sender][credId] = publicKey;
        signerCount[msg.sender]++;
        emit SignerAdded(msg.sender, credId);
    }

    //     function _removeSigner(bytes32 credId) internal {
    //         delete signers[msg.sender][credId];
    //         signerCount[msg.sender]--;
    //         emit SignerRemoved(msg.sender, credId);
    //     }
}
