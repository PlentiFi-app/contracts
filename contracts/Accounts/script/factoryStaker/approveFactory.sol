// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {PlentiFiFactoryStaker} from "../../src/factory/FactoryStaker.sol";

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
contract PostDeployScript is Script {
    function setUp() public {}

    function run() public {
        // Load private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Load contract addresses from environment
        address factoryStakerAddress = vm.envAddress(
            "EXPECTED_PLENTIFI_FACTORY_STAKER_ADDRESS"
        );
        address accountFactoryAddress = vm.envAddress(
            "EXPECTED_PLENTIFI_CANONICAL_FACTORY_ADDRESS"
        );

        // Verify addresses are set
        require(
            factoryStakerAddress != address(0),
            "EXPECTED_PLENTIFI_FACTORY_STAKER_ADDRESS not set in env"
        );
        require(
            accountFactoryAddress != address(0),
            "EXPECTED_PLENTIFI_CANONICAL_FACTORY_ADDRESS not set in env"
        );

        // Check if contracts are deployed
        require(
            address(factoryStakerAddress).code.length > 0,
            "FactoryStaker not deployed"
        );
        require(
            address(accountFactoryAddress).code.length > 0,
            "AccountFactory not deployed"
        );

        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Get FactoryStaker contract instance
        PlentiFiFactoryStaker factoryStaker = PlentiFiFactoryStaker(
            factoryStakerAddress
        );

        // Register AccountFactory in FactoryStaker
        factoryStaker.approveFactory(accountFactoryAddress, true);

        vm.stopBroadcast();
    }
}
