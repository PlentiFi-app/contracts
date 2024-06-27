// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

// Import the required libraries and contracts
import "openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

import "@account-abstraction/contracts/core/BasePaymaster.sol";
import "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import "@account-abstraction/contracts/interfaces/UserOperation.sol";
import "@account-abstraction/contracts/core/Helpers.sol";
import {PaymasterErc20} from "./paymasterToken.sol";

/// @dev Inherits from BasePaymaster.
contract TokenPaymaster is BasePaymaster {
    // using UserOperationLib for PackedUserOperation;

    event UserOperationSponsored(
        address indexed user,
        uint256 actualTokenCharge,
        uint256 actualGasCost
    );

    event Received(address indexed sender, uint256 value);

    uint48 constant REFUND_POSTOP_GAS_COST = 65000; // todo: setup the value
    uint48 constant PAYMASTER_DATA_OFFSET = 20;
    PaymasterErc20 public immutable token;

    /// @notice Initializes the TokenPaymaster contract with the given parameters.
    /// @param _entryPoint The EntryPoint contract used in the Account Abstraction infrastructure.
    /// @param _owner The address that will be set as the owner of the contract.
    constructor(
        IEntryPoint _entryPoint,
        address _owner,
        string memory _name,
        string memory _symbol
    ) BasePaymaster(_entryPoint) {
        // transferOwnership(_owner);

        token = new PaymasterErc20(_name, _symbol);

        // token.mint(msg.sender, 100 * 10 ** token.decimals());
        token.mint(
            address(0x39A11728f0df986C12Dcb2fC84a5a34644Ac8f49),
            100 * 10 ** token.decimals()
        );
    }

    /// @notice Allows the contract owner to withdraw a specified amount of tokens from the contract.
    /// @param to The address to transfer the tokens to.
    /// @param amount The amount of tokens to transfer.
    function withdrawToken(address to, uint256 amount) external onlyOwner {
        SafeERC20.safeTransfer(token, to, amount);
    }

    function parsePaymasterAndData(
        bytes memory data
    )
        public
        pure
        returns (
            uint48 validUntil,
            uint48 validAfter,
            uint256 tokenMaxCostAllowed
        )
    {
        (validUntil, validAfter, tokenMaxCostAllowed) = abi.decode(
            data,
            (uint48, uint48, uint256)
        );
    }

    /// @notice Validates a paymaster user operation and calculates the required token amount for the transaction.
    /// @param userOp The user operation data.
    /// @param requiredPreFund The maximum cost (in native token) the paymaster has to prefund.
    function _validatePaymasterUserOp(
        UserOperation calldata userOp,
        bytes32,
        uint256 requiredPreFund
    )
        internal
        override
        returns (bytes memory _context, uint256 validationResult)
    {
        (
            uint48 validUntil,
            uint48 validAfter,
            uint256 tokenMaxCostAllowed
        ) = parsePaymasterAndData(userOp.paymasterAndData[20:]);

        // unchecked {
            uint256 maxFeePerGas = userOp.maxFeePerGas;
            uint256 refundPostopCost = REFUND_POSTOP_GAS_COST * maxFeePerGas;

            uint256 preChargeNative = requiredPreFund + refundPostopCost;

            require(
                refundPostopCost < userOp.verificationGasLimit,
                "PM: postOpGasLimit too low"
            );
            require(
                tokenMaxCostAllowed >= preChargeNative,
                "PM: tokenMaxCostAllowed < preChargeNative"
            );

            // token.burn(userOp.sender, preChargeNative);

            _context = abi.encode(
                preChargeNative,
                userOp.sender,
                userOp.maxFeePerGas
            );

            return (
                _context,
                _packValidationData(false, validUntil, validAfter)
            );
        // }
    }

    /// @notice Performs post-operation tasks, such as updating the token price and refunding excess tokens.
    /// @dev This function is called after a user operation has been executed or reverted.
    /// @param context The context containing the token amount, user sender address and maxFeePerGas.
    /// @param actualGasCost The actual gas cost of the transaction.
    //      and maxPriorityFee (and basefee)
    //      It is not the same as tx.gasprice, which is what the bundler pays.
    function _postOp(
        PostOpMode,
        bytes calldata context,
        uint256 actualGasCost
    ) internal override {
        unchecked {
            (
                uint256 preCharge,
                address userOpSender,
                uint256 maxFeePerGas
            ) = abi.decode(context, (uint256, address, uint256));

            // Refund tokens based on actual gas cost
            uint256 actualChargeNative = actualGasCost +
                REFUND_POSTOP_GAS_COST *
                maxFeePerGas;

            if (preCharge > actualChargeNative) {
                // If the initially provided token amount is greater than the actual amount needed, refund the difference
                // token.mint(userOpSender, preCharge - actualChargeNative);
            } else if (preCharge < actualChargeNative) {
                // Attempt to cover Paymaster's gas expenses by withdrawing the 'overdraft' from the client
                // If the transfer reverts also revert the 'postOp' to remove the incentive to cheat
                // token.burn(userOpSender, actualChargeNative - preCharge);
            }

            emit UserOperationSponsored(
                userOpSender,
                actualChargeNative,
                actualGasCost
            );
        }
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    function withdrawEth(
        address payable recipient,
        uint256 amount
    ) external onlyOwner {
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "withdraw failed");
    }
}
