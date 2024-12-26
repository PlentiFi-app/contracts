// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

/* solhint-disable reason-string */
/* solhint-disable no-inline-assembly */

import {BasePaymaster} from "../../common/core/BasePaymaster.sol";
import {_packValidationData} from "../../common/core/Helpers.sol";
import {IEntryPoint} from "../../common/interfaces/IEntryPoint.sol";
import {PackedUserOperation} from "../../common/interfaces/PackedUserOperation.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * @title Paymaster
 * @dev A paymaster contract that validates user operations through an external signer.
 * This paymaster requires user operations to be pre-approved by a trusted external signer
 * before it agrees to pay for the gas fees. The external signer performs off-chain
 * validations before signing the operation.
 */
contract Paymaster is BasePaymaster {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;
    /**
     * @dev Struct containing validation and tracking data for paymaster operations (without the signature)
     * @param validUntil Timestamp until which the operation is valid
     * @param validAfter Timestamp after which the operation becomes valid
     * @param sponsorUUID Unique identifier for tracking sponsored transactions
     * @param allowAnyBundler If true, any bundler can include this operation
     */
    struct PaymasterData {
        uint48 validUntil;
        uint48 validAfter;
        uint128 sponsorUUID;
        bool allowAnyBundler;
    }

    /// @dev Gas allocated for post-operation processing
    uint256 public constant POST_OP_GAS = 0;

    /// @dev Version identifier for this paymaster implementation
    string public constant paymasterId =
        "Plentifi-Paymaster-v0.0.1-entrypointV0.7";

    /// @dev Address of the trusted signer that validates operations
    mapping(address => bool) public approvedSigners;

    /// @dev Address of the trusted bundler that can include operations
    mapping(address => bool) approvedBundlers;

    /**
     * @dev Emitted when a user operation is successfully sponsored
     * @param sender Address of the account that initiated the operation
     * @param sponsorUUID Unique identifier for tracking sponsored transactions
     * @param userOpFeeGasCost Total gas cost incurred
     * @param userOpFeePerGas Fee per gas unit paid by the paymaster
     */
    event UserOperationSponsored(
        address indexed sender,
        uint128 indexed sponsorUUID,
        uint256 userOpFeeGasCost,
        uint256 userOpFeePerGas
    );

    /**
     * @dev Constructor to initialize the paymaster
     * @param _entryPoint Address of the EntryPoint contract
     * @param _verifyingSigner Address of the trusted external signer
     * @param _owner Address that will own this contract
     */
    constructor(
        IEntryPoint _entryPoint,
        address _verifyingSigner,
        address _owner
    ) BasePaymaster(_entryPoint) {
        approvedSigners[_verifyingSigner] = true;
        transferOwnership(_owner);
    }

    // /**
    //  * @dev Generates a hash for signing/validating the user operation
    //  * @param userOp The user operation to hash
    //  * @param pmData Paymaster data associated with the operation
    //  * @return bytes32 Hash of the operation data
    //  */
    function getHash(
        // PackedUserOperation calldata userOp,
        address sender,
        bytes calldata initCode,
        bytes calldata callData,
        PaymasterData memory pmData
    ) public view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    // userOp.sender,
                    // keccak256(userOp.initCode),
                    // keccak256(userOp.callData),
                    sender,
                    keccak256(initCode),
                    keccak256(callData),
                    block.chainid,
                    pmData.validAfter,
                    pmData.validUntil,
                    pmData.sponsorUUID,
                    pmData.allowAnyBundler
                )
            );
    }

    /**
     * @dev Parses the paymaster and data field from the user operation
     * @param paymasterAndData Raw bytes containing paymaster data and signature
     * @return pmData Structured paymaster data
     * @return signature Signature bytes from the trusted signer
     */
    function parsePaymasterAndData(
        bytes calldata paymasterAndData
    )
        internal
        pure
        returns (PaymasterData memory pmData, bytes memory signature)
    {
        pmData.validUntil = uint48(bytes6(paymasterAndData[0:6]));
        pmData.validAfter = uint48(bytes6(paymasterAndData[6:12]));
        pmData.sponsorUUID = uint128(bytes16(paymasterAndData[12:28]));
        pmData.allowAnyBundler = paymasterAndData[28] != 0x00;
        signature = paymasterAndData[29:];
    }

    /**
     * @inheritdoc BasePaymaster
     */
    function _validatePaymasterUserOp(
        PackedUserOperation calldata userOp,
        bytes32 /* userOpHash */,
        uint256 /* maxCost */
    )
        internal
        virtual
        override
        returns (bytes memory context, uint256 validationData)
    {
        (
            PaymasterData memory paymasterData,
            bytes memory signature
        ) = parsePaymasterAndData(
                userOp.paymasterAndData[PAYMASTER_DATA_OFFSET:]
            );

        if (!paymasterData.allowAnyBundler && !approvedBundlers[tx.origin])
            revert("Bundler not approved");

        require(
            signature.length == 64 || signature.length == 65,
            "VerifyingPaymaster: invalid signature length in paymasterAndData"
        );

        // bytes32 hash = getHash(userOp, paymasterData).toEthSignedMessageHash();
        bytes32 hash = getHash(
            userOp.sender,
            userOp.initCode,
            userOp.callData,
            // userOp,
            paymasterData
        ).toEthSignedMessageHash();

        bool isSignatureValid = approvedSigners[ECDSA.recover(hash, signature)];

        bytes memory _context = abi.encode(
            userOp.sender,
            paymasterData.sponsorUUID
        );

        return (
            _context,
            _packValidationData(
                !isSignatureValid,
                paymasterData.validUntil,
                paymasterData.validAfter
            )
        );
    }

    /**
     * @inheritdoc BasePaymaster
     */
    function _postOp(
        PostOpMode mode,
        bytes calldata context,
        uint256 actualGasCost,
        uint256 actualUserOpFeePerGas
    ) internal virtual override {
        (address userOpSender, uint128 sponsorUUID) = abi.decode(
            context,
            (address, uint128)
        );

        uint256 actualGasCostWithPostOp = actualGasCost +
            POST_OP_GAS *
            actualUserOpFeePerGas;

        if (mode != PostOpMode.postOpReverted) {
            emit UserOperationSponsored(
                userOpSender,
                sponsorUUID,
                actualGasCostWithPostOp,
                actualUserOpFeePerGas
            );
        }
    }

    /**
     * @dev Sets the approval status of a signer
     * @param signer Address of the signer
     * @param status Approval status
     */
    function setSigners(address signer, bool status) external onlyOwner {
        approvedSigners[signer] = status;
    }

    /**
     * @dev Sets the approval status of a list of signers
     * @param signers Array of signer addresses
     * @param status Approval status
     */
    function setSignersBatch(
        address[] calldata signers,
        bool[] calldata status
    ) external onlyOwner {
        for (uint256 i = 0; i < signers.length; i++) {
            approvedSigners[signers[i]] = status[i];
        }
    }
}
