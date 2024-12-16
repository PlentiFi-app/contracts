// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

/*
Script to run when all the deployment is done:
- ImplementationManager
- FactoryStaker
- AccountFactory

This script: 
- initializes the ImplementationManager with the useful addresses
- register the AccountFactory in the FactoryStaker
*/
// SHOULD BE RAN WITH THE ENV FROM ../.env LOADED

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {ImplementationManager} from "../src/deployers/ImplementationManager.sol";
import {PlentiFiFactoryStaker} from "../src/factory/FactoryStaker.sol";

contract PostDeploymentSetup is Script {
    function setUp() public {}

    function run() public {
        // Load private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Load addresses from environment
        address implementationManagerAddress = vm.envAddress("EXPECTED_IMPLEMENTATION_MANAGER_ADDRESS");
        require(implementationManagerAddress != address(0), "EXPECTED_IMPLEMENTATION_MANAGER_ADDRESS not set in env");

        address factoryStakerAddress = vm.envAddress("EXPECTED_PLENTIFI_FACTORY_STAKER_ADDRESS");
        require(factoryStakerAddress != address(0), "EXPECTED_PLENTIFI_FACTORY_STAKER_ADDRESS not set in env");

        address accountFactoryAddress = vm.envAddress("EXPECTED_PLENTIFI_CANONICAL_FACTORY_ADDRESS");
        require(accountFactoryAddress != address(0), "EXPECTED_PLENTIFI_CANONICAL_FACTORY_ADDRESS not set in env");

        address kernelAddress = vm.envAddress("KERNEL_IMPLEMENTATION_ADDRESS");
        require(kernelAddress != address(0), "KERNEL_IMPLEMENTATION_ADDRESS not set in env");

        address proxyUpgrader = vm.envAddress("PROXY_UPGRADER_ADDRESS");
        require(proxyUpgrader != address(0), "PROXY_UPGRADER_ADDRESS not set in env");

        /* -------------ENSURE CONTRACTS ARE DEPLOYED----------------- */
        require(
            address(implementationManagerAddress).code.length > 0,
            "ImplementationManager not deployed"
        );
        require(
            address(factoryStakerAddress).code.length > 0,
            "FactoryStaker not deployed"
        );
        require(
            address(accountFactoryAddress).code.length > 0,
            "AccountFactory not deployed"
        );
        require(
            address(kernelAddress).code.length > 0,
            "Kernel not deployed"
        );
        require(
            address(proxyUpgrader).code.length > 0,
            "ProxyUpgrader not deployed"
        );

        /* -------------INITIALIZE ImplementationManager----------------- */
        ImplementationManager implementationManager = ImplementationManager(implementationManagerAddress);

        // check if already initialized
        bool isInitialized = implementationManager.isInitialized();
        if (isInitialized) {
            // get the current implementation and proxyUpgrader
            address currentImplementation = implementationManager.implementation();
            address currentProxyUpgrader = implementationManager.proxyUpgrader();

            require(
                currentImplementation == kernelAddress && currentProxyUpgrader == proxyUpgrader,
                "ImplementationManager already initialized with different values"
            );
        } else {
            vm.startBroadcast(deployerPrivateKey);
            
            implementationManager.initialize(kernelAddress, proxyUpgrader);
            
            vm.stopBroadcast();
            console2.log("ImplementationManager initialized with Kernel and ProxyUpgrader");
        }

        /* -------------REGISTER AccountFactory in FactoryStaker----------------- */
        vm.startBroadcast(deployerPrivateKey);

        PlentiFiFactoryStaker factoryStaker = PlentiFiFactoryStaker(factoryStakerAddress);
        factoryStaker.approveFactory(accountFactoryAddress, true);

        vm.stopBroadcast();
        console2.log("AccountFactory registered in FactoryStaker");
    }
}