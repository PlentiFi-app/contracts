// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ERC1967Proxy} from "openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IImplementationManager} from "../interfaces/IImplementationManager.sol";
import {Create2} from "openzeppelin/contracts/utils/Create2.sol";
import {FirstImplementation} from "../FirstImplementation.sol";
import {ProxyUpgrader} from "../ProxyUpgrader.sol";
import {LibClone} from "solady/utils/LibClone.sol";

/**
 * @title PlentiFiAccountFactory
 * @notice Factory contract for creating and managing PlentiFi accounts using proxy pattern
 * @dev Uses CREATE2 for deterministic address generation and ERC1967 proxy pattern. Then update their implementation
 * using the ImplementationManager contract.
 */
contract PlentiFiAccountFactory {
    error InvalidImplementationManager();
    error DeploymentFailed();
    error InitializeError();
    error ZeroAddress();

    string public constant versionId = "PlentiFi-AccountFactory-v0.0.1";
    FirstImplementation public immutable firstImplementation;
    IImplementationManager public immutable implementationManager;

    // the custom identifier for special purpose factories
    bytes32 public immutable ID;

    event AccountDeployed(address indexed account, bytes32 salt);

    /**
     * @notice Constructor to initialize the factory
     * @param implementationManager_ Address of the implementation manager
     * @param id_ Identifier for special purpose factories. Canonical factory id is bytes32(1)
     */
    constructor(address implementationManager_, bytes32 id_) {
        if (implementationManager_ == address(0)) revert ZeroAddress();

        implementationManager = IImplementationManager(implementationManager_);
        firstImplementation = new FirstImplementation();
        ID = id_;
    }

    /**
     * @notice Creates a new account with specified initialization data
     * @param data Initialization data for the account
     * @param salt Unique salt for address generation
     * @return address The address of the deployed or existing account
     *
     * @dev The deployed account address only depends on the salt and the factory address
     */
    function createAccount(
        bytes calldata data,
        bytes32 salt
    ) public payable returns (address) {
        address addr = getAddress(data, salt);

        uint32 size;
        assembly {
            size := extcodesize(addr)
        }

        // If there's already a contract, return its address
        if (size > 0) {
            return addr;
        }

        try
            new ERC1967Proxy{salt: salt, value: msg.value}(address(firstImplementation), "")
        returns (ERC1967Proxy proxy) {
            address newImplementation = implementationManager.implementation();
            address proxyAddress = address(proxy);

            // upgrade to the last available implementation and initialize
            ProxyUpgrader(address(implementationManager.proxyUpgrader()))
                .upgrade(proxyAddress, newImplementation, data);

            emit AccountDeployed(proxyAddress, salt);

            return proxyAddress;
        } catch {
            revert DeploymentFailed();
        }
    }

    /**
     * @notice Computes the counterfactual address for an account
     * @param salt Salt for address generation
     * @return The computed address
     */
    function getAddress(
        // kept to match the usual kernel factory interface and avoid issues with its sdk
        bytes memory,
        bytes32 salt
    ) public view returns (address) {
        bytes memory bytecode = abi.encodePacked(
            type(ERC1967Proxy).creationCode,
            abi.encode(address(firstImplementation), "")
        );

        return Create2.computeAddress(salt, keccak256(bytecode), address(this));
    }

    /**
     * @notice Wrapper function for ethers compatibility
     * @param salt Salt for address generation
     * @return The computed address
     *
     * when trying to call getAddress using ethers,
     * it returns the contract addres (because of the ethers' built-in function)
     * so we need to wrap the function to get the address
     */
    function getAddressWrapper(bytes32 salt) external view returns (address) {
        return getAddress("", salt);
    }
}
