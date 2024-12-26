// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

/*
This script update the Account implementation in the ImplementationManager 
*/

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {ImplementationManager} from "../../src/deployers/ImplementationManager.sol";

contract UpdateAccountImplementation is Script {
    function setUp() public {}

    function run() public {
        // Load private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Load addresses from environment
        address implementationManagerAddress = vm.envAddress("EXPECTED_IMPLEMENTATION_MANAGER_ADDRESS");
        address account = vm.envAddress("ACCOUNT_IMPLEMENTATION_ADDRESS");
        
        require(implementationManagerAddress != address(0), "EXPECTED_IMPLEMENTATION_MANAGER_ADDRESS not set in env");
        require(account != address(0), "ACCOUNT_IMPLEMENTATION_ADDRESS not set in env");

        /* -------------ENSURE CONTRACTS ARE DEPLOYED----------------- */
        require(
            address(implementationManagerAddress).code.length > 0,
            "ImplementationManager not deployed"
        );
        require(
            address(account).code.length > 0,
            "Account not deployed"
        );

        /* -------------INITIALIZE ImplementationManager----------------- */
        ImplementationManager implementationManager = ImplementationManager(implementationManagerAddress);

        // Check if the implementationManager is already initialized
        bool isInitialized = implementationManager.isInitialized();
        require(isInitialized, "ImplementationManager not initialized");

        // Check if account is already set to the new value
        address currentAccount = implementationManager.implementation();
        if (currentAccount == account) {
            console2.log("Account already updated to the new value:", account);
            return;
        }

        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        /* -------------UPDATE account address----------------- */
        implementationManager.setImplementation(account);

        vm.stopBroadcast();

        console2.log("Account updated to:", account);
    }
}