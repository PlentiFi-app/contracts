// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

/* 
Precompute the addresses of:
- Canonical FactoryStaker
- ImplementationManager
- Canonical Account Factory
*/

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {IDeterministicContractDeployer} from "../../src/accounts/interfaces/IDeterministicContractDeployer.sol";
import {PlentiFiFactoryStaker} from "../../src/factory/FactoryStaker.sol";
import {ImplementationManager} from "../../src/deployers/ImplementationManager.sol";
import {PlentiFiAccountFactory} from "../../src/factory/AccountFactory.sol";

struct AccountFactoryParams {
    address implManager;
    bytes32 factory_id;
    address firstOwner;
    address backupOwner;
}

contract PrecomputeAddresses is Script {
    function setUp() public {}

    function run() public view {
        /* -------------SETUP DETERMINISTIC FACTORY----------------- */
        address deterministicFactoryAddress = vm.envAddress(
            "DETERMINISTIC_FACTORY_ADDRESS"
        );
        require(
            deterministicFactoryAddress != address(0),
            "DETERMINISTIC_FACTORY_ADDRESS not set in env"
        );

        IDeterministicContractDeployer deterministicFactory = IDeterministicContractDeployer(
                deterministicFactoryAddress
            );

        /* -------------GET THE EXPECTED ADDRESSES----------------- */

        // Canonical FactoryStaker
        address factoryStakerOwner = vm.envAddress("FACTORY_STAKER_OWNER");
        require(
            factoryStakerOwner != address(0),
            "FACTORY_STAKER_OWNER not set in env"
        );
        bool locked = false;

        bytes memory factoryStakerConstructorArgs = abi.encode(
            factoryStakerOwner,
            locked
        );
        bytes memory factoryStakerBytecode = abi.encodePacked(
            type(PlentiFiFactoryStaker).creationCode,
            factoryStakerConstructorArgs
        );
        bytes32 factoryStakerSalt = keccak256(factoryStakerBytecode);
        address preComputedFactoryStaker = deterministicFactory.computeAddress(
            factoryStakerBytecode,
            factoryStakerSalt
        );

        // ImplementationManager
        bytes memory implManagerConstructorArgs = abi.encode(
            factoryStakerOwner
        );
        bytes memory implManagerBytecode = abi.encodePacked(
            type(ImplementationManager).creationCode,
            implManagerConstructorArgs
        );
        bytes32 implManagerSalt = keccak256(implManagerBytecode);
        address implManagerPreComputedAddress = deterministicFactory
            .computeAddress(implManagerBytecode, implManagerSalt);

        // Canonical Account Factory
        AccountFactoryParams memory accountFactoryParams = AccountFactoryParams(
            implManagerPreComputedAddress,
            vm.envBytes32("FACTORY_ID"),
            vm.envAddress("FIRST_OWNER"),
            vm.envAddress("BACKUP_OWNER")
        );

        bytes memory accountFactoryConstructorArgs = abi.encode(
            implManagerPreComputedAddress,
            accountFactoryParams.factory_id,
            accountFactoryParams.firstOwner,
            accountFactoryParams.backupOwner
        );
        bytes memory accountFactoryBytecode = abi.encodePacked(
            type(PlentiFiAccountFactory).creationCode,
            accountFactoryConstructorArgs
        );
        bytes32 accountFactorySalt = keccak256(accountFactoryBytecode);
        address accountFactoryPreComputedAddress = deterministicFactory
            .computeAddress(accountFactoryBytecode, accountFactorySalt);

        // Log the precomputed addresses
        console2.log(
            "FactoryStaker precomputed address:",
            preComputedFactoryStaker
        );
        console2.log(
            "ImplementationManager precomputed address:",
            implManagerPreComputedAddress
        );
        console2.log(
            "Canonical PlentiFi Canonical Factory precomputed address:",
            accountFactoryPreComputedAddress
        );
    }
}
