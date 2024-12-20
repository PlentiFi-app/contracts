// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

/*
Deploy the PlentiFiAccountFactory contract using create2
*/

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {PlentiFiAccountFactory} from "../../src/factory/AccountFactory.sol";
import {IDeterministicContractDeployer} from "../../src/accounts/interfaces/IDeterministicContractDeployer.sol";

contract test is Script {
    function setUp() public {}

    function run() public {      
      vm.startBroadcast();
        address deployedAddress = address(new PlentiFiAccountFactory(
            vm.envAddress("EXPECTED_IMPLEMENTATION_MANAGER_ADDRESS"),
            vm.envBytes32("FACTORY_ID"),
            vm.envAddress("FIRST_OWNER"),
            vm.envAddress("BACKUP_OWNER"),
            new address[](0)
        ));

        vm.stopBroadcast();
        console2.log("PlentiFiAccountFactory deployed to:", deployedAddress);
    }
}

