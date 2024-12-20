// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

/*
Deploy the ImplementationManager contract using create2
*/

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {ImplementationManager} from "../../src/deployers/ImplementationManager.sol";
import {IDeterministicContractDeployer} from "../../../common/interfaces/IDeterministicContractDeployer.sol";

contract DeployImplementationManager is Script {
    function setUp() public {}

    function run() public {
        // Load private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        /* -------------CONSTRUCTOR ARGUMENTS----------------- */
        address owner = vm.envAddress("IMPLEMENTATION_MANAGER_OWNER_ADDRESS");
        require(owner != address(0), "IMPLEMENTATION_MANAGER_OWNER_ADDRESS not set in env");

        /* -------------SETUP DETERMINISTIC FACTORY----------------- */
        address deterministicFactoryAddress = vm.envAddress("DETERMINISTIC_FACTORY_ADDRESS");
        require(deterministicFactoryAddress != address(0), "DETERMINISTIC_FACTORY_ADDRESS not set in env");
        
        IDeterministicContractDeployer deterministicFactory = IDeterministicContractDeployer(payable(deterministicFactoryAddress));

        /* -------------SETUP FACTORY FOR DEPLOYMENT----------------- */
        // Get the bytecode of ImplementationManager with constructor arguments
        bytes memory constructorArgs = abi.encode(owner);
        bytes memory bytecode = abi.encodePacked(
            type(ImplementationManager).creationCode,
            constructorArgs
        );
        
        bytes32 salt = keccak256(bytecode);

        /* -------------ENSURE ADDRESS IS THE EXPECTED ONE----------------- */
        address expectedAddress = vm.envAddress("EXPECTED_IMPLEMENTATION_MANAGER_ADDRESS");
        address preComputedAddress = deterministicFactory.computeAddress(bytecode, salt);
        
        console2.log("Expected address:", expectedAddress);
        console2.log("Pre-computed address:", preComputedAddress);
        
        require(
            expectedAddress == preComputedAddress,
            "ImplementationManager computed address does not match expected address"
        );

        // Check if contract is already deployed
        uint256 size;
        assembly {
            size := extcodesize(expectedAddress)
        }
        
        if (size > 0) {
            console2.log("ImplementationManager already deployed at:", expectedAddress);
            return;
        }

        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the ImplementationManager contract
        deterministicFactory.deploy(bytecode, salt);

        vm.stopBroadcast();

        // Verify deployment
        assembly {
            size := extcodesize(expectedAddress)
        }
        require(size > 0, "Deployment failed");

        console2.log("ImplementationManager deployed to:", expectedAddress);
    }
}