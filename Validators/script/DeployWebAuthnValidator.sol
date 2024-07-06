// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SclVerifier} from "src/webAuthnValidator/SclVerifier.sol";
import {WebAuthn256r1Validator} from "src/webAuthnValidator/WebAuthn256r1Validator.sol";

import "forge-std/Script.sol";

// address deployer: 0xaF06998b48c1cC58261c26dfAe284228C7A65bDF
// command:
// forge script script/test.sol --broadcast -vvv --rpc-url http://127.0.0.1:7545 --private-key 0x0fc0ab06c0fc17a38ea266f58927c85384e9f4a9f12f42513d15d7c0317acb03
contract DeployAll is Script {
    function run() external {
        vm.startBroadcast();

        // deploy
        SclVerifier sclVerifier = new SclVerifier();

        console2.log("sclVerifier address: ", address(sclVerifier));

        WebAuthn256r1Validator webAuthn256r1Validator = new WebAuthn256r1Validator(
                address(sclVerifier)
            );

        console2.log(
            "webAuthn256r1Validator address: ",
            address(webAuthn256r1Validator)
        );

        vm.stopBroadcast();
    }
}
