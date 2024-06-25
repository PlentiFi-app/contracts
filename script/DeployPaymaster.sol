// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IEntryPoint} from "@account-abstraction/contracts/core/EntryPoint.sol";
import {WebAuthnAccountFactory} from "../src/Accounts/WebAuthnAccountFactory.sol";
import {Paymaster} from "../src/Paymaster/Paymaster.sol";
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

        Paymaster paymaster = new Paymaster(entryPoint, loginService, msg.sender);

        // paymaster.addStake{value: 1 wei}(60 * 10);
        // paymaster.deposit{value: 0.05 ether}();

        console2.log("paymaster", address(paymaster));

        vm.stopBroadcast();
    }
}
