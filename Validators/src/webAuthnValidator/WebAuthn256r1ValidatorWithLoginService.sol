// SPDX-License-Identifier: GNU Public License v3.0
pragma solidity >=0.8.19 <0.9.0;

import {SCL_ECDSAB4} from "./SCL/lib/libSCL_ecdsab4.sol";
import {Base64} from "solady/utils/Base64.sol";
import {p, a, gx, gy, gpow2p128_x, gpow2p128_y, n} from "./SCL/fields/SCL_secp256r1.sol";

import {IValidator, IModule, PackedUserOperation} from "../interfaces/IERC7579Modules.sol";
import {SclVerifier} from "./SclVerifier.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {ECDSA} from "@openzeppelin/utils/cryptography/ECDSA.sol";
import {ERC1271_MAGICVALUE, ERC1271_INVALID, MODULE_TYPE_VALIDATOR, SIG_VALIDATION_SUCCESS_UINT} from "./constants.sol";

enum SignatureTypes {
    WEBAUTHN, // used to validate webauthn login requests
    LOGIN_SERVICE, // used to validate userops
    LOGIN_SERVICE_EIP1271 // used to validate eip1271 login requests done by login services
}

contract WebAuthn256r1ValidatorWithLoginService is IValidator, Ownable {
    using ECDSA for bytes32;

    bytes32 public constant initializedKey = bytes32(0);
    string public constant name =
        "PlentiFi.WebAuthn256r1ValidatorWithLoginService-v0.0.1";
    SclVerifier public immutable sclVerifier;

    mapping(address => bool) public isLoginService; // addresses allowed to approve txs
    mapping(address => mapping(bytes32 => uint256[2])) public signers;
    mapping(address => bool) public consumed; // true when the user has consumed the login service (ie: has already used the login service to add a signer)(login service can only be called once)
    mapping(address => bool) public initialized; // true when the module has been initialized (installed)

    error InvalidAuthenticatorData();
    error InvalidClientData();
    error InvalidChallenge();

    event SignerAdded(address indexed smartAccount, bytes32 indexed credId);
    event SignerRemoved(address indexed smartAccount, bytes32 indexed credId);

    constructor(
        address owner_,
        address sclVerifier_,
        address[] memory loginServices
    ) Ownable() {
        transferOwnership(owner_);

        sclVerifier = SclVerifier(sclVerifier_);

        for (uint256 i = 0; i < loginServices.length; i++) {
            isLoginService[loginServices[i]] = true;
        }
    }

    /**
     * @inheritdoc IValidator
     */
    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    ) external payable returns (uint256) {
        SignatureTypes signatureType = SignatureTypes(
            uint8(userOp.signature[0])
        );

        if (signatureType == SignatureTypes.LOGIN_SERVICE) {
            _validateLoginServiceOnlySignature(userOp.sender, userOp.signature);
        } else if (signatureType == SignatureTypes.WEBAUTHN) {
            _validateWebAuthnSignature(
                userOp.sender,
                userOpHash,
                userOp.signature
            );
        }
        revert("Invalid signature type");
    }

    /**
     * @inheritdoc IValidator
     */
    function isValidSignatureWithSender(
        address sender,
        bytes32 hash,
        bytes calldata data
    ) external view returns (bytes4) {
        if (
            _validateWebAuthnSignature(sender, hash, data) ==
            SIG_VALIDATION_SUCCESS_UINT
        ) {
            return ERC1271_MAGICVALUE;
        } else {
            return ERC1271_INVALID;
        }
    }

    /**
     * @inheritdoc IModule
     */
    function onInstall(bytes calldata data) external payable override {
        // set initialized to true
        initialized[msg.sender] = true;

        // if data length > 0, add the first signer
        if (data.length == 0) return;

        (bytes32 credId, uint256[2] memory publicKey) = abi.decode(
            data,
            (bytes32, uint256[2])
        );

        _addWebAuthnSigner(credId, publicKey);
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
    function isModuleType(uint256 moduleTypeId) external pure returns (bool) {
        return moduleTypeId == MODULE_TYPE_VALIDATOR;
    }

    /**
     * @inheritdoc IModule
     */
    function isInitialized(address smartAccount) external view returns (bool) {
        return signers[smartAccount][initializedKey][0] != 0;
    }

    function addWebAuthnSigner(
        bytes32 credId,
        uint256[2] calldata publicKey
    ) external {
        _addWebAuthnSigner(credId, publicKey);
    }

    function removeSigner(bytes32 credId) external {
        _removeSigner(credId);
    }

    function addWebAuthnSigners(bytes calldata data) external {
        (bytes32[] memory credIds, uint256[2][] memory publicKeys) = abi.decode(
            data,
            (bytes32[], uint256[2][])
        );

        for (uint256 i = 0; i < credIds.length; i++) {
            _addWebAuthnSigner(credIds[i], publicKeys[i]);
        }
    }

    function removeSigners(bytes calldata data) external {
        bytes32[] memory credIds = abi.decode(data, (bytes32[]));

        for (uint256 i = 0; i < credIds.length; i++) {
            _removeSigner(credIds[i]);
        }
    }

    function _validateLoginServiceOnlySignature(
        address sender,
        bytes memory signature
    ) internal returns (uint256 validationData) {
        require(
            !consumed[msg.sender],
            "user has already consumed login service"
        );

        (
            ,
            // bytes1 ignored
            address userAccount,
            bytes32 newCredId,
            uint256[2] memory newPubKeyCoordinates,
            bytes memory serviceSignature
        ) = _parseLoginServiceData(signature);

        require(userAccount == sender, "incorrect userAccount for sig");

        // verify the login service signature
        bytes32 payload = keccak256(
            abi.encode(
                bytes1(uint8(SignatureTypes.LOGIN_SERVICE)),
                userAccount,
                newCredId,
                newPubKeyCoordinates
            )
        );

        address recoveredAddress = payload.toEthSignedMessageHash().recover(
            serviceSignature
        );

        require(
            isLoginService[recoveredAddress],
            "incorrect login service signature"
        );

        _addWebAuthnSigner(newCredId, newPubKeyCoordinates);

        return SIG_VALIDATION_SUCCESS_UINT;
    }

    function _validateWebAuthnSignature(
        address sender,
        bytes32 hash,
        bytes calldata signatureData
    ) internal view returns (uint256) {
        // decode the signature
        (
            ,
            // bytes1 ignored
            bytes32 credId,
            bytes1 authenticatorDataFlagMask,
            bytes memory authenticatorData,
            bytes memory clientData,
            bytes memory clientChallenge,
            uint256 clientChallengeOffset,
            uint256[2] memory rs,
            uint256[2] memory q2p128 // precomputed of 2**128.publicKey
        ) = _parseWebAuthnSigData(signatureData);

        // check if the provided signed message is the same as the hash
        if (hash != bytes32(clientChallenge)) {
            revert("UserOp hash & challenge mismatch");
            // return ERC1271_INVALID;
        }

        // check if the provided public key is known // todo: check if really usefull regarding the csecp256r1 curve
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

    function _parseLoginServiceData(
        bytes memory loginServiceData
    )
        internal
        pure
        returns (
            bytes1 signatureType,
            address login,
            bytes32 credId,
            uint256[2] memory pubKeyCoordinates,
            bytes memory signature
        )
    {
        return
            abi.decode(
                loginServiceData,
                (bytes1, address, bytes32, uint256[2], bytes)
            );
    }

    function _parseWebAuthnSigData(
        bytes calldata signature
    )
        internal
        pure
        returns (
            bytes1, // ignored (signature type)
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
                    bytes1,
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

    function _addWebAuthnSigner(
        bytes32 credId,
        uint256[2] memory publicKey
    ) internal {
        signers[msg.sender][credId] = publicKey;
        emit SignerAdded(msg.sender, credId);
    }

    function _removeSigner(bytes32 credId) internal {
        delete signers[msg.sender][credId];
        emit SignerRemoved(msg.sender, credId);
    }
}
