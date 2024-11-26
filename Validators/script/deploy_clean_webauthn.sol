// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SclVerifier} from "src/webAuthnValidator/SclVerifier.sol";
import {CleanWebAuthnValidator} from "src/webAuthnValidator/clean_webauthn.sol";

import "forge-std/Script.sol";

// address deployer: 0xaF06998b48c1cC58261c26dfAe284228C7A65bDF
// command:
// forge script script/deploy_clean_webauthn.sol --broadcast -vvv --rpc-url http://127.0.0.1:8545 --private-key 
contract DeployAll is Script {
    function run() external {
        vm.startBroadcast();

        // deploy
        SclVerifier sclVerifier = new SclVerifier();

        console2.log("sclVerifier address: ", address(sclVerifier));

        address[] memory loginServices = new address[](1);

        loginServices[0] = address(0x9198aEf8f3019f064d0826eB9e07Fb07a3d3a4BD);

        CleanWebAuthnValidator webAuthn256r1ValidatorWithLoginService = new CleanWebAuthnValidator(
            address(0x9198aEf8f3019f064d0826eB9e07Fb07a3d3a4BD),
            address(sclVerifier),
            loginServices
        );

        console2.log(
            "WebAuthn256r1ValidatorWithLoginService address: ",
            address(webAuthn256r1ValidatorWithLoginService)
        );

        vm.stopBroadcast();
    }
}
