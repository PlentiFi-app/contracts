// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IEntryPoint} from "../../common/core/EntryPoint.sol";
import {Paymaster} from "../src/Paymaster.sol";
import "forge-std/Script.sol";

// command:
// forge script script/DeployPaymaster.sol --broadcast -vvv --rpc-url <RPC_URL> --private-key <YOUR_PRIVATE_KEY>
// forge script script/DeployPaymaster.sol --broadcast -vvv --rpc-url http://127.0.0.1:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
contract DeployScript is Script {
    function run() external {
        vm.startBroadcast();

        // IEntryPoint entryPoint = IEntryPoint(msg.sender); // only for ganache
        IEntryPoint entryPoint = IEntryPoint(0x0000000071727De22E5E9d8BAf0edAc6f37da032); // entrypoint v0.7 address
        address loginService = address(
            0xce150a7C1d2e7A2816029b2b723e03b29CcFD212
        );

        Paymaster paymaster = new Paymaster(
            entryPoint,
            loginService,
            msg.sender
        );

        // paymaster.addStake{value: 1 wei}(60 * 10);
        // paymaster.deposit{value: 0.05 ether}();

        console2.log("paymaster", address(paymaster));

        vm.stopBroadcast();
    }
}
