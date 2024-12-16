// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

/*
This script update the ProxyUpgrader in the ImplementationManager 
*/

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {ImplementationManager} from "../../src/deployers/ImplementationManager.sol";

contract UpdateProxyUpgrader is Script {
    function setUp() public {}

    function run() public {
        // Load private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Load addresses from environment
        address implementationManagerAddress = vm.envAddress("EXPECTED_IMPLEMENTATION_MANAGER_ADDRESS");
        require(implementationManagerAddress != address(0), "EXPECTED_IMPLEMENTATION_MANAGER_ADDRESS not set in env");
        
        address proxyUpgrader = vm.envAddress("PROXY_UPGRADER_ADDRESS");
        require(proxyUpgrader != address(0), "PROXY_UPGRADER_ADDRESS not set in env");

        /* -------------ENSURE CONTRACTS ARE DEPLOYED----------------- */
        require(
            address(implementationManagerAddress).code.length > 0,
            "ImplementationManager not deployed"
        );
        require(
            address(proxyUpgrader).code.length > 0,
            "ProxyUpgrader not deployed"
        );

        /* -------------INITIALIZE ImplementationManager----------------- */
        ImplementationManager implementationManager = ImplementationManager(implementationManagerAddress);

        // check if the implementationManager is already initialized
        bool isInitialized = implementationManager.isInitialized();
        require(isInitialized, "ImplementationManager not initialized");

        // check if the proxyUpgrader is already set to the new value
        address currentProxyUpgrader = implementationManager.proxyUpgrader();
        if (currentProxyUpgrader == proxyUpgrader) {
            console2.log("ProxyUpgrader already updated to the new value:", proxyUpgrader);
            return;
        }

        /* -------------UPDATE proxyUpgrader address----------------- */
        vm.startBroadcast(deployerPrivateKey);

        implementationManager.setProxyUpgrader(proxyUpgrader);

        vm.stopBroadcast();

        console2.log("proxyUpgrader updated to:", proxyUpgrader);
    }
}