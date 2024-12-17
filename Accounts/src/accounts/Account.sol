// SPDX-License-Identifier: MIT

pragma solidity ^0.8.27;

import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import {PackedUserOperation} from "./interfaces/PackedUserOperation.sol";
import {TokenCallbackHandler} from "./core/TokenCallbackHandler.sol";
import {IEntryPoint} from "./interfaces/IEntryPoint.sol";
import {ModuleManager} from "./core/ModuleManager.sol";
import {BaseAccount} from "./core/BaseAccount.sol";
import {IValidator, IHook} from "./interfaces/IModules.sol";
import {SIG_VALIDATION_FAILED_UINT, ERC1271_MAGICVALUE, MODULE_TYPE_VALIDATOR, MODULE_TYPE_HOOK, ERC1967_IMPLEMENTATION_SLOT} from "./core/constants.sol";

contract PlentiFiAccount is
    BaseAccount,
    ModuleManager,
    TokenCallbackHandler,
    UUPSUpgradeable
{
    string public constant versionId = "PlentiFiAccount-v0.0.1";

    IEntryPoint public immutable ENTRY_POINT; // entryPointV0.7 expected

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

        if (validators[validator]) {
            return validator.validateUserOp(userOp, userOpHash);
        }

        return SIG_VALIDATION_FAILED_UINT;
    }

    /**
     * @dev ERC-1271 isValidSignature
     *         This function is intended to be used to validate a smart account signature
     * and may forward the call to a validator module
     *
     * @param hash The hash of the data that is signed
     * @param data The data that is signed
     */
    function isValidSignature(
        bytes32 hash,
        bytes calldata data
    ) external view returns (bytes4) {
        // todo: implement
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
     * @dev Install a hook
     * @param hook The address of the hook
     * @param flags The status of the hook (
     * @param data The data to initialize / remove the hook
     */
    function updateHook(
        IHook hook,
        uint8 flags,
        bytes calldata data
    ) public onlyEntryPointOrSelfOrRoot {
        if (address(hook) == address(0)) {
            revert ZeroAddress();
        }

        if (flags != 0) {
            // install or update the hook capabilities
            hook.onInstall(data);
            hooks[hook] = flags;
            hookList.push(address(hook));
            emit HookInstalled(hook);
        } else {
            // uninstall the hook
            hook.onUninstall(data);
            delete hooks[hook];
            for (uint256 i = 0; i < hookList.length; i++) {
                if (hookList[i] == address(hook)) {
                    hookList[i] = hookList[hookList.length - 1];
                    hookList.pop();
                    break;
                }
            }
            emit HookRemoved(hook);
        }
    }

    /* ----------------------OPERATION EXECUTION---------------------- */
    /**
     * execute a transaction (called directly from owner, or by entryPoint)
     */
    function execute(
        address dest,
        uint256 value,
        bytes calldata data
    ) external onlyEntryPointOrSelfOrRoot {
        HookContext[] memory contexts = _executePreHooks(
            value,
            data,
            RUN_ON_EXECUTE
        );
        _call(dest, value, data);
        _executePostHooks(contexts);
    }

    /**
     * execute a sequence of transactions
     * @dev to reduce gas consumption for trivial case (no value), use a zero-length array to mean zero value
     */
    function executeBatch(
        address[] calldata dest,
        uint256[] calldata value,
        bytes[] calldata data
    ) external onlyEntryPointOrSelfOrRoot {
        require(
            dest.length == data.length &&
                (value.length == 0 || value.length == data.length),
            "wrong array length"
        );

        // todo: we might find a way to reduce the gas cost and complexity of this function
        // by using a single context array for all the transactions
        HookContext[][] memory contexts;

        if (value.length == 0) {
            for (uint256 i = 0; i < dest.length; i++) {
                contexts[i] = _executePreHooks(0, data[i], RUN_ON_EXECUTE);
                _call(dest[i], 0, data[i]);
                _executePostHooks(contexts[i]);
            }
        } else {
            for (uint256 i = 0; i < dest.length; i++) {
                contexts[i] = _executePreHooks(
                    value[i],
                    data[i],
                    RUN_ON_EXECUTE
                );
                _call(dest[i], value[i], data[i]);
                _executePostHooks(contexts[i]);
            }
        }
    }

    function _call(address target, uint256 value, bytes memory data) internal {
        (bool success, bytes memory result) = target.call{value: value}(data);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

    /* ----------------------UUPS PROXY FUNCTIONS---------------------- */

    /**
     * @dev Initialize the account with the root validator and the initial configuration
     *
     * @param rootValidatorAndData - The root validator address and its init data
     * @param initConfig - The initial configuration
     */
    function initialize(
        bytes calldata rootValidatorAndData,
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

        rootValidator = IValidator(address(bytes20(rootValidatorAndData[:20])));
        rootValidator.onInstall(rootValidatorAndData[20:]);

        emit RootValidatorUpdated(rootValidator);

        for (uint256 i = 0; i < initConfig.length; i++) {
            bytes calldata config = initConfig[i];
            if (config.length < 21) {
                // 1 byte type + 20 bytes address minimum
                revert("account: invalid config length");
            }

            bytes1 moduleType = config[0];
            address moduleAddress = address(bytes20(config[1:21]));
            bytes calldata moduleData = config[21:];

            if (moduleAddress == address(0)) {
                revert("account: invalid module address");
            }

            // Handle different module types
            if (moduleType == MODULE_TYPE_VALIDATOR) {
                updateValidator(IValidator(moduleAddress), true, moduleData);
            } else if (moduleType == MODULE_TYPE_HOOK) {
                // for hooks, module data = 1 byte flags + hook specific data
                updateHook(
                    IHook(moduleAddress),
                    uint8(moduleData[0]),
                    moduleData[1:]
                );
            } else {
                revert("account: unknown module type");
            }
        }
    }

    /* ----------------------DEFAULT FUNCTIONS---------------------- */
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    fallback() external payable {
        HookContext[] memory contexts = _executePreHooks(
            msg.value,
            msg.data,
            RUN_ON_FALLBACK
        );

        // todo: we could use this space to execute some stuff
        _executePostHooks(contexts);
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
