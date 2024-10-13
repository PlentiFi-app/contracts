// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { DeterministicContractDeployer } from "../src/ScDeployer.sol";
import "forge-std/Script.sol";

// command:
// forge script script/DeployFactory.sol --broadcast -vvv --rpc-url <RPC_URL> --private-key <YOUR_PRIVATE_KEY>
// verify:  export ETHERSCAN_API_KEY=Your api key
//          forge verify-contract --chain 421614 --compiler-version 0.8.23 contractAddress src/ScDeployer.sol:PlentiFiContractDeployer -> contract path
contract DeployScript is Script {
  function run() external {
    vm.startBroadcast();

    DeterministicContractDeployer factory = new DeterministicContractDeployer();

    console2.log("PlentiFi Factory: ", address(factory));

    vm.stopBroadcast();
  }
}
