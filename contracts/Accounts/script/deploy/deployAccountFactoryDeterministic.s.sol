// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

/*
Deploy the PlentiFiAccountFactory contract using create2
*/

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {PlentiFiAccountFactory} from "../../src/factory/AccountFactory.sol";
import {IDeterministicContractDeployer} from "../../../common/interfaces/IDeterministicContractDeployer.sol";

contract DeployFactory is Script {
    function setUp() public {}

    function run() public {
        // Load private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        /* -------------CONSTRUCTOR ARGUMENTS----------------- */
        address implementationManager = vm.envAddress(
            "EXPECTED_IMPLEMENTATION_MANAGER_ADDRESS"
        );
        bytes32 factory_id = vm.envBytes32("FACTORY_ID");

        address firstOwner =  vm.envAddress("FIRST_OWNER");
        address backupOwner = vm.envAddress("BACKUP_OWNER");

        require(
            implementationManager != address(0),
            "IMPLEMENTATION_ADDRESS not set in env"
        );

        /* -------------SETUP DETERMINISTIC FACTORY----------------- */
        address deterministicFactoryAddress = vm.envAddress(
            "DETERMINISTIC_FACTORY_ADDRESS"
        );
        require(
            deterministicFactoryAddress != address(0),
            "DETERMINISTIC_FACTORY_ADDRESS not set in env"
        );

        IDeterministicContractDeployer deterministicFactory = IDeterministicContractDeployer(
                payable(deterministicFactoryAddress)
            );

        /* -------------SETUP FACTORY FOR DEPLOYMENT----------------- */
        // Get the bytecode with constructor arguments
        bytes memory bytecode = abi.encodePacked(
            type(PlentiFiAccountFactory).creationCode,
            abi.encode(implementationManager, factory_id, firstOwner, backupOwner, new address[](0))
        );

        bytes32 salt = keccak256(bytecode);

        /* -------------ENSURE CANONICAL ADDRESS IS THE EXPECTED ONE----------------- */
        // if id == bytes32(0), then the factory is the canonical factory
        if (factory_id == bytes32(0)) {
            address expectedAddress = vm.envAddress(
                "EXPECTED_PLENTIFI_CANONICAL_FACTORY_ADDRESS"
            );
            address preComputedAddress = deterministicFactory.computeAddress(
                bytecode,
                salt
            );

            console2.log("expectedAddress:", expectedAddress);
            console2.log("preComputedAddress:", preComputedAddress);

            require(
                expectedAddress == preComputedAddress,
                "Canonical Factory computed address does not match expected address"
            );

            // Check if contract is already deployed
            uint256 size;
            assembly {
                size := extcodesize(expectedAddress)
            }
            if (size > 0) {
                console2.log(
                    "PlentiFiAccountFactory already deployed at:",
                    expectedAddress
                );
                return;
            }
        } else {
            console2.log(
                "factory_id != bytes32(0), Canonical Factory address check skipped, stop now if this is not expected"
            );
            // Sleep for 10 seconds to allow manual interruption
            vm.sleep(10);
        }

        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the PlentiFiAccountFactory contract using deterministicFactory
        address deployedAddress = address(
            deterministicFactory.deploy(bytecode, salt)
        );

        vm.stopBroadcast();

        console2.log("PlentiFiAccountFactory deployed to:", deployedAddress);
    }
}

