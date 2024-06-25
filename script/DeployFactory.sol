// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IEntryPoint } from "@account-abstraction/contracts/core/EntryPoint.sol";
import { WebAuthnAccountFactory } from "../src/Accounts/WebAuthnAccountFactory.sol";
import "forge-std/Script.sol";

// command:
// forge script script/DeployScript.sol --broadcast -vvv --rpc-url <RPC_URL> --private-key <YOUR_PRIVATE_KEY>
contract DeployScript is Script {
  function run() external {
    vm.startBroadcast();

    IEntryPoint entryPoint = IEntryPoint(0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789);
    address webAuthnVerifier = address(0xBcD881D800F6e568964C4d0858040C8DA749e568);
    address loginService = address(0xE9890962Af02D626E69A18fdFCC663da502ebe79);

    WebAuthnAccountFactory factory = new WebAuthnAccountFactory(entryPoint, webAuthnVerifier, loginService);

    console2.log("webAuthnAccountFactory", address(factory));

    vm.stopBroadcast();
  }
}