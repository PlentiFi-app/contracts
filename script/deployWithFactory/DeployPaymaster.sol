// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IEntryPoint} from "@account-abstraction/contracts/core/EntryPoint.sol";
import {Paymaster} from "../../src/Paymaster/Paymaster.sol";
import {PlentiFiContractDeployer} from "./ScDeployer.sol";
import "forge-std/Script.sol";

// command:
// forge script script/DeployScript.sol --broadcast -vvv --rpc-url <RPC_URL> --private-key <YOUR_PRIVATE_KEY>
contract DeployScript is Script {
    function run() external {
        vm.startBroadcast();

        IEntryPoint entryPoint = IEntryPoint(
            0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789
        );
        address loginService = address(
            0xE9890962Af02D626E69A18fdFCC663da502ebe79
        );

        // Get the deployed PlentiFiContractDeployer factory instance
        PlentiFiContractDeployer factory = PlentiFiContractDeployer(
            payable(0x29896Bf5E0F260e81e9D2e0F7E98Ca8cb8d12cA1)
        );

        // Prepare bytecode and salt for deployment
        bytes memory bytecode = abi.encodePacked(
            type(Paymaster).creationCode,
            abi.encode(entryPoint, loginService, msg.sender)
        );
        bytes32 salt = keccak256(
            abi.encodePacked(block.timestamp, block.difficulty)
        ); // the paymaster address does not matter here so we use "random" salt

        // Deploy the contract using the factory
        address deployedAddress = factory.deploy{gas: 6000000}(bytecode, salt);

        Paymaster paymaster = Paymaster(deployedAddress);

        console2.log("paymaster owner: ", paymaster.owner());

        // add stake to the paymaster
        paymaster.addStake{value: 1 wei}(60 * 10);
        // paymaster.deposit{value: 0.05 ether}();

        console2.log("Paymaster deployed at", deployedAddress);

        vm.stopBroadcast();
    }
}
