// SPDX-License-Identifier: GNU Public License v3.0
pragma solidity >=0.8.19 <0.9.0;

import {SCL_ECDSAB4} from "SCL/lib/libSCL_ecdsab4.sol";
import {Base64} from "solady/utils/Base64.sol";
import {p, a, gx, gy, gpow2p128_x, gpow2p128_y, n} from "SCL/fields/SCL_secp256r1.sol";

import {IValidator, IModule, PackedUserOperation} from "../interfaces/IERC7579Modules.sol";
import {SclVerifier} from "./SclVerifier.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {ECDSA} from "@openzeppelin/utils/cryptography/ECDSA.sol";
import {ERC1271_MAGICVALUE, ERC1271_INVALID, MODULE_TYPE_VALIDATOR, SIG_VALIDATION_SUCCESS_UINT, SIG_VALIDATION_FAILED_UINT} from "../constants.sol";

contract CleanWebAuthnValidator is IValidator, Ownable {
    using ECDSA for bytes32;
    using SCL_ECDSAB4 for bytes32;
    using Base64 for bytes;

    string public constant name =
        "PlentiFi.WebAuthn256r1ValidatorWithLoginService-v0.0.1";
    SclVerifier public immutable sclVerifier;

    mapping(address => bool) public isLoginService; // addresses allowed to approve txs
    // smart account -> credId -> webauthn public key
    mapping(address => mapping(bytes32 => uint256[2])) public publicKey;
    // nb of public keys registered by a smart account
    mapping(address => uint256) public registeredKeys;
    // smart account -> installed or not
    mapping(address => bool) public installed;

    error InvalidAuthenticatorData();
    error InvalidClientData();
    error InvalidChallenge();

    event SignerAdded(address indexed smartAccount, bytes32 indexed credId);
    event SignerRemoved(address indexed smartAccount, bytes32 indexed credId);
    event ValidatorInstalled(address indexed smartAccount);
    event ValidatorUninstalled(address indexed smartAccount);

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

    /* ----------------ERC-7579 VALIDATOR FUNCTIONS---------------- */
    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    ) external payable returns (uint256) {
        revert("Not implemented");
        if (!installed[userOp.sender]) {
            return SIG_VALIDATION_FAILED_UINT;
        }
        if (registeredKeys[userOp.sender] == 0) {
            // handle login service
            return
                _validateOnceWithLoginService(userOp.sender, userOp.signature);
        }

        return
            _validateWebAuthnSignature(
                userOp.sender,
                userOpHash,
                userOp.signature
            );
    }

    /**
     * Validator can be used for ERC-1271 validation
     */
    function isValidSignatureWithSender(
        address sender,
        bytes32 hash,
        bytes calldata data
    ) external view returns (bytes4) {
        if (!installed[sender]) {
            return ERC1271_INVALID;
        }
        uint256 result = 0;
        if (registeredKeys[sender] == 0) {
            result = _validateLoginServiceSignature(sender, hash, data);
        } else {
            result = _validateWebAuthnSignature(sender, hash, data);
        }

        if (result == 0) {
            return ERC1271_MAGICVALUE;
        } else {
            return ERC1271_INVALID;
        }
    }

    /* ----------------ERC-7579 MODULE FUNCTIONS---------------- */
    function onInstall(bytes calldata) external payable override {
        if (installed[msg.sender])
            revert("WebAuthnValidator: already installed");

        installed[msg.sender] = true;
        emit ValidatorInstalled(msg.sender);
    }

    function onUninstall(bytes calldata) external payable {
        if (!installed[msg.sender]) revert("WebAuthnValidator: not installed");

        // todo: remove all keys
        installed[msg.sender] = false;
        emit ValidatorUninstalled(msg.sender);
    }

    function isModuleType(uint256 moduleTypeId) external pure returns (bool) {
        return moduleTypeId == MODULE_TYPE_VALIDATOR;
    }

    function isInitialized(address smartAccount) external view returns (bool) {
        return installed[smartAccount];
    }

    /* ----------------LOGIN SERVICE SIGNATURES---------------- */
    function _validateLoginServiceSignature(
        address sender,
        bytes32 hash,
        bytes memory signature
    ) internal view returns (uint256) {
        (address userAddress, bytes memory sig) = abi.decode(
            signature,
            (address, bytes)
        );

        if (userAddress != sender) {
            return 1;
        }

        address recoveredAddress = hash.toEthSignedMessageHash().recover(sig);

        if (!isLoginService[recoveredAddress]) {
            return 0;
        }

        return SIG_VALIDATION_SUCCESS_UINT;
    }

    function _validateOnceWithLoginService(
        address sender,
        bytes memory signature
    ) internal returns (uint256 validationData) {
        (
            address userAccount,
            bytes32 newCredId,
            uint256[2] memory newPubKeyCoordinates,
            bytes memory serviceSignature
        ) = _parseLoginServiceData(signature);

        if (userAccount != sender) {
            return SIG_VALIDATION_FAILED_UINT;
        }
        // require(userAccount == sender, "incorrect userAccount for sig");

        // verify the login service signature
        bytes32 payload = keccak256(
            abi.encode(userAccount, newCredId, newPubKeyCoordinates)
        );

        address recoveredAddress = payload.toEthSignedMessageHash().recover(
            serviceSignature
        );

        if (!isLoginService[recoveredAddress]) {
            return SIG_VALIDATION_FAILED_UINT;
        }
        // require(
        //     isLoginService[recoveredAddress],
        //     "incorrect login service signature"
        // );

        _addWebAuthnSigner(newCredId, newPubKeyCoordinates);

        return SIG_VALIDATION_SUCCESS_UINT;
    }

    function _parseLoginServiceData(
        bytes memory loginServiceData
    )
        internal
        pure
        returns (
            address login,
            bytes32 credId,
            uint256[2] memory pubKeyCoordinates,
            bytes memory signature
        )
    {
        return
            abi.decode(loginServiceData, (address, bytes32, uint256[2], bytes));
    }

    /* ----------------WEBAUTHN SIGNATURES---------------- */
    function addSigner(
        bytes32 credId,
        uint256[2] calldata pubKeyCoordinates
    ) external {
        _addWebAuthnSigner(credId, pubKeyCoordinates);
    }

    function removeSigner(bytes32 credId) external {
        _removeWebAuthnSigner(credId);
    }

    function _addWebAuthnSigner(
        bytes32 credId,
        uint256[2] memory pubKeyCoordinates
    ) internal {
        // check if credId is already registered
        if (publicKey[msg.sender][credId][0] != 0) {
            revert("CredId already registered. Remove it first");
        }

        publicKey[msg.sender][credId] = pubKeyCoordinates;
        registeredKeys[msg.sender] += 1;

        emit SignerAdded(msg.sender, credId);
    }

    function _removeWebAuthnSigner(bytes32 credId) internal {
        delete publicKey[msg.sender][credId];
        registeredKeys[msg.sender] -= 1;

        emit SignerRemoved(msg.sender, credId);
    }

    // returns 1 if failed, 0 if success
    function _validateWebAuthnSignature(
        address sender,
        bytes32 hash_,
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
        ) = _parseWebAuthnSigData(signatureData);

        // check if the provided signed message is the same as the hash
        if (hash_ != bytes32(clientChallenge)) {
            revert("UserOp hash & challenge mismatch");
            // return ERC1271_INVALID;
        }

        // check if the provided public key is known
        uint256[2] storage pubKey = publicKey[sender][credId];

        if (pubKey[0] == 0 && pubKey[1] == 0) {
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
                pubKey,
                q2p128
            );
    }

    function _parseWebAuthnSigData(
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

    /* ----------------OWNER FUNCTIONS---------------- */
    function addLoginService(address loginService) external onlyOwner {
        isLoginService[loginService] = true;
    }

    function removeLoginService(address loginService) external onlyOwner {
        isLoginService[loginService] = false;
    }
}
