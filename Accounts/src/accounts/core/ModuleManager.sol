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
    /// @notice Address of the installed hook contract
    /// @dev Only one hook can be installed at a time but this 
    /// one hook can handle multiple 'sub-hooks'. This setup increases 
    /// upgradability and simplifies this contract code.
    IHook public hook;

    event HookUpdated(IHook indexed hook);   

    modifier withHook() {
        if (address(hook) == address(0)) {
            _;
            return;
        }
        bytes memory context = hook.preCheck(msg.sender, msg.value, msg.data);
        _;
        hook.postCheck(context);
    } 
}