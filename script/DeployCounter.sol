// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19 <0.9.0;

import { Increment } from "../../src/increment.sol";
import { BaseScript } from "./Base.s.sol";
import { Test } from "@forge-std/Test.sol";
import { console2 } from "@forge-std/console2.sol";


contract DeployCounter is BaseScript, Test {
    function run() external broadcast returns (address) {
        Increment counter = new Increment();
        console2.log("Counter address", address(counter));

        return address(counter);
    }
}

// forge create --rpc-url <your_rpc_url> --private-key <your_private_key>

// forge script script/DeployScript.sol --broadcast -vvv --rpc-url <RPC_URL> --private-key <YOUR_PRIVATE_KEY>