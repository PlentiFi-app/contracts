// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import "src/kernel/Kernel.sol";

import "src/kernel/factory/KernelFactory.sol";
import "src/kernel/factory/FactoryStaker.sol";

// forge script script/kernelScripts/DeployKernel.s.sol --broadcast -vvv --rpc-url <rpc> --private-key 
contract DeployValidators is Script {
    address constant ENTRYPOINT_0_7_ADDR = 0x0000000071727De22E5E9d8BAf0edAc6f37da032;
    // address constant DEPLOYER = 0x9775137314fE595c943712B0b336327dfa80aE8A;
    address constant EXPECTED_STAKER = 0x329A76707745586b2992a6837918a8d2b73Dfd3f;

    function run() external {
        vm.startBroadcast(/* DEPLOYER */);

        Kernel kernel = new Kernel{salt: 0}(IEntryPoint(ENTRYPOINT_0_7_ADDR));
        console.log("Kernel : ", address(kernel));

        KernelFactory factory = new KernelFactory{salt: 0}(address(kernel));
        console.log("KernelFactory : ", address(factory));

        FactoryStaker staker = FactoryStaker(EXPECTED_STAKER);
        if (!staker.approved(factory)) {
            staker.approveFactory(factory, true);
            console.log("Approved");
        }

        vm.stopBroadcast();
    }
}
