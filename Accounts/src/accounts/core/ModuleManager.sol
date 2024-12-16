// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IValidator, IHook} from "../interfaces/IModules.sol";

contract ModuleManager {
    /* ----------------------VALIDATORS---------------------- */
    mapping(IValidator => bool) public validators;
    IValidator public rootValidator;

    event ValidatorInstalled(IValidator indexed validator);
    event ValidatorRemoved(IValidator indexed validator);
    event RootValidatorUpdated(IValidator indexed rootValidator);

    /* ----------------------HOOKS---------------------- */
    // returned by _executePreHooks and used by _executePostHooks
    struct HookContext {
        IHook hook;
        bytes context;
    }
    // Constants for hook configuration flags
    uint8 constant RUN_ON_EXECUTE = 1 << 3; // 1000
    uint8 constant RUN_ON_RECEIVE = 1 << 1; // 0010
    uint8 constant RUN_ON_FALLBACK = 1 << 2; // 0100

    // Hook -> Bit flags for hook configuration
    mapping(IHook => uint8) public hooks;
    address[] public hookList;

    event HookInstalled(IHook indexed hook);
    event HookRemoved(IHook indexed hook);
    event HookConfigUpdated(IHook indexed hook, uint8 flags);

    /**
     * @notice Execute the pre-hooks allowed to run
     *
     * @param value - The transferred value
     * @param callData - The user operation callData
     * @param flags - The flags to filter the hooks
     */
    function _executePreHooks(
        uint256 value,
        bytes memory callData,
        uint8 flags
    ) internal returns (HookContext[] memory contexts) {
        new bytes[](hookList.length);
        for (uint256 i = 0; i < hookList.length; i++) {
            IHook hook = IHook(hookList[i]);
            if (hooks[hook] & flags == 0) {
                continue;
            }
            contexts[i] = HookContext(hook, _doPreHook(hook, value, callData));
        }
    }

    /**
     * @notice Execute the post-hooks allowed to run
     *
     * @param contexts - The contexts returned by the pre-hooks functions
     */
    function _executePostHooks(HookContext[] memory contexts) internal {
        for (uint256 i = 0; i < contexts.length; i++) {
            _doPostHook(contexts[i].hook, contexts[i].context);
        }
    }

    /**
     * @notice Executes the pre-check hook
     * @param hook The hook to execute
     * @param value The value to check
     * @param callData The user operation callData
     * @return context The context returned by the hook
     */
    function _doPreHook(
        IHook hook,
        uint256 value,
        bytes memory callData
    ) internal returns (bytes memory context) {
        context = hook.preCheck(msg.sender, value, callData);
    }

    /**
     * @notice Executes the post-check hook
     * @param hook The hook to execute
     * @param context The context returned by the pre-check hook
     */
    function _doPostHook(IHook hook, bytes memory context) internal {
        hook.postCheck(context);
    }
}
