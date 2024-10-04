// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IEntryPoint} from "../src/kernel/interfaces/IEntryPoint.sol";
import {IPlentiFiContractDeployer} from "./interfaces/IPlentiFiContractDeployer.sol";
import {FirstImplementation} from "../src/plentifi-deployersv1/FirstImplementation.sol";
import {ProxyFactory} from "../src/plentifi-deployersv1/factory/ProxyFactory.sol";
import {ImplementationManager} from "../src/plentifi-deployersv1/ImplementationManager.sol";
import {Kernel} from "../src/kernel/Kernel.sol";
import {ValidationId} from "../src/kernel/core/ValidationManager.sol";
import {ProxyUpgrader} from "../src/plentifi-deployersv1/ProxyUpgrader.sol";
import {IHook} from "../src/kernel/interfaces/IERC7579Modules.sol";
import {MockValidator} from "../src/kernel/mock/MockValidator.sol";
import{ValidatorLib} from "../src/kernel/utils/ValidationTypeLib.sol";
import "forge-std/Script.sol";

// address deployer: 0xaF06998b48c1cC58261c26dfAe284228C7A65bDF
// command:
// forge script script/test.sol --broadcast -vvv --rpc-url http://127.0.0.1:7545 --private-key 
contract DeployAll is Script {
    function run() external {
        vm.startBroadcast();

        address entrypoint = address(0x159);

        // deploy the implementation
        Kernel implementation = new Kernel(IEntryPoint(entrypoint));

        // deploy the proxyUpgrader
        ProxyUpgrader proxyUpgrader = new ProxyUpgrader();

        address owner = 0x329A76707745586b2992a6837918a8d2b73Dfd3f;

        // deploy the implementationManager
        ImplementationManager implementationManager = new ImplementationManager(owner);

        // initialize the implementationManager
        implementationManager.initialize(
            address(implementation),
            address(proxyUpgrader),
            entrypoint
        );

        // deploy firstImplementation
        FirstImplementation firstImplementation = new FirstImplementation(); // should be done by implementation manager

        console2.log(
            "firstImplementation address: ",
            address(firstImplementation)
        );

        // deploy the ProxyFactory
        ProxyFactory proxyFactory = new ProxyFactory(
            address(implementationManager),
            address(firstImplementation)
        );

        console2.log("proxyFactory address: ", address(proxyFactory));

        // for test purpose, deploy a mocked validator
        // deploy a mocked validator
        MockValidator validator = new MockValidator();

        // function initData() internal view returns (bytes memory) {
        //     return abi.encodeWithSelector(
        //         Kernel.initialize.selector,
        //         rootValidation,
        //         rootValidationConfig.hook,
        //         rootValidationConfig.validatorData,
        //         rootValidationConfig.hookData,
        //         initConfig
        //     );
        // }
        // in ecdsa validator:
        // {hook: IHook(address(0)), hookData: hex"", validatorData: abi.encodePacked(owner)}

        // for init config:
        //     configs[0] = abi.encodeWithSelector(
        //     Kernel.installModule.selector, 1, address(validator), abi.encodePacked(address(0), abi.encode(hex"", hex"", hex""))
        // );
        // initConfig = configs;


        // deploy an account
        bytes memory initData = abi.encode( // WithSelector(
            // Kernel.initialize.selector,
            ValidatorLib.validatorToIdentifier(validator), // ValidationId -> ValidatorLib.validatorToIdentifier(validator address)
            IHook(address(0)), // IHook
            abi.encodePacked(address(0xB7e3a20439afd41fE17856572C81eed1efF85aEB)), // validatorData
            hex"", // hookData
            new bytes[](0) // initConfig -> data pour que le smart account execute direct une tx concernant le validator ? (pour eviter une éeme tx)
        );
        address proxy = proxyFactory.createAccount(
            "loginTest", // login
            bytes32(uint256(0x0123456789)), // salt
            initData
        );

        // check if the proxy is created
        console2.log("proxy address: ", proxy);
        console2.log("proxy code length: ", proxy.code.length);
        // console2.log("get entryPoint: ", Kernel(payable(proxy)).entrypoint());
        // console2.log("get login: ", Kernel(payable(proxy)).login());

        vm.stopBroadcast();
    }
}
