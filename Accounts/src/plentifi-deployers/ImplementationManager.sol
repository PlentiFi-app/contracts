// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import {Ownable} from "../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
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
    address public firstImplementation;

    mapping(address => bool) public isService; // allowed to update the implementation and entryPoint

    event FirstImplementationDeployed(address indexed firstImplementation, address indexed owner);

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
        // deploy the first implementation
        firstImplementation = address(new FirstImplementation());
        transferOwnership(owner);
        emit FirstImplementationDeployed(firstImplementation, owner);
    }

    function setEntryPoint(
        address _entryPoint
    ) external onlyServiceOrOwner lockedOrOwner {
        if (_entryPoint == address(0)) {
            revert("Cannot set implementation to address(0)");
        }
        entryPoint = _entryPoint;
    }

    function setImplementation(
        address _implementation
    ) external onlyServiceOrOwner lockedOrOwner {
        if (_implementation == address(0)) {
            revert("Cannot set implementation to address(0)");
        }
        implementation = _implementation;
    }

    function setProxyUpgrader(
        address _proxyUpgrader
    ) external onlyServiceOrOwner lockedOrOwner {
        if (_proxyUpgrader == address(0)) {
            revert("Cannot set implementation to address(0)");
        }
        proxyUpgrader = _proxyUpgrader;
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
    }
}
