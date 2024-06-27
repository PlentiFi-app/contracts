// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19 <0.9.0;

import {EntryPoint} from "@account-abstraction/contracts/core/EntryPoint.sol";
import {WebAuthn256r1} from "../src/Lib/WebAuthn256r1.sol";
import {console2} from "@forge-std/console2.sol";
import {Test} from "@forge-std/Test.sol";
import {WebAuthnAccountFactory} from "../src/Accounts/WebAuthnAccountFactory.sol";
import {Paymaster} from "../src/Paymaster/Paymaster.sol";
import {BaseScript} from "./Base.s.sol";


// forge script script/DeployAll.sol --broadcast -vvv --rpc-url <RPC_URL> --private-key <YOUR_PRIVATE_KEY>
contract DeployAnvil is BaseScript, Test {
    function run() external broadcast returns (address[4] memory) {
        EntryPoint entryPoint = EntryPoint(
            payable(0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789)
        );

        // address webAuthnAddr = address(new WebAuthn256r1());
        // console2.log("webAuthn", webAuthnAddr);
        address webAuthnAddr = address(0xBcD881D800F6e568964C4d0858040C8DA749e568);

        address loginService = address(0xB7e3a20439afd41fE17856572C81eed1efF85aEB);
        
        WebAuthnAccountFactory webAuthnAccountFactory = new WebAuthnAccountFactory(
                entryPoint,
                webAuthnAddr,
                loginService
            );

        console2.log("webAuthnAccountFactory", address(webAuthnAccountFactory));

        address verifyingSigner = address(0xd3A113d62BDFB359C9257F3AefD8D813AAB67831);
        Paymaster paymaster = new Paymaster(entryPoint, verifyingSigner, msg.sender);
        console2.log("paymaster", address(paymaster));
        // console2.log("paymaster owner", msg.sender);

        paymaster.addStake{ value: 1 wei }(60 * 10);
        paymaster.deposit{ value: 0.2 ether }();
        // console2.log("paymaster deposit", paymaster.getDeposit());

    

        return [
            address(entryPoint),
            webAuthnAddr,
            address(paymaster),
            address(webAuthnAccountFactory)
        ];
    }
}
