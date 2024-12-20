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
     * @param validFrom The timestamp from which the signature is valid
     * @param validUntil The timestamp until which the signature is valid
     * @return The combined signature bytes (r + s + v)
     */
    function generateSignature(
        uint48 validFrom,
        uint48 validUntil
    ) internal view returns (bytes memory) {
        // First create the message hash without the Ethereum Signed Message prefix
        bytes32 messageHash = keccak256(
            abi.encodePacked(
                vm.envBytes32("FACTORY_ID"),
                // vm.envBytes32("SALT"),
                bytes("0x75b1eae7acd61b0d56531a3eab2f5c8fbe1781227ff40a95500ae3f4fa4de32d"),
                validFrom,
                validUntil,
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
     * @notice Main execution function that deploys the account
     */
    function run() public {
        // Deploy the account
        vm.startBroadcast();

        // Set validity period
        uint48 validFrom = 0;
        uint48 validUntil = 1934373395;

        // Generate and encode authorization data
        bytes memory signature = generateSignature(validFrom, validUntil);

        // log the signature
        console2.logBytes(signature);

        vm.stopBroadcast();
    }
}
