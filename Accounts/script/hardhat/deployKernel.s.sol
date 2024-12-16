// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

/*
Deploy the Kernel contract
*/

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {PlentiFiAccount} from "../../src/accounts/Account.sol";
import {IEntryPoint} from "../../src/accounts/interfaces/IEntryPoint.sol";

contract DeployKernel is Script {
    function setUp() public {}

    function run() public {
        // Load private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Get entrypoint address from environment
        IEntryPoint entrypointV07 = IEntryPoint(
            vm.envAddress("ENTRYPOINT_V_0_7_0")
        );
        require(
            address(entrypointV07) != address(0),
            "ENTRYPOINT_V_0_7_0 not set in env"
        );

        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Deploy Kernel
        PlentiFiAccount kernel = new PlentiFiAccount(entrypointV07);

        vm.stopBroadcast();

        // Log the deployment address
        console2.log("Kernel deployed to:", address(kernel));
    }
}
