// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IEntryPoint} from "@account-abstraction/contracts/core/EntryPoint.sol";
import {WebAuthnAccountFactory} from "../../src/Accounts/WebAuthnAccountFactory.sol";
import {PlentiFiContractDeployer} from "./ScDeployer.sol";
import "forge-std/Script.sol";

// command:
// forge script script/DeployScript.sol --broadcast -vvv --rpc-url <RPC_URL> --private-key <YOUR_PRIVATE_KEY>
// verify:  export ETHERSCAN_API_KEY=Your api key
//          forge verify-contract --chain 421614 --compiler-version 0.8.23 0x4DEB5270A0A4948EBa9628172CCB98bC3F9b3e30 src/Paymaster/Paymaster.sol:Paymaster --constructor-args  $(cast abi-encode "constructor(address,address,address)" 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789 0xE9890962Af02D626E69A18fdFCC663da502ebe79 0xe68e8f155A563633aD9D022c0ADdDFB0D61Ae1cE) -> constructor args
contract DeployScript is Script {
    function run() external {
        vm.startBroadcast();

        // Initialize contract addresses
        address entryPoint = address(
            0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789
        );
        address webAuthnVerifier = address(
            0xBcD881D800F6e568964C4d0858040C8DA749e568
        );
        address loginService = address(
            0xE9890962Af02D626E69A18fdFCC663da502ebe79
        );

        // Get the deployed PlentiFiContractDeployer factory instance
        PlentiFiContractDeployer factory = PlentiFiContractDeployer(
            payable(0x29896Bf5E0F260e81e9D2e0F7E98Ca8cb8d12cA1)
        );

        // console2.log("sender is deployer", factory.deployers(msg.sender));

        // Prepare bytecode and salt for deployment
        bytes memory bytecode = abi.encodePacked(
            type(WebAuthnAccountFactory).creationCode,
            abi.encode(entryPoint, webAuthnVerifier, loginService)
        );
        bytes32 salt = keccak256(abi.encodePacked(bytes32(0x188a7cab831f1b1e9e2a417224ffc55d1c2220f7cb330f836d163e03394a9aed)));

        // Deploy the contract using the factory
        address deployedAddress = factory.deploy{gas: 6000000}(bytecode, salt);

        // Log the deployed contract address
        console2.log("WebAuthnAccountFactory deployed at", deployedAddress);

        vm.stopBroadcast();
    }
}
