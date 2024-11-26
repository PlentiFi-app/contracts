// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IEntryPoint} from "@account-abstraction/contracts/core/EntryPoint.sol";
import {VerifyingPaymaster} from "../src/Paymaster/Paymaster-example.sol";
import "forge-std/Script.sol";

// command:
// forge script script/DeployPaymaster.sol --broadcast -vvv --rpc-url <RPC_URL> --private-key <YOUR_PRIVATE_KEY>
contract DeployScript is Script {
    function run() external {
        vm.startBroadcast();

        // IEntryPoint entryPoint = IEntryPoint(msg.sender); // only for ganache
        IEntryPoint entryPoint = IEntryPoint(0x0000000071727De22E5E9d8BAf0edAc6f37da032); // entrypoint v0.7 address
        address loginService = address(
            0xd3A113d62BDFB359C9257F3AefD8D813AAB67831
        );

        VerifyingPaymaster paymaster = new VerifyingPaymaster(
            entryPoint,
            loginService
            // msg.sender
        );

        // paymaster.addStake{value: 1 wei}(60 * 10);
        // paymaster.deposit{value: 0.05 ether}();

        console2.log("paymaster", address(paymaster));

        vm.stopBroadcast();
    }
}
