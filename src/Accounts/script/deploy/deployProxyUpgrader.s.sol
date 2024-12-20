// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

/*
Deploy the ProxyUpgrader contract
*/

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {ProxyUpgrader} from "../../src/deployers/ProxyUpgrader.sol";

contract DeployProxyUpgrader is Script {
    function setUp() public {}

    function run() public {
        // Load private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Deploy ProxyUpgrader
        ProxyUpgrader proxyUpgrader = new ProxyUpgrader();

        vm.stopBroadcast();

        // Log the deployment address
        console2.log("ProxyUpgrader deployed to:", address(proxyUpgrader));
    }
}
