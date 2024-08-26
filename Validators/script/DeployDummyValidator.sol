// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DummyValidator} from "src/DummyValidator.sol";

import "forge-std/Script.sol";

// command:
// forge script script/DeployDummyValidator.sol --broadcast -vvv --rpc-url  --private-key
contract DeployDummyValidator is Script {
    function run() external returns (address) {
        vm.startBroadcast();

        // deploy
        DummyValidator dummyValidator = new DummyValidator();

        console2.log("DummyValidator address: ", address(dummyValidator));

        vm.stopBroadcast();

        return address(dummyValidator);
    }
}

// deployed on arb sepolia: 0x74fCAE8dE9C0bf25ffE2B23b29645D4b6Ae1021F