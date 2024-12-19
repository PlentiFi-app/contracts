// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

/*
Test the user account deployment process by deploying an account (with dummy values)
This script handles:
1. Loading necessary addresses and configuration from environment
2. Generating authorization signature
3. Preparing initialization data
4. Deploying the account through the factory staker
*/

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {PlentiFiFactoryStaker} from "../src/factory/FactoryStaker.sol";
import {PlentiFiAccountFactory} from "../src/factory/AccountFactory.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract TestAccountDeployment is Script {
    using MessageHashUtils for bytes32;

    function setUp() public {}

    /**
     * @notice Generates the authorization signature for account deployment
     * @return The combined signature bytes (r + s + v)
     */
    function generateSignature() internal view returns (bytes memory) {
        // First create the message hash without the Ethereum Signed Message prefix
        bytes32 messageHash = keccak256(
            abi.encode(
                vm.envBytes32("FACTORY_ID"),
                vm.envAddress("EXPECTED_PLENTIFI_CANONICAL_FACTORY_ADDRESS"),
                vm.envBytes32("SALT"),
                uint256(17000) // chain ID (Ethereum holesky)
            )
        );

        // Then create the Ethereum Signed Message hash
        bytes32 ethSignedHash = messageHash.toEthSignedMessageHash();

        // Sign the Ethereum Signed Message hash
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            uint256(vm.envBytes32("FIRST_OWNER_PRIVATE_KEY")),
            ethSignedHash
        );

        // Return the signature in r+s+v format
        return abi.encodePacked(r, s, v);
    }

    /**
     * @notice Prepares the authorization and initialization data for account deployment
     * @return signature The encoded authorization data including signature and validity period
     * @return createData The encoded initialization data for the new account
     */
    function prepareDeploymentData()
        internal
        view
        returns (bytes memory signature, bytes memory createData)
    {
        // Generate and encode authorization data
        signature = generateSignature();

        // Prepare initialization data
        bytes memory rootValidatorAndData = vm.envBytes(
            "DUMMY_VALIDATOR_ADDRESS"
        );

        // optional hook and its data
        bytes memory hookAndData = bytes("0x");

        // other modules and their data
        bytes[] memory initConfig = new bytes[](0);

        // Encode initialization call
        createData = abi.encodeWithSignature(
            "initialize(bytes,bytes[])",
            rootValidatorAndData,
            hookAndData,
            initConfig
        );
    }

    /**
     * @notice Loads and validates factory addresses from environment
     * @return factoryStakerAddress The address of the PlentiFiFactoryStaker contract
     * @return accountFactoryAddress The address of the PlentiFiAccountFactory contract
     */
    function loadAddresses()
        internal
        view
        returns (address factoryStakerAddress, address accountFactoryAddress)
    {
        // Load factory staker address
        factoryStakerAddress = vm.envAddress(
            "EXPECTED_PLENTIFI_FACTORY_STAKER_ADDRESS"
        );
        require(
            factoryStakerAddress != address(0),
            "EXPECTED_PLENTIFI_FACTORY_STAKER_ADDRESS not set in env"
        );

        // Load account factory address
        accountFactoryAddress = vm.envAddress(
            "EXPECTED_PLENTIFI_CANONICAL_FACTORY_ADDRESS"
        );
        require(
            accountFactoryAddress != address(0),
            "EXPECTED_PLENTIFI_CANONICAL_FACTORY_ADDRESS not set in env"
        );
    }

    /**
     * @notice Main execution function that deploys the account
     */
    function run() public {
        // Load deployer's private key
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Deploy the account
        vm.startBroadcast(deployerPrivateKey);

        // Load contract addresses
        (
            address factoryStakerAddress,
            address accountFactoryAddress
        ) = loadAddresses();

        // Prepare deployment data
        (
            bytes memory authorizationData,
            bytes memory createData
        ) = prepareDeploymentData();

        // Get factory staker instance
        PlentiFiFactoryStaker factoryStaker = PlentiFiFactoryStaker(
            factoryStakerAddress
        );

        // Check if account factory is approved
        bool isApproved = factoryStaker.approved(accountFactoryAddress);
        if (!isApproved) {
            console2.log(
                "Account Factory at",
                accountFactoryAddress,
                "not approved for FactoryStaker at",
                factoryStakerAddress
            );
            return;
        }
        console2.log("FactoryStaker is approved");

        factoryStaker.deployWithFactory(
            PlentiFiAccountFactory(accountFactoryAddress),
            authorizationData,
            createData,
            vm.envBytes32("SALT")
        );

        vm.stopBroadcast();
    }
}
