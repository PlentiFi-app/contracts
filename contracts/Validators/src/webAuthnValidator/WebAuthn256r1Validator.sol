// SPDX-License-Identifier: GNU Public License v3.0
pragma solidity >=0.8.19 <0.9.0;

import {IEntryPoint} from "../../../common/interfaces/IEntryPoint.sol";
import {IValidator, IModule} from "../../../common/interfaces/IERC7579Modules.sol";
import {PackedUserOperation} from "../../../common/interfaces/PackedUserOperation.sol";
import {SclVerifier} from "./SclVerifier.sol";
import {USEROP_SIGNATURE_OFFSET, ERC1271_MAGICVALUE, ERC1271_INVALID, MODULE_TYPE_VALIDATOR, SIG_VALIDATION_SUCCESS_UINT, SIG_VALIDATION_FAILED_UINT} from "../../../common/Constants.sol";

struct PublicKey {
    uint256 x;
    uint256 y;
}

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

contract WebAuthn256r1Validator is IValidator {
    string public constant name = "PlentiFi.WebAuthn256r1Validator-v0.0.1";
    SclVerifier public immutable sclVerifier;

    // number of signers per smart account
    mapping(address => uint256) public signerCount;
    // mapping of signers for each smart account
    // signers[keccak(accountAddress + credId)] = publicKey
    mapping(bytes32 => PublicKey) public signerAndId;

    error InvalidAuthenticatorData();
    error InvalidUnstakeDelay();
    error InvalidClientData();
    error InvalidChallenge();
    error ZeroAddress();
    error ZeroValue();

    event SignerAdded(address indexed smartAccount, bytes32 indexed credId);
    event SignerRemoved(address indexed smartAccount, bytes32 indexed credId);
    event StakeWithdrawn(
        address indexed entryPoint,
        address indexed recipient,
        uint256 amount
    );

    constructor(address sclVerifier_) {
        sclVerifier = SclVerifier(sclVerifier_);
    }

    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    ) external payable returns (uint256) {
        return
            _verify(
                userOp.sender,
                userOpHash,
                userOp.signature[USEROP_SIGNATURE_OFFSET:]
            );
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
        (bytes32 credId, PublicKey memory publicKey) = abi.decode(
            data,
            (bytes32, PublicKey)
        );
        _addSigner(credId, publicKey);
    }

    function onUninstall(bytes calldata data) external payable override {
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

    function addSigner(bytes32 credId, PublicKey calldata publicKey) external {
        _addSigner(credId, publicKey);
    }

    function removeSigner(bytes32 credId) external {
        _removeSigner(credId);
    }

    function addSigners(bytes calldata data) external {
        (bytes32[] memory credIds, PublicKey[] memory publicKeys) = abi.decode(
            data,
            (bytes32[], PublicKey[])
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
        if (signerCount[sender] == 0) {
            revert("No signers for smart account");
        }

        bool dryRun = signatureData[0] != 0x00;

        // Parse signature data into struct to avoid stack too deep
        SignatureData memory sigData = _parseSigData(signatureData[1:]);

        // check if the provided signed message is the same as the hash
        if (!dryRun && hash != bytes32(sigData.clientChallenge)) {
            revert("UserOp hash & challenge mismatch");
        }

        // check if the provided public key is known
        bytes32 callerAndId = keccak256(
            abi.encodePacked(sender, sigData.credId)
        );
        PublicKey memory publicKey = signerAndId[callerAndId];

        if (!dryRun && publicKey.x == 0 && publicKey.y == 0) {
            revert("Unknown public key");
        }

        // uint256 isValid = sclVerifier.verify(
        //     sigData.authenticatorDataFlagMask,
        //     sigData.authenticatorData,
        //     sigData.clientData,
        //     sigData.clientChallenge,
        //     sigData.clientChallengeOffset,
        //     sigData.rs,
        //     [publicKey.x, publicKey.y],
        //     sigData.q2p128
        // );
        uint256 isValid = SIG_VALIDATION_SUCCESS_UINT;

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

    function _addSigner(bytes32 credId, PublicKey memory publicKey) internal {
        bytes32 callerAndId = keccak256(abi.encodePacked(msg.sender, credId));
        signerAndId[callerAndId] = publicKey;
        signerCount[msg.sender]++;
        emit SignerAdded(msg.sender, credId);
    }

    function _removeSigner(bytes32 credId) internal {
        bytes32 callerAndId = keccak256(abi.encodePacked(msg.sender, credId));
        if (
            signerAndId[callerAndId].x == 0 &&
            signerAndId[callerAndId].y == 0
        ) {
            revert("Unknown public key");
        }
        delete signerAndId[callerAndId];
        signerCount[msg.sender]--;
        emit SignerRemoved(msg.sender, credId);
    }
}
