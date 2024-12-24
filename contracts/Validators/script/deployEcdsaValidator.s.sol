// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ECDSAValidator} from "../src/ECDSAValidator.sol";

import "forge-std/Script.sol";

// command:
// forge script script/deployEcdsaValidator.s.sol --broadcast -vvv --rpc-url  --private-key
contract DeployECDSAValidator is Script {
    function run() external returns (address) {
        vm.startBroadcast();

        // deploy
        ECDSAValidator ecdsaValidator = new ECDSAValidator();

        console2.log("ECDSAValidator address: ", address(ecdsaValidator));

        vm.stopBroadcast();

        return address(ecdsaValidator);
    }
}
