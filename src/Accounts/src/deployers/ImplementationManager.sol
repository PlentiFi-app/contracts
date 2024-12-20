// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {FirstImplementation} from "./FirstImplementation.sol";

/**
 * @title ImplementationManager
 * @notice This contract manages implementations for ERC1967 proxies deployed by the factory
 * @dev This contract is designed to be immutable and maintain the same address across all EVM-compatible chains
 * It MUST never change
 * It MUST always have the same address on any evm compatible chain
 */
contract ImplementationManager is Ownable {
    string public constant versionId = "ImplementationManager-v0.0.1";

    uint256 constant MODULE_TYPE_VALIDATOR = 1;

    bool public isInitialized;
    bool public locked;

    address public proxyUpgrader;
    address public implementation;

    event ImplementationUpdated(address indexed implementation);
    event ProxyUpgraderUpdated(address indexed proxyUpgrader);

    error AlreadyInitialized();
    error NotInitialized();
    error Unauthorized();
    error ZeroAddress();

    /// @notice Allowed addresses to update the implementation and proxy upgrader
    mapping(address => bool) public isService;

    /**
     * @notice Ensures caller is either a service or the owner
     */
    modifier onlyServiceOrOwner() {
        if (!isService[msg.sender] && msg.sender != owner()) {
            revert Unauthorized();
        }
        _;
    }

    /**
     * @notice Ensures contract is either unlocked or caller is owner
     */
    modifier lockedOrOwner() {
        if (locked && msg.sender != owner()) {
            revert Unauthorized();
        }
        _;
    }

    /**
     * @notice Ensures contract is initialized
     */
    modifier initializedOnly() {
        if (!isInitialized) {
            revert NotInitialized();
        }
        _;
    }

    /**
     * @notice Contract constructor
     * @param owner_ Initial owner address of the contract
     */
    constructor(address owner_) Ownable(owner_) {}

    /**
     * @notice Sets the implementation address
     * @param _implementation New implementation address
     */
    function setImplementation(
        address _implementation
    ) external onlyServiceOrOwner lockedOrOwner {
        if (_implementation == address(0)) revert ZeroAddress();
        implementation = _implementation;
        emit ImplementationUpdated(_implementation);
    }

    /**
     * @notice Sets the proxy upgrader address
     * @param _proxyUpgrader New proxy upgrader address
     */
    function setProxyUpgrader(
        address _proxyUpgrader
    ) external onlyServiceOrOwner lockedOrOwner {
        if (_proxyUpgrader == address(0)) revert ZeroAddress();
        proxyUpgrader = _proxyUpgrader;
        emit ProxyUpgraderUpdated(_proxyUpgrader);
    }

    /**
     * @notice Unlocks the contract
     */
    function unlock() external onlyServiceOrOwner {
        locked = false;
    }

    /**
     * @notice Locks the contract
     */
    function lock() external onlyServiceOrOwner {
        locked = true;
    }

    /**
     * @notice Adds a service address
     * @param _service Address to be added as a service
     */
    function addService(
        address _service
    ) external onlyServiceOrOwner lockedOrOwner initializedOnly {
        if (_service == address(0)) revert ZeroAddress();
        isService[_service] = true;
    }

    /**
     * @notice Removes a service address
     * @param _service Address to be removed from services
     */
    function removeService(
        address _service
    ) external onlyServiceOrOwner lockedOrOwner initializedOnly {
        if (_service == address(0)) revert ZeroAddress();
        isService[_service] = false;
    }

    /**
     * @notice Initializes the contract with implementation and proxy upgrader addresses
     * @dev Should be called immediately after deployment and before registering factories
     * @param _implementation Initial implementation address
     * @param _proxyUpgrader Initial proxy upgrader address
     */
    function initialize(
        address _implementation,
        address _proxyUpgrader
    ) external onlyServiceOrOwner lockedOrOwner {
        if (isInitialized) revert AlreadyInitialized();
        if (_implementation == address(0) || _proxyUpgrader == address(0)) {
            revert ZeroAddress();
        }

        implementation = _implementation;
        proxyUpgrader = _proxyUpgrader;
        isInitialized = true;

        emit ImplementationUpdated(_implementation);
        emit ProxyUpgraderUpdated(_proxyUpgrader);
    }
}
