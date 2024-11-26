// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

/* solhint-disable reason-string */
/* solhint-disable no-inline-assembly */

import "@account-abstraction/contracts/core/BasePaymaster.sol";
import "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import "@account-abstraction/contracts/core/Helpers.sol";
import "openzeppelin/contracts/utils/cryptography/ECDSA.sol";

// import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
/**
 * A sample paymaster that uses external service to decide whether to pay for the UserOp.
 * The paymaster trusts an external signer to sign the transaction.
 * The calling user must pass the UserOp to that external signer first, which performs
 * whatever off-chain verification before signing the UserOp.
 * Note that this signature is NOT a replacement for the account-specific signature:
 * - the paymaster checks a signature to agree to PAY for GAS.
 * - the account checks a signature to prove identity and account ownership.
 */
contract Paymaster is BasePaymaster {
    // using UserOperationLib for PackedUserOperation;
    using ECDSA for bytes32;

    string public constant paymasterId =
        "Plentifi-Paymaster-beta1.0.0-entrypointV0.7";

    address public immutable verifyingSigner;

    event UserOperationSponsored(
        address indexed sender,
        uint256 actualGasCost,
        uint256 actualUserOpFeePerGas
    );

    constructor(
        IEntryPoint _entryPoint,
        address _verifyingSigner,
        address _owner
    ) BasePaymaster(_entryPoint) {
        verifyingSigner = _verifyingSigner;

        // need to transfer ownership because when deploying through the factory, the factory is the owner and we cannot change that.
        transferOwnership(_owner);
    }

    /**
     * return the hash we're going to sign off-chain (and validate on-chain)
     * this method is called by the off-chain service, to sign the request.
     * it is called on-chain from the validatePaymasterUserOp, to validate the signature.
     * note that this signature covers all fields of the UserOperation, except the "paymasterAndData",
     * which will carry the signature itself.
     */
    function getHash(
        PackedUserOperation calldata userOp,
        uint48 validUntil,
        uint48 validAfter
    ) public view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    userOp.sender,
                    userOp.nonce,
                    keccak256(userOp.initCode),
                    keccak256(userOp.callData),
                    block.chainid,
                    address(this),
                    validUntil,
                    validAfter
                )
            );
    }

    function parsePaymasterAndData(
        bytes calldata paymasterAndData
    )
        internal
        pure
        returns (uint48 validUntil, uint48 validAfter, bytes memory signature)
    {
        (validUntil, validAfter, signature) = abi.decode(
            paymasterAndData,
            (uint48, uint48, bytes)
        );
    }

    /**
     * @inheritdoc BasePaymaster
     */
    function _validatePaymasterUserOp(
        PackedUserOperation calldata userOp,
        bytes32, // userOpHash -> // todo: add user ophash in the paymaster signed data
        uint256 // maxCost // todo: check if max cost includes postOp cost or not ?
    )
        internal
        virtual
        override
        returns (bytes memory context, uint256 validationData)
    {
        (
            uint48 validUntil,
            uint48 validAfter,
            bytes memory signature
        ) = parsePaymasterAndData(
                userOp.paymasterAndData[PAYMASTER_DATA_OFFSET:] // PAYMASTER_DATA_OFFSET = len(address) + len(PAYMASTER_VALIDATION_GAS)
            );
        // revert("alphabet");

        // ECDSA library supports both 64 and 65-byte long signatures.
        // we only "require" it here so that the revert reason on invalid signature will be of "VerifyingPaymaster", and not "ECDSA"
        require(
            signature.length == 64 || signature.length == 65,
            "VerifyingPaymaster: invalid signature length in paymasterAndData"
        );

        bytes32 hash = getHash(userOp, validUntil, validAfter)
            .toEthSignedMessageHash();

        // don't revert on signature failure: return SIG_VALIDATION_FAILED
        if (verifyingSigner != ECDSA.recover(hash, signature)) {
            revert("VerifyingPaymaster: invalid signature"); // for debug
            // return ("", _packValidationData(true, validUntil, validAfter));
        }

        bytes memory _context = abi.encode(userOp);

        // no need for other on-chain validation: entire UserOp should have been checked
        // by the external service prior to signing it.
        return (_context, _packValidationData(false, validUntil, validAfter));

        // return (_context, _packValidationData(false, uint48(block.timestamp+10*60), 1));
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
        PackedUserOperation memory userOp = abi.decode(
            context,
            (PackedUserOperation)
        );

        if (mode != PostOpMode.postOpReverted) {
            emit UserOperationSponsored(
                userOp.sender,
                actualGasCost,
                actualUserOpFeePerGas
            );
        }
    }
}
