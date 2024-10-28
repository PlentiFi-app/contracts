// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import {UUPSUpgradeable} from "openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title FirstImplementation
 * @notice Base implementation for ERC1967 proxies deployed by the factory
 * @dev This contract MUST never change and MUST have the same address on any EVM compatible chain
 * It serves as a minimal implementation that only handles upgrades
 */
contract FirstImplementation is UUPSUpgradeable {
    error ZeroAddressImplementation();
    error InitializeError();

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
     * @notice Upgrades the implementation and optionally executes a function
     * @dev This function is callable by the proxy owner
     * @param newImplementation Address of the new implementation
     * @param data The function call data to execute after upgrade
     * @param forceCall Force the call even if the contract doesn't exist
     */
    function upgradeToAndCall(
        address newImplementation,
        bytes memory data,
        bool forceCall
    ) external {
        if (newImplementation == address(0)) revert ZeroAddressImplementation();

        _upgradeToAndCall(newImplementation, data, forceCall);
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
