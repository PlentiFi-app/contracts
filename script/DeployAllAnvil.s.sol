// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19 <0.9.0;

import {EntryPoint} from "@account-abstraction/contracts/core/EntryPoint.sol";
import {WebAuthn256r1} from "../src/Lib/WebAuthn256r1.sol";
import {console2} from "@forge-std/console2.sol";
import {Test} from "@forge-std/Test.sol";
import {WebAuthnAccountFactory} from "../src/Accounts/WebAuthnAccountFactory.sol";
import {Paymaster} from "../src/Paymaster/Paymaster.sol";
import {BaseScript} from "./Base.s.sol";
import {PaperRockScissor721} from "../src/tokens/paperRockScissor721.sol";
import {Tictactoe721} from "../src/tokens/tictactoe721.sol";
import {TestErc20} from "../src/tokens/fakeErc20.sol";
import {TestProducts721} from "../src/tokens/products.sol";

contract DeployAnvil is BaseScript, Test {
    function run() external broadcast returns (address[8] memory) {
        // // deploy the library contract and return the address
        // EntryPoint entryPoint = new EntryPoint();
        // console2.log("entrypoint", address(entryPoint));
        EntryPoint entryPoint = EntryPoint(
            payable(0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789)
        );

        address webAuthnAddr = address(new WebAuthn256r1());
        console2.log("webAuthn", webAuthnAddr);
        
        WebAuthnAccountFactory webAuthnAccountFactory = new WebAuthnAccountFactory(
                entryPoint,
                webAuthnAddr,
                0xE9890962Af02D626E69A18fdFCC663da502ebe79
            );

        console2.log("webAuthnAccountFactory", address(webAuthnAccountFactory));

        PaperRockScissor721 paperRockScissor721 = new PaperRockScissor721(
            "preAlpha-PaperRockScissor721",
            "PAPRS721"
        );
        console2.log("PaperRockScissor721", address(paperRockScissor721));

        Tictactoe721 tictactoe721 = new Tictactoe721(
            "preAlpha-Tictactoe721",
            "PATTT721"
        );
        console2.log("Tictactoe721", address(tictactoe721));

        TestProducts721 testProducts721 = new TestProducts721(
            "preAlpha-TestProducts721",
            "PATP721"
        );
        console2.log("TestProducts721", address(testProducts721));

        // ERCs 20
        TestErc20 wbtc = new TestErc20("Mocked Bitcoin", "WBTC");
        console2.log("WBTC", address(wbtc));

        TestErc20 usdt = new TestErc20("Mocked Tether USD", "USDT");
        console2.log("USDT", address(usdt));


        // Paymaster paymaster = new Paymaster(entryPoint, msg.sender);
        // console2.log("paymaster", address(paymaster));
        // console2.log("paymaster owner", msg.sender);

        // paymaster.addStake{ value: 1 wei }(60 * 10);
        // paymaster.deposit{ value: 10 ether }();
        // console2.log("paymaster deposit", paymaster.getDeposit());

        // EntryPoint.DepositInfo memory DepositInfo = entryPoint.getDepositInfo(address(paymaster));
        // console2.log("paymaster staked", DepositInfo.staked);
        // console2.log("paymaster stake", DepositInfo.stake);
        // console2.log("paymaster deposit", DepositInfo.deposit);
        // console2.log("paymaster unstakeDelaySec", DepositInfo.unstakeDelaySec);
        // console2.log("paymaster withdrawTime", DepositInfo.withdrawTime);

        return [
            address(entryPoint),
            webAuthnAddr,
            // address(paymaster),
            address(webAuthnAccountFactory),
            address(paperRockScissor721),
            address(tictactoe721),
            address(testProducts721),
            address(wbtc),
            address(usdt)
        ];
    }
}
