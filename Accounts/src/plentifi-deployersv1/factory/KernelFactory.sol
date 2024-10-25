// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ERC1967Proxy} from "openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IImplementationManager} from "../interfaces/IImplementationManager.sol";
import {FirstImplementation} from "../FirstImplementation.sol";
import {Create2} from "openzeppelin/contracts/utils/Create2.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {ProxyUpgrader} from "../ProxyUpgrader.sol";

contract PlentiFiAccountFactory {
    error InitializeError();
    error DeploymentFailed();

    string public constant versionId = "PlentiFi-AccountFactory-v0.0.2";
    FirstImplementation public immutable firstImplementation;
    IImplementationManager public immutable implementationManager;

    // the custom identifier for special purpose factories
    bytes32 public immutable ID;

    event AccountCreated(address indexed account, bytes32 salt);
    event DeploymentAttempt(address computedAddress, bytes32 saltHash, bytes32 bytecodeHash);

    constructor(address implementationManager_, bytes32 id_) {
        implementationManager = IImplementationManager(implementationManager_);
        firstImplementation = new FirstImplementation();
        ID = id_;
    }

    function createAccount(
        bytes calldata data,
        bytes32 salt
    ) public payable returns (address) {
        address addr = getAddress(data, salt);
        bytes32 saltHash = _getSalt(data, salt);
        
        uint32 size;
        assembly {
            size := extcodesize(addr)
        }

        // If there's already a contract, return its address
        if (size > 0) {
            return addr;
        }

        // For debugging: emit computed values
        bytes memory bytecode = abi.encodePacked(
            type(ERC1967Proxy).creationCode,
            abi.encode(address(firstImplementation), "")
        );
        emit DeploymentAttempt(addr, saltHash, keccak256(bytecode));

        try new ERC1967Proxy{salt: saltHash}(
            address(firstImplementation),
            ""
        ) returns (ERC1967Proxy proxy) {
            address newImplementation = implementationManager.implementation();

            // upgrade to the last available implementation and initialize the proxy
            ProxyUpgrader(address(implementationManager.proxyUpgrader())).upgrade(
                address(proxy),
                newImplementation,
                data
            );

            emit AccountCreated(address(proxy), salt);
            return address(proxy);
        } catch {
            revert DeploymentFailed();
        }
    }

    function getAddress(
        bytes calldata login,
        bytes32 salt
    ) public view returns (address) {
        bytes32 saltHash = _getSalt(login, salt);
        bytes memory bytecode = abi.encodePacked(
            type(ERC1967Proxy).creationCode,
            abi.encode(address(firstImplementation), "")
        );

        return Create2.computeAddress(saltHash, keccak256(bytecode), address(this));
    }

    // when trying to call getAddress using ethers, 
    // it returns the contract addres (because of the ethers' built-in function)
    // so we need to wrap the function to get the address
    function getAddressWrapper(
        bytes calldata login,
        bytes32 salt
    ) public view returns (address) {
        return getAddress(login, salt);
    }

    function _getSalt(
        bytes calldata login,
        bytes32 _salt
    ) public pure returns (bytes32 salt) {
        salt = keccak256(abi.encodePacked(login, _salt));
    }
}