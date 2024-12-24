// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SclVerifier} from "../src/webAuthnValidator/SclVerifier.sol";
import {WebAuthn256r1Validator} from "../src/webAuthnValidator/WebAuthn256r1Validator.sol";
// import {IEntryPoint} from "../../common/interfaces/IEntryPoint.sol";

import "forge-std/Script.sol";

// command:
// forge script script/DeployWebAuthnValidator.sol --broadcast -vvv --rpc-url http://127.0.0.1:7545 --private-key 
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

        // // stake
        // uint256 amountToStake = 1; // wei
        // uint32 unstakeDelay = 100; // seconds
        // address entryPoint = address(0x0000000071727De22E5E9d8BAf0edAc6f37da032);
        // webAuthn256r1Validator.stake{value: amountToStake}(IEntryPoint(entryPoint), unstakeDelay);

        // console2.log("WebAuthn256r1Validator staked %d wei", amountToStake);

        vm.stopBroadcast();
    }
}
