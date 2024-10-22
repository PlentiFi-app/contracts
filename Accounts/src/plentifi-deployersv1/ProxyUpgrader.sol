// SPDX-License-Identifier: MIT

pragma solidity ^0.8.21;

// import {LibClone} from "solady/utils/LibClone.sol";
import {IImplementationManager} from "./interfaces/IImplementationManager.sol";
import {Create2} from "openzeppelin/contracts/utils/Create2.sol";
import {IFirstImplementation} from "./interfaces/IFirstImplementation.sol";
import {Kernel} from "../kernel/Kernel.sol";
import {ERC1967Proxy} from "openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Initializable} from "openzeppelin/contracts/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
// import {FirstImplementation} from "./FirstImplementation.sol";

import {IValidator} from "../kernel/utils/ValidationTypeLib.sol";
import {ValidatorLib} from "../kernel/utils/ValidationTypeLib.sol";
import {ValidationId} from "../kernel/core/ValidationManager.sol";
import {IHook} from "../kernel/interfaces/IERC7579Modules.sol";

contract ProxyUpgrader {
    string public constant versionId = "ProxyUpgrader-v0.0.1";

    constructor() {}

    function upgrade(
        address proxy,
        address newImplementation,
        bytes calldata initdata
    ) public {
        (
            ValidationId rootValidator,
            IHook hook,
            bytes memory validatorData,
            bytes memory hookData,
            bytes[] memory initConfig
        ) = _parseInitData(initdata);

        // revert("alphabet");

        // upgrade to the last available implementation and initialize the proxy
        IFirstImplementation(proxy).upgradeToAndCall(
            address(newImplementation), // newImplementation
            // initdata,
            abi.encodeWithSelector(
                Kernel.initialize.selector,
                rootValidator, // ValidationId
                hook, // IHook
                validatorData, // validatorData
                hookData, // hookData
                initConfig // initConfig
            ),
            false
        );
    }

    // should return the args of Kernel.initialize
    function _parseInitData(
        bytes calldata initdata
    )
        internal
        pure
        returns (
            ValidationId rootValidator,
            IHook hook,
            bytes memory validatorData,
            bytes memory hookData,
            bytes[] memory initConfig
        )
    {
        return
            abi.decode(initdata, (ValidationId, IHook, bytes, bytes, bytes[]));
        // rootValidator = bytes21("");
        // hook = IHook(address(0));
        // validatorData = new bytes(0);
        // hookData = new bytes(0);
        // initConfig = new bytes[](0);
    }
}
