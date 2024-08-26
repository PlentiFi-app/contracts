// SPDX-License-Identifier: GNU Public License v3.0
pragma solidity >=0.8.19 <0.9.0;

import {SCL_ECDSAB4} from "./SCL/lib/libSCL_ecdsab4.sol";
import {Base64} from "solady/utils/Base64.sol";
import {p, a, gx, gy, gpow2p128_x, gpow2p128_y, n} from "./SCL/fields/SCL_secp256r1.sol";

import {IValidator, IModule, PackedUserOperation} from "../interfaces/IERC7579Modules.sol";
import {SclVerifier} from "./SclVerifier.sol";
import {ERC1271_MAGICVALUE, ERC1271_INVALID, MODULE_TYPE_VALIDATOR, SIG_VALIDATION_SUCCESS_UINT} from "../constants.sol";

contract WebAuthn256r1Validator is IValidator {
    bytes32 public constant initializedKey = bytes32(0);
    string public constant name = "PlentiFi.WebAuthn256r1Validator-v0.0.1";
    SclVerifier public immutable sclVerifier;

    mapping(address => mapping(bytes32 => uint256[2])) public signers;

    error InvalidAuthenticatorData();
    error InvalidClientData();
    error InvalidChallenge();

    event SignerAdded(address indexed smartAccount, bytes32 indexed credId);
    event SignerRemoved(address indexed smartAccount, bytes32 indexed credId);

    constructor(address sclVerifier_) {
        sclVerifier = SclVerifier(sclVerifier_);
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

    /**
     * @inheritdoc IModule
     */
    function onInstall(bytes calldata data) external payable override {
        // add the first signer
        (bytes32 credId, uint256[2] memory publicKey) = abi.decode(
            data,
            (bytes32, uint256[2])
        );

        _addSigner(credId, publicKey);
    }

    /**
     * @inheritdoc IModule
     */
    function onUninstall(bytes calldata data) external payable override {
        delete signers[msg.sender][initializedKey];

        if (data.length == 0) return;

        // if the user wants to remove some credIds
        bytes32[] memory credIds = abi.decode(data, (bytes32[]));

        for (uint256 i = 0; i < credIds.length; i++) {
            delete signers[msg.sender][credIds[i]];
        }

        return;
    }

    /**
     * @inheritdoc IModule
     */
    function isModuleType(uint256 moduleTypeId) external view returns (bool) {
        return moduleTypeId == MODULE_TYPE_VALIDATOR;
    }

    /**
     * @inheritdoc IModule
     */
    function isInitialized(address smartAccount) external view returns (bool) {
        return signers[smartAccount][initializedKey][0] != 0;
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
        // decode the signature
        (
            bytes32 credId,
            bytes1 authenticatorDataFlagMask,
            bytes memory authenticatorData,
            bytes memory clientData,
            bytes memory clientChallenge,
            uint256 clientChallengeOffset,
            uint256[2] memory rs,
            uint256[2] memory q2p128 // precomputed of 2**128.publicKey
        ) = _parseSigData(signatureData);

        // check if the provided signed message is the same as the hash
        if (hash != bytes32(clientChallenge)) {
            revert("UserOp hash & challenge mismatch");
            // return ERC1271_INVALID;
        }

        // check if the provided public key is known
        uint256[2] storage publicKey = signers[sender][credId];

        if (publicKey[0] == 0 && publicKey[1] == 0) {
            revert("Unknown public key");
        }

        return
            sclVerifier.verify(
                authenticatorDataFlagMask,
                authenticatorData,
                clientData,
                clientChallenge,
                clientChallengeOffset,
                rs,
                publicKey,
                q2p128
            );
    }

    function _generateMessage(
        bytes1 authenticatorDataFlagMask,
        bytes calldata authenticatorData,
        bytes calldata clientData,
        bytes calldata clientChallenge,
        uint256 clientChallengeOffset
    ) internal pure returns (bytes32 message) {
        unchecked {
            if ((authenticatorData[32] & authenticatorDataFlagMask) == 0)
                revert InvalidAuthenticatorData();
            if (clientChallenge.length == 0) revert InvalidChallenge();
            bytes memory challengeEncoded = bytes(
                Base64.encode(clientChallenge, true, true)
            );
            bytes32 challengeHashed = keccak256(
                clientData[clientChallengeOffset:(clientChallengeOffset +
                    challengeEncoded.length)]
            );
            if (keccak256(challengeEncoded) != challengeHashed)
                revert InvalidClientData();
            message = sha256(
                abi.encodePacked(authenticatorData, sha256(clientData))
            );
        }
    }

    function _parseSigData(
        bytes calldata signature
    )
        internal
        pure
        returns (
            bytes32 credId,
            bytes1 authenticatorDataFlagMask,
            bytes memory authenticatorData,
            bytes memory clientData,
            bytes memory clientChallenge,
            uint256 clientChallengeOffset,
            uint256[2] memory rs,
            uint256[2] memory q2p128
        )
    {
        return
            abi.decode(
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
    }

    function _addSigner(bytes32 credId, uint256[2] memory publicKey) internal {
        signers[msg.sender][credId] = publicKey;
        emit SignerAdded(msg.sender, credId);
    }

    function _removeSigner(bytes32 credId) internal {
        delete signers[msg.sender][credId];
        emit SignerRemoved(msg.sender, credId);
    }
}
