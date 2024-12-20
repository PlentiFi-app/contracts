// SPDX-License-Identifier: MIT

pragma solidity ^0.8.27;

import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import {PackedUserOperation} from "../../../common/interfaces/PackedUserOperation.sol";
import {TokenCallbackHandler} from "./core/TokenCallbackHandler.sol";
import {IEntryPoint} from "../../../common/interfaces/IEntryPoint.sol";
import {ModuleManager} from "./core/ModuleManager.sol";
import {BaseAccount} from "./core/BaseAccount.sol";
import {IValidator, IHook} from "../../../common/interfaces/IERC7579Modules.sol";

import {SIG_VALIDATION_FAILED_UINT, SIG_VALIDATION_SUCCESS_UINT, ERC1271_MAGICVALUE, MODULE_TYPE_VALIDATOR, MODULE_TYPE_HOOK, ERC1967_IMPLEMENTATION_SLOT} from "../../../common/Constants.sol";

contract PlentiFiAccount is
    BaseAccount,
    ModuleManager,
    TokenCallbackHandler,
    IERC1271,
    UUPSUpgradeable
{
    string public constant versionId = "PlentiFiAccount-v0.0.1";

    IEntryPoint public immutable ENTRY_POINT; // entryPointV0.7 expected

    event BatchExecuted(uint256 opCount);
    event Executed(address indexed dest, uint256 value, bytes data);

    error ZeroAddress();

    event Received(address sender, uint256 amount);
    event Upgraded(address indexed implementation);

    modifier onlyEntryPointOrSelfOrRoot() {
        if (
            msg.sender != address(ENTRY_POINT) &&
            msg.sender != address(this) &&
            msg.sender != address(rootValidator)
        ) {
            revert("account: not from EntryPoint or self or root");
        }

        _;
    }

    constructor(IEntryPoint entryPoint_) {
        ENTRY_POINT = entryPoint_;
    }

    /* ----------------------BASE ACCOUNT FUNCTIONS---------------------- */
    /**
     * @inheritdoc BaseAccount
     */
    function _validateSignature(
        // expect userOp.signature to be:
        // 20 bytes validator address + validator specific data
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    ) internal override returns (uint256 validationData) {
        IValidator validator = IValidator(
            address(bytes20(userOp.signature[:20]))
        );

        if (
            validators[validator] ||
            address(validator) == address(rootValidator)
        ) {
            return validator.validateUserOp(userOp, userOpHash);
        }

        return SIG_VALIDATION_FAILED_UINT;
    }

    /* ----------------------ERC1271 RELATED---------------------- */
    /**
     * @inheritdoc IERC1271
     */
    function isValidSignature(
        bytes32 hash,
        bytes calldata data
    ) external pure returns (bytes4) {
        // todo: implement
        revert("account: isValidSignature");
    }

    // required for erc7579
    function isValidSignatureWithSender(
        address sender,
        bytes32 hash,
        bytes memory signature
    ) public pure returns (bool) {
        // todo: implement
        revert("account: isValidSignatureWithSender");
    }

    function entryPoint() public view override returns (IEntryPoint) {
        return ENTRY_POINT;
    }

    /* ----------------------VALIDATOR MANAGEMENT---------------------- */
    /**
     * @dev Install a validator
     * @param validator The address of the validator
     * @param status The status of the validator (true = enabled, false = disabled)
     * @param data The data to initialize / remove the validator
     *
     * @notice This function is only enables regular validators to be installed
     */
    function updateValidator(
        IValidator validator,
        bool status,
        bytes calldata data
    ) public onlyEntryPointOrSelfOrRoot {
        if (address(validator) == address(0)) {
            revert ZeroAddress();
        }

        if (status) {
            validator.onInstall(data);
            validators[validator] = status;
            emit ValidatorInstalled(validator);
        } else {
            validator.onUninstall(data);
            delete validators[validator];
            emit ValidatorRemoved(validator);
        }
    }

    /**
     * @dev Update the root validator
     *
     * @param newRootValidator - The new root validator
     * @param data - The data to pass to the current root validator to verify the change
     * @param initData - The data to initialize the new root validator
     *
     * data = keccak256(abi.encodePacked(initData, address(rootValidator), address(newRootValidator)))
     */
    function updateRootValidator(
        IValidator newRootValidator,
        bytes calldata initData,
        bytes calldata data
    ) external onlyEntryPointOrSelfOrRoot {
        if (address(newRootValidator) == address(0)) {
            revert ZeroAddress();
        }

        // validate the new root validator
        bytes32 message = keccak256(
            abi.encodePacked(
                initData,
                address(rootValidator),
                address(newRootValidator)
            )
        );

        bytes4 result = rootValidator.isValidSignatureWithSender(
            address(this),
            message,
            data
        );

        if (result != ERC1271_MAGICVALUE) {
            revert("account: invalid data");
        }

        rootValidator = newRootValidator;
        emit RootValidatorUpdated(newRootValidator);
    }

    /* ----------------------HOOKS---------------------- */
    /**
     * @notice Install a hook
     * @dev If the uninstall data is empty, the hook is uninstalled without being called
     * (event if it usually needs to). This protects against bricked hooks.
     * @param hook The address of the hook
     * @param uninstallData The data to uninstall the actual hook
     * @param initData The data to initialize the new hook
     */
    function updateHook(
        IHook hook,
        bytes calldata uninstallData,
        bytes calldata initData
    ) external onlyEntryPointOrSelfOrRoot {
        if (uninstallData.length > 0) {
            hook.onUninstall(uninstallData);
        }

        if (initData.length > 0) {
            hook.onInstall(initData);
        }

        emit HookUpdated(hook);
    }

    /* ----------------------OPERATION EXECUTION---------------------- */
    /**
     * @notice execute a transaction (called directly from owner, or by entryPoint)
     */
    function execute(
        address dest,
        uint256 value,
        bytes calldata data
    ) external onlyEntryPointOrSelfOrRoot {
        // for now we do not support delegate calls for security reasons
        // todo: Add a flag to allow delegate calls with security checks
        // also allow "executor" modules to interact with the account
        _call(dest, value, data);

        emit Executed(dest, value, data);
    }

    /**
     * @notice execute a sequence of transactions
     * @dev to reduce gas consumption for trivial case (no value), use a zero-length array to mean zero value
     */
    function executeBatch(
        address[] calldata dest,
        uint256[] calldata value,
        bytes[] calldata data
    ) external onlyEntryPointOrSelfOrRoot {
        uint256 destLength = dest.length;

        if (value.length != 0) {
            require(value.length == destLength, "value length mismatch");
        }
        require(destLength == data.length, "data length mismatch");

        unchecked {
            // Using unchecked since array bounds are already validated
            for (uint256 i = 0; i < destLength; i++) {
                _call(dest[i], value.length == 0 ? 0 : value[i], data[i]);
            }
        }

        emit BatchExecuted(destLength);
    }

    function _call(address target, uint256 value, bytes memory data) internal {
        (bool success, bytes memory result) = target.call{value: value}(data);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    /* ----------------------UUPS & PROXY FUNCTIONS---------------------- */

    /**
     * @dev Initialize the account with the root validator and the initial configuration
     *
     * @param rootValidatorAndData - The root validator address and its init data
     * @param initConfig - The initial configuration
     */
    function initialize(
        bytes calldata rootValidatorAndData,
        // 0x for no hook, else 20 bytes hook address + hook init data
        bytes calldata hookAndData,
        // each elem is: 1 byte moduleType + 20 bytes moduleAddress + 1 byte module type
        // + module specific data
        bytes[] calldata initConfig
    ) external {
        if (rootValidator != IValidator(address(0))) {
            revert("account: already initialized");
        }
        if (
            rootValidatorAndData.length < 20 ||
            bytes20(rootValidatorAndData[:20]) == bytes20(0)
        ) {
            revert("account: invalid rootValidatorAndData");
        }

        // install root validator
        rootValidator = IValidator(address(bytes20(rootValidatorAndData[:20])));
        rootValidator.onInstall(rootValidatorAndData[20:]);

        emit RootValidatorUpdated(rootValidator);

        // install optional hook
        if (hookAndData.length > 0) {
            IHook hook = IHook(address(bytes20(hookAndData[:20])));
            hook.onInstall(hookAndData[20:]);

            emit HookUpdated(hook);
        }

        for (uint256 i = 0; i < initConfig.length; i++) {
            bytes calldata config = initConfig[i];
            if (config.length < 21) {
                // 1 byte type + 20 bytes address minimum
                revert("account: invalid config length");
            }

            uint8 moduleType = uint8(config[0]);
            address moduleAddress = address(bytes20(config[1:21]));
            bytes calldata moduleData = config[21:];

            if (moduleAddress == address(0)) {
                revert("account: invalid module address");
            }

            // Handle different module types
            if (moduleType == MODULE_TYPE_VALIDATOR) {
                updateValidator(IValidator(moduleAddress), true, moduleData);
            } else {
                revert("account: unknown module type");
            }
        }
    }

    /* ----------------------DEFAULT FUNCTIONS---------------------- */
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    /**
     * @dev Fallback function to call the hook
     */
    fallback() external payable withHook {
        // todo: we could use this space to execute some stuff
    }

    /* ----------------------ERC1967 AND UUPS---------------------- */

    function upgradeTo(
        address _newImplementation
    ) external payable onlyEntryPointOrSelfOrRoot {
        require(
            _newImplementation != address(0),
            "account: new implementation is the zero address"
        );
        assembly {
            sstore(ERC1967_IMPLEMENTATION_SLOT, _newImplementation)
        }
        emit Upgraded(_newImplementation);
    }

    /**
     * @dev function from UUPSUpgradeable that we don't want to expose
     * since it would allow anyone to upgrade the account.
     * @notice To upgrade the account, use the `upgradeTo` function
     */
    function upgradeToAndCall(
        address,
        bytes memory
    ) public payable override onlyEntryPointOrSelfOrRoot {
        revert("account: upgradeToAndCall not allowed");
    }

    /**
     * @inheritdoc UUPSUpgradeable
     */
    function _authorizeUpgrade(
        address newImplementation /* pure */
    ) internal pure override {
        if (newImplementation == address(0)) revert ZeroAddress();
    }
}
