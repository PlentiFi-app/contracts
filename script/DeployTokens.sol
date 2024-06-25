// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PaperRockScissor721} from "../src/tokens/paperRockScissor721.sol";
import {Tictactoe721} from "../src/tokens/tictactoe721.sol";
import {TestErc20} from "../src/tokens/fakeErc20.sol";
import {TestProducts721} from "../src/tokens/products.sol";
import "forge-std/Script.sol";

// command:
// forge script script/DeployScript.sol --broadcast -vvv --rpc-url <RPC_URL> --private-key <YOUR_PRIVATE_KEY>
contract DeployScript is Script {
    function run() external {
        vm.startBroadcast();

        PaperRockScissor721 paperRockScissor721 = new PaperRockScissor721("preAlpha-PaperRockScissor721", "PAPRS721");
        console2.log("PaperRockScissor721", address(paperRockScissor721));

        Tictactoe721 tictactoe721 = new Tictactoe721("preAlpha-Tictactoe721", "PATTT721");
        console2.log("Tictactoe721", address(tictactoe721));

        // ERCs 20
        TestErc20 wbtc = new TestErc20("Mocked Bitcoin", "WBTC");
        console2.log("WBTC", address(wbtc));

        TestErc20 usdt = new TestErc20("Mocked Tether USD", "USDT");
        console2.log("USDT", address(usdt)); 

        TestProducts721 testProducts721 = new TestProducts721("preAlpha-TestProducts721", "PATP721");
        console2.log("TestProducts721", address(testProducts721));

        vm.stopBroadcast();
    }
}
