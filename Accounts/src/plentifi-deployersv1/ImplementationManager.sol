// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import {Ownable} from "openzeppelin/contracts/access/Ownable.sol";
import {FirstImplementation} from "./FirstImplementation.sol";
import {IImplementationManager} from "./interfaces/IImplementationManager.sol";

// This contract is the implementation manager for all the erc1967 proxies deployed by the factory
// It MUST never change
// it MUST always have the same address on any evm compatible chain
contract ImplementationManager is Ownable, IImplementationManager {
    string public constant versionId = "ImplementationManager-v0.0.1";

    uint256 constant MODULE_TYPE_VALIDATOR = 1;

    bool public isInitialized;
    bool public locked;

    address public entryPoint;
    address public proxyUpgrader;
    address public implementation;

    event ImplementationUpdated(address indexed implementation);
    event EntryPointUpdated(address indexed entryPoint);
    event ProxyUpgraderUpdated(address indexed proxyUpgrader);

    mapping(address => bool) public isService; // allowed to update the implementation and entryPoint

    modifier onlyServiceOrOwner() {
        require(isService[msg.sender] || msg.sender == owner(), "Not allowed");
        _;
    }

    // revert if locked and not the owner
    modifier lockedOrOwner() {
        require(!locked || msg.sender == owner(), "Not allowed");
        _;
    }

    modifier initialized() {
        require(isInitialized, "Not initialized");
        _;
    }

    constructor(address owner) {
        transferOwnership(owner);
    }

    function setEntryPoint(
        address _entryPoint
    ) external onlyServiceOrOwner lockedOrOwner {
        if (_entryPoint == address(0)) {
            revert("Cannot set implementation to address(0)");
        }
        entryPoint = _entryPoint;

        emit EntryPointUpdated(_entryPoint);
    }

    function setImplementation(
        address _implementation
    ) external onlyServiceOrOwner lockedOrOwner {
        if (_implementation == address(0)) {
            revert("Cannot set implementation to address(0)");
        }
        implementation = _implementation;

        emit ImplementationUpdated(_implementation);
    }

    function setProxyUpgrader(
        address _proxyUpgrader
    ) external onlyServiceOrOwner lockedOrOwner {
        if (_proxyUpgrader == address(0)) {
            revert("Cannot set implementation to address(0)");
        }
        proxyUpgrader = _proxyUpgrader;

        emit ProxyUpgraderUpdated(_proxyUpgrader);
    }

    function unlock() external onlyServiceOrOwner {
        locked = false;
    }

    function lock() external onlyServiceOrOwner {
        locked = true;
    }

    function addService(
        address _service
    ) external onlyServiceOrOwner lockedOrOwner initialized {
        isService[_service] = true;
    }

    function removeService(
        address _service
    ) external onlyServiceOrOwner lockedOrOwner initialized {
        isService[_service] = false;
    }

    // initialize the contract. Should be called right after deployment,
    // before registering the factories in the staker factory
    function initialize(
        address _implementation,
        address _proxyUpgrader,
        address _entrypoint
    ) external onlyServiceOrOwner lockedOrOwner {
        require(!isInitialized, "Already initialized");

        implementation = _implementation;
        proxyUpgrader = _proxyUpgrader;
        entryPoint = _entrypoint;

        isInitialized = true;

        emit ImplementationUpdated(_implementation);
        emit EntryPointUpdated(_entrypoint);
        emit ProxyUpgraderUpdated(_proxyUpgrader);
    }
}
