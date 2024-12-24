// SPDX-License-Identifier: MIT
/**
 * @title ECDSAValidator
 * @notice An ERC-7579 compatible validator module that verifies ECDSA signatures
 * @dev Originally derived from zerodev (https://github.com/zerodevapp) and modified by PlentiFi
 * Supports both raw ECDSA signatures and EthSign formatted signatures
 */
pragma solidity ^0.8.0;

import {ECDSA} from "solady/utils/ECDSA.sol";
import {IModule, IValidator} from "../../common/interfaces/IERC7579Modules.sol";
import {PackedUserOperation} from "../../common/interfaces/PackedUserOperation.sol";
import {SIG_VALIDATION_SUCCESS_UINT, SIG_VALIDATION_FAILED_UINT, MODULE_TYPE_VALIDATOR, MODULE_TYPE_HOOK, ERC1271_MAGICVALUE, ERC1271_INVALID, USEROP_SIGNATURE_OFFSET} from "../../common/Constants.sol";

/**
 * @dev Custom errors for better gas efficiency and error handling
 */
error NotInitialized(address account);
error InvalidSignatureLength(uint256 length);
error InvalidOwnerAddress(address owner);
error RecoveredAddressZero();

/////
error UserOpHash(bytes32 userOpHash);
/////

/**
 * @dev Storage structure for the validator
 * @param owner The address authorized to sign transactions
 */
struct ECDSAValidatorStorage {
    address owner;
}

/**
 * @title ECDSAValidator
 * @notice Implements ECDSA signature validation for ERC-7579 smart accounts
 * @dev Supports both standard ECDSA signatures and EthSign message format
 */
contract ECDSAValidator is IValidator {
    /// @notice Emitted when a new owner is registered for a kernel (smart account)
    event OwnerRegistered(address indexed kernel, address indexed owner);

    /// @notice Maps smart accounts to their validator storage
    mapping(address => ECDSAValidatorStorage) public ecdsaValidatorStorage;

    // Constants
    uint256 private constant SIGNATURE_LENGTH = 65;

    /**
     * @notice Installs the validator module for a smart account
     * @dev Sets the owner address from the first 20 bytes of the input data
     * @param _data The installation data containing the owner address
     */
    function onInstall(bytes calldata _data) external payable override {
        address owner = address(bytes20(_data[0:20]));
        if (owner == address(0)) revert InvalidOwnerAddress(owner);

        ecdsaValidatorStorage[msg.sender].owner = owner;
        emit OwnerRegistered(msg.sender, owner);
    }

    /**
     * @inheritdoc IModule
     */
    function onUninstall(bytes calldata) external payable {
        if (!_isInitialized(msg.sender)) revert NotInitialized(msg.sender);
        delete ecdsaValidatorStorage[msg.sender];
    }

    /**
     * @inheritdoc IModule
     */
    function isModuleType(
        uint256 typeID
    ) external pure override returns (bool) {
        return typeID == MODULE_TYPE_VALIDATOR;
    }

    /**
     * @notice Checks if the module is initialized for a given account
     * @param smartAccount The account to check
     * @return bool True if initialized
     */
    function isInitialized(
        address smartAccount
    ) external view override returns (bool) {
        return _isInitialized(smartAccount);
    }

    /**
     * @notice Internal function to check initialization status
     * @param smartAccount The account to check
     * @return bool True if the account has an owner set
     */
    function _isInitialized(address smartAccount) internal view returns (bool) {
        return ecdsaValidatorStorage[smartAccount].owner != address(0);
    }

    /**
     * @notice Validates a signature according to ERC-7579
     * @param userOp The user operation to validate
     * @param userOpHash The hash of the user operation
     * @return uint256 Validation status code
     */
    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    ) external payable override returns (uint256) {
        return
            // remove the first 20 bytes of the signature (the validator address)
            _validateSignature(
                msg.sender,
                userOpHash,
                userOp.signature[USEROP_SIGNATURE_OFFSET:]
            )
                ? SIG_VALIDATION_SUCCESS_UINT
                : SIG_VALIDATION_FAILED_UINT;
    }

    /**
     * @dev Does not use the address parameter, as the sender is always the validator
     * @inheritdoc IValidator
     */
    function isValidSignatureWithSender(
        address sender,
        bytes32 hash,
        bytes calldata sig
    ) external view override returns (bytes4) {
        return
            _validateSignature(sender, hash, sig)
                ? ERC1271_MAGICVALUE
                : ERC1271_INVALID;
    }

    /**
     * @notice Validates an ECDSA signature (ethSign or raw) for a given account
     * @dev Internal function to validate signatures
     * @param account The account to validate for
     * @param hash The message hash
     * @param sig The signature bytes
     * @return bool True if signature is valid
     */
    function _validateSignature(
        address account,
        bytes32 hash,
        bytes calldata sig
    ) internal view returns (bool) {
        // Check initialization
        address owner = ecdsaValidatorStorage[account].owner;
        if (owner == address(0)) revert NotInitialized(account);

        // Validate signature length
        if (sig.length != SIGNATURE_LENGTH) {
            revert InvalidSignatureLength(sig.length);
        }

        // Try raw signature first
        address recovered = ECDSA.recover(hash, sig);
        if (recovered == owner) return true;

        // Try EthSign signature
        recovered = ECDSA.recover(ECDSA.toEthSignedMessageHash(hash), sig);

        return recovered == owner;
    }
}
