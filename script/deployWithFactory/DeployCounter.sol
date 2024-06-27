// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19 <0.9.0;

import { Increment } from "../../src/increment/increment.sol";
import { BaseScript } from "../Base.s.sol";
import { Test } from "@forge-std/Test.sol";
import { console2 } from "@forge-std/console2.sol";
import {PlentiFiContractDeployer} from "./ScDeployer.sol";
import {Increment} from "../../src/increment/increment.sol";


contract DeployCounter is BaseScript, Test {
    function run() external broadcast returns (address) {

         // Get the deployed PlentiFiContractDeployer factory instance
        PlentiFiContractDeployer factory = PlentiFiContractDeployer(
            payable(0x29896Bf5E0F260e81e9D2e0F7E98Ca8cb8d12cA1)
        );

        // console2.log("sender is deployer", factory.deployers(msg.sender));

        // Prepare bytecode and salt for deployment
        bytes memory bytecode = abi.encodePacked(
            type(Increment).creationCode,
            abi.encode()
        );
        bytes32 salt = keccak256(abi.encodePacked(bytes32(0x00)));

        // Deploy the contract using the factory
        address deployedAddress = factory.deploy{gas: 6000000}(bytecode, salt);

        // Log the deployed contract address
        console2.log("Counter address", deployedAddress);

        return address(deployedAddress);
    }
}

// forge create --rpc-url <your_rpc_url> --private-key <your_private_key>

// forge script script/DeployScript.sol --broadcast -vvv --rpc-url <RPC_URL> --private-key <YOUR_PRIVATE_KEY>
