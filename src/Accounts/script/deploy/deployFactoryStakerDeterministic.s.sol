// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

/*
Deploy the FactoryStaker contract using create2
*/

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {PlentiFiFactoryStaker} from "../../src/factory/FactoryStaker.sol";
import {IDeterministicContractDeployer} from "../../src/accounts/interfaces/IDeterministicContractDeployer.sol";

contract DeployFactoryStaker is Script {
    function setUp() public {}

    function run() public {
        // Load private key and addresses from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deterministicFactoryAddress = vm.envAddress("DETERMINISTIC_FACTORY_ADDRESS");
        address owner = vm.envAddress("FACTORY_STAKER_OWNER");
        address expectedAddress = vm.envAddress("EXPECTED_PLENTIFI_FACTORY_STAKER_ADDRESS");

        // Verify addresses are set
        require(deterministicFactoryAddress != address(0), "DETERMINISTIC_FACTORY_ADDRESS not set in env");
        require(owner != address(0), "FACTORY_STAKER_OWNER not set in env");
        require(expectedAddress != address(0), "EXPECTED_PLENTIFI_FACTORY_STAKER_ADDRESS not set in env");

        // Get the DeterministicContractDeployer instance
        IDeterministicContractDeployer deterministicFactory = IDeterministicContractDeployer(payable(deterministicFactoryAddress));

        // Get the bytecode and encode constructor arguments
        bool locked = false;
        bytes memory constructorArgs = abi.encode(owner, locked);
        bytes memory bytecode = abi.encodePacked(
            type(PlentiFiFactoryStaker).creationCode,
            constructorArgs
        );
        
        // Generate salt from bytecode
        bytes32 salt = keccak256(bytecode);

        // Compute the expected address
        address preComputedAddress = deterministicFactory.computeAddress(bytecode, salt);
        
        // Verify computed address matches expected address
        require(expectedAddress == preComputedAddress, "Computed address does not match expected address");
        
        console2.log("Expected address:", expectedAddress);
        console2.log("Pre-computed address:", preComputedAddress);

        // Check if contract is already deployed
        uint256 size;
        assembly {
            size := extcodesize(expectedAddress)
        }
        
        if (size > 0) {
            console2.log("FactoryStaker already deployed at:", expectedAddress);
            return;
        }

        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Deploy using create2
        address deployedAddress = address(deterministicFactory.deploy(bytecode, salt));
        
        vm.stopBroadcast();

        console2.log("PlentiFiFactoryStaker deployed to:", deployedAddress);
    }
}