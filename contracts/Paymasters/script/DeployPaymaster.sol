// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IEntryPoint} from "../../common/core/EntryPoint.sol";
import {Paymaster} from "../src/Paymaster.sol";
import "forge-std/Script.sol";

// command:
// forge script script/DeployPaymaster.sol --broadcast -vvv --rpc-url <RPC_URL> --private-key <YOUR_PRIVATE_KEY>
// forge script script/DeployPaymaster.sol --broadcast -vvv --rpc-url http://127.0.0.1:8545 --private-key 
contract DeployScript is Script {
    function run() external {
        vm.startBroadcast();

        IEntryPoint entryPoint = IEntryPoint(0x0000000071727De22E5E9d8BAf0edAc6f37da032); // entrypoint v0.7 address
        address pmSigner = address(
            0xce150a7C1d2e7A2816029b2b723e03b29CcFD212
        );

        Paymaster paymaster = new Paymaster(
            entryPoint,
            pmSigner,
            msg.sender
        );

        paymaster.addStake{value: 1 wei}(60 * 10);
        paymaster.deposit{value: 0.05 ether}();

        console2.log("paymaster", address(paymaster));


        // Paymaster paymaster2 = Paymaster(0x069924aCa1E8a39C75c930536E27900F5bbfD9C9);

        // console2.log("is signer", paymaster2.approvedSigners(pmSigner));


        vm.stopBroadcast();
    }
}
