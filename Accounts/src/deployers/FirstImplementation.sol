// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import {IFirstImplementation} from "./interfaces/IFirstImplementation.sol";

/**
 * @title FirstImplementation
 * @notice Base implementation for ERC1967 proxies deployed by the factory
 * @dev This contract MUST never change and MUST have the same address on any EVM compatible chain
 * It serves as a minimal implementation that only handles upgrades
 */
contract FirstImplementation is UUPSUpgradeable {
    error ZeroAddressImplementation();

    uint256 test = 12;
    string public constant versionId = "FirstImplementation-v0.0.1";

    /**
     * @notice Authorizes an upgrade to a new implementation
     * @dev This function is required by UUPS pattern
     * @param newImplementation Address of the new implementation
     */
    function _authorizeUpgrade(
        address newImplementation
    ) internal pure override {
        if (newImplementation == address(0)) revert ZeroAddressImplementation();
    }

    /**
     * @notice Allows the contract to receive ETH
     * @dev Required for proxies that need to receive ETH during initialization
     */
    receive() external payable {}

    /**
     * @notice Fallback function for compatibility
     * @dev Required for proxies that need to receive ETH during initialization
     */
    fallback() external payable {}
}
