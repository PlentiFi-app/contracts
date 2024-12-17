// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title FirstImplementation
 * @notice Base implementation for ERC1967 proxies deployed by the factory
 * @dev This contract MUST never change and MUST have the same address on any EVM compatible chain
 * It serves as a minimal implementation that only handles upgrades
 * All proxies pointing to this contract MUST be upgraded to another implementation in the same transaction
 */
contract FirstImplementation is UUPSUpgradeable {
    error ZeroAddressImplementation();
    string public constant versionId = "FirstImplementation-v0.0.1";

    /**
     * @inheritdoc UUPSUpgradeable
     */
    function _authorizeUpgrade(
        address newImplementation /* pure */
    ) internal pure override {
        if (newImplementation == address(0)) revert ZeroAddressImplementation();
    }

    /**
     * @notice Do not all the contract to receive ETH
     */
    receive() external payable {
        revert("ETH not accepted");
    }
}
