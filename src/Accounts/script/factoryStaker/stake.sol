// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

/*
Calls the stake function of the factoryStaker contract
*/

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {PlentiFiFactoryStaker} from "../../src/factory/FactoryStaker.sol";
import {IEntryPoint} from "../../src/accounts/interfaces/IEntryPoint.sol";


contract StakeScript is Script {
    function setUp() public {}

    function run() public {
        // Load private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Load contract addresses from environment
        address factoryStakerAddress = vm.envAddress(
            "EXPECTED_PLENTIFI_FACTORY_STAKER_ADDRESS"
        );
        address entryPoint = vm.envAddress("ENTRYPOINT_V_0_7_0");

        // Verify addresses are set
        require(
            factoryStakerAddress != address(0),
            "EXPECTED_PLENTIFI_FACTORY_STAKER_ADDRESS not set in env"
        );
        require(entryPoint != address(0), "ENTRYPOINT_V_0_7_0 not set in env");

        /* -------------ENSURE CONTRACTS ARE DEPLOYED----------------- */
        require(
            address(factoryStakerAddress).code.length > 0,
            "FactoryStaker not deployed"
        );

        /* -------------STAKE----------------- */
        uint256 amountToStake = 1; // wei
        uint32 unstakeDelay = 100; // seconds

        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Get FactoryStaker contract instance
        PlentiFiFactoryStaker factoryStaker = PlentiFiFactoryStaker(
            factoryStakerAddress
        );

        // Perform staking
        factoryStaker.stake{value: amountToStake}(IEntryPoint(entryPoint), unstakeDelay);

        vm.stopBroadcast();

        // Log the staking (using Forge's console2.log)
        console2.log("FactoryStaker staked %d wei", amountToStake);
    }
}
