// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

/* solhint-disable reason-string */
/* solhint-disable no-inline-assembly */

import "@account-abstraction/contracts/core/BasePaymaster.sol";
import "@account-abstraction/contracts/interfaces/UserOperation.sol";
import "@account-abstraction/contracts/core/Helpers.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";


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
    struct PackedUserOperation {
        address sender;
        uint256 nonce;
        bytes initCode;
        bytes callData;
        bytes32 accountGasLimits;
        uint256 preVerificationGas;
        bytes32 gasFees;
        bytes paymasterAndData;
        bytes signature;
    }

    using UserOperationLib for PackedUserOperation;
    using ECDSA for bytes32;

    address public immutable verifyingSigner;

    uint256 constant POST_OP_GAS_COST = 45000; // todo: check if the value is still accurate

    event UserOperationSponsored(address indexed sender, uint256 actualGasCost);

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
     * 
     * @param userOp the UserOperation to sign
     * @param ethMaxCost the maximum cost of the operation in wei
     * @param validUntil the time until which the signature is valid
     * @param validAfter the time after which the signature is valid
     * 
     * @return hash the hash to sign
     */
    function getHash(
        UserOperation calldata userOp,
        uint256 ethMaxCost,
        uint48 validUntil,
        uint48 validAfter
    ) public view returns (bytes32) {
        // can't use userOp.hash(), since it contains also the paymasterAndData itself.
        address sender = userOp.sender;
        return
            keccak256(
                abi.encode(
                    sender,
                    userOp.nonce,
                    keccak256(userOp.initCode),
                    keccak256(userOp.callData),
                    ethMaxCost,
                    block.chainid,
                    address(this),
                    validUntil,
                    validAfter
                )
            );
    }

    /**
     * Parse the paymasterAndData field, which contains the signature and other data.
     * 
     * @param paymasterAndData the paymasterAndData field from the UserOperation
     * 
     * @return  validUntil the time until which the signature is valid
     * @return  validAfter the time after which the signature is valid
     * @return  ethMaxCostAllowed the maximum cost of the operation in wei
     * @return  signature the signature of the UserOperation
     */
    function parsePaymasterAndData(
        bytes calldata paymasterAndData
    )
        public
        pure
        returns (
            uint48 validUntil,
            uint48 validAfter,
            uint256 ethMaxCostAllowed,
            bytes memory signature
        )
    {

        (validUntil, validAfter, ethMaxCostAllowed, signature) = abi.decode(
            paymasterAndData,
            (uint48, uint48, uint256, bytes)
        );
    }

    /**
     * Validate the UserOperation, by checking the signature.
     * 
     * @param userOp the UserOperation to validate
     * @param maxCost the maximum cost of the operation in wei
     * 
     * @return context the context to pass to the post op
     */
    function _validatePaymasterUserOp(
        UserOperation calldata userOp,
        bytes32, // userOpHash
        uint256 maxCost
    )
        internal
        virtual
        override
        returns (bytes memory context, uint256 validationData)
    {
        (
            uint48 validUntil,
            uint48 validAfter,
            uint256 ethMaxCostAllowed,
            bytes memory signature
        ) = parsePaymasterAndData(userOp.paymasterAndData[20:]);
        // ECDSA library supports both 64 and 65-byte long signatures.
        // we only "require" it here so that the revert reason on invalid signature will be of "VerifyingPaymaster", and not "ECDSA"

        require(
            signature.length == 64 || signature.length == 65,
            "VerifyingPaymaster: invalid signature length in paymasterAndData"
        );

        require(
            ethMaxCostAllowed >= maxCost,
            "VerifyingPaymaster: ethMaxCostAllowed < maxCost"
        );

        bytes32 hash = getHash(
            userOp,
            ethMaxCostAllowed,
            validUntil,
            validAfter
        ).toEthSignedMessageHash();

        // don't revert on signature failure: return SIG_VALIDATION_FAILED
        if (verifyingSigner != ECDSA.recover(hash, signature)) {
            revert("VerifyingPaymaster: invalid signature");
            // return ("", _packValidationData(true, validUntil, validAfter));
        }

        bytes memory _context = abi.encode(userOp);

        // no need for other on-chain validation: entire UserOp should have been checked
        // by the external service prior to signing it.
        return (_context, _packValidationData(false, validUntil, validAfter));
    }

    /**
     * Perform the post-operation
     */
    function _postOp(
        PostOpMode mode,
        bytes calldata context,
        uint256 actualGasCost
    ) internal override {
        // todo: emit event
        UserOperation memory userOp = abi.decode(context, (UserOperation));

        if (mode != PostOpMode.postOpReverted) {
            emit UserOperationSponsored(
                userOp.sender,
                actualGasCost + POST_OP_GAS_COST * 3 * userOp.maxFeePerGas
            );
        }
    }
}
