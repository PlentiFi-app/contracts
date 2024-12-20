// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

/*
This script update the kernel implementation in the ImplementationManager 
*/

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {ImplementationManager} from "../../src/deployers/ImplementationManager.sol";

contract UpdateKernelImplementation is Script {
    function setUp() public {}

    function run() public {
        // Load private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Load addresses from environment
        address implementationManagerAddress = vm.envAddress("EXPECTED_IMPLEMENTATION_MANAGER_ADDRESS");
        address kernel = vm.envAddress("KERNEL_IMPLEMENTATION_ADDRESS");
        
        require(implementationManagerAddress != address(0), "EXPECTED_IMPLEMENTATION_MANAGER_ADDRESS not set in env");
        require(kernel != address(0), "KERNEL_IMPLEMENTATION_ADDRESS not set in env");

        /* -------------ENSURE CONTRACTS ARE DEPLOYED----------------- */
        require(
            address(implementationManagerAddress).code.length > 0,
            "ImplementationManager not deployed"
        );
        require(
            address(kernel).code.length > 0,
            "Kernel not deployed"
        );

        /* -------------INITIALIZE ImplementationManager----------------- */
        ImplementationManager implementationManager = ImplementationManager(implementationManagerAddress);

        // Check if the implementationManager is already initialized
        bool isInitialized = implementationManager.isInitialized();
        require(isInitialized, "ImplementationManager not initialized");

        // Check if kernel is already set to the new value
        address currentKernel = implementationManager.implementation();
        if (currentKernel == kernel) {
            console2.log("Kernel already updated to the new value:", kernel);
            return;
        }

        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        /* -------------UPDATE kernel address----------------- */
        implementationManager.setImplementation(kernel);

        vm.stopBroadcast();

        console2.log("Kernel updated to:", kernel);
    }
}