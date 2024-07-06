// SPDX-License-Identifier: GNU Public License v3.0
pragma solidity >=0.8.19 <0.9.0;

import {Base64} from "solady/utils/Base64.sol";
import {Ownable} from "openzeppelin/contracts/access/Ownable.sol";
import {IValidator, IModule} from "src/kernel/interfaces/IERC7579Modules.sol";
import {PackedUserOperation} from "src/kernel/interfaces/PackedUserOperation.sol";
import {ERC1271_MAGICVALUE, ERC1271_INVALID, MODULE_TYPE_VALIDATOR, SIG_VALIDATION_FAILED_UINT, SIG_VALIDATION_SUCCESS_UINT} from "src/kernel/types/Constants.sol";
import {ECDSA} from "openzeppelin/contracts/utils/cryptography/ECDSA.sol";

enum SignatureTypes {
    NONE, // use to authenticate a login service
    LOGIN_SERVICE, // used to validate userops
    EIP1271 // used to validate eip1271 login requests
}

// erc7579 validator - installed during init phase of a PlentiFi smart acocunt.
contract BasicLoginService is IValidator, Ownable {
    using ECDSA for bytes32;

    string public constant name = "PlentiFi.BasicLoginServiceValidator-v0.0.1";

    mapping(address => bool) public loginService; // addresses allowed to approve txs
    mapping(address => bool) public consumed; // true when the user has consumed the login service (login service can only be called once)
    mapping(address => bool) public initialized; // true when the module has been initialized (installed)

    modifier onlyLoginServiceOrOwner() {
        require(
            loginService[msg.sender] || owner() == msg.sender,
            "BasicLoginService: caller is not login service or owner"
        );
        _;
    }

    constructor() {}

    /**
     * @inheritdoc IValidator
     */
    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    ) external payable returns (uint256) {
        require(
            !consumed[userOp.sender],
            "BasicLoginService: user has already consumed login service"
        );

        consumed[userOp.sender] = true;
        return _verifyUserOp(userOp.signature, userOpHash);
    }

    /**
     * @inheritdoc IValidator
     */
    function isValidSignatureWithSender(
        address sender,
        bytes32 hash,
        bytes calldata data
    ) external view returns (bytes4) {
        if (_verify1271(data, hash, sender) == SIG_VALIDATION_SUCCESS_UINT) {
            return ERC1271_MAGICVALUE;
        } else {
            return ERC1271_INVALID;
        }
    }

    /**
     * @inheritdoc IModule
     */
    function onInstall(bytes calldata) external payable override {
        initialized[msg.sender] = true;
    }

    /**
     * @inheritdoc IModule
     */
    function onUninstall(bytes calldata) external payable override {
        initialized[msg.sender] = false;
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
    function isInitialized(address smartAccount) public view returns (bool) {
        return initialized[smartAccount];
    }

    function addSigner(address login) external {
        _addSigner(login);
    }

    function removeSigner(address login) external {
        _removeSigner(login);
    }

    function addSigners(address[] calldata logins) external {
        for (uint256 i = 0; i < logins.length; i++) {
            _addSigner(logins[i]);
        }
    }

    function removeSigners(address[] calldata logins) external {
        for (uint256 i = 0; i < logins.length; i++) {
            _removeSigner(logins[i]);
        }
    }

    function _verifyUserOp(
        bytes calldata signatureData,
        bytes32 userOpHash
    ) internal view returns (uint256) {
        // decode the signature
        (
            address user,
            bytes32 opHash,
            bytes memory serviceSignature
        ) = _parseLoginServiceData(signatureData);

        require(
            user == msg.sender,
            "BasicLoginService: user is not the msg.sender"
        );

        require(
            opHash == userOpHash,
            "BasicLoginService: userOp hashes does not match"
        );

        bytes32 payload = keccak256(
            abi.encode(bytes1(uint8(SignatureTypes.LOGIN_SERVICE)), user)
        );

        // verify the signature
        address recoveredAddress = payload.toEthSignedMessageHash().recover(
            serviceSignature
        );

        require(
            loginService[recoveredAddress],
            "incorrect login service signature"
        );

        return SIG_VALIDATION_SUCCESS_UINT;
    }

    function _verify1271(
        bytes calldata serviceSignature,
        bytes32 hash,
        address sender
    ) internal view returns (uint256) {
        require(
            isInitialized(sender),
            "BasicLoginService: module not initialized for sender"
        );
        require(
            !consumed[sender],
            "BasicLoginService: user has already consumed login service"
        );

        // verify the signature
        address recoveredAddress = hash.toEthSignedMessageHash().recover(
            serviceSignature
        );

        if (loginService[recoveredAddress]) {
            return SIG_VALIDATION_SUCCESS_UINT;
        }

        return SIG_VALIDATION_FAILED_UINT;
    }

    function _parseLoginServiceData(
        bytes memory loginServiceData
    )
        internal
        pure
        returns (address user, bytes32 userOpHash, bytes memory signature)
    {
        return abi.decode(loginServiceData, (address, bytes32, bytes)); // todo: we no not necessarily need the user address since it is the userop.sender
    }

    function _addSigner(address service) internal {
        loginService[service] = true;
    }

    function _removeSigner(address service) internal {
        loginService[service] = false;
    }
}
