// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {FirstImplementation} from "../deployers/FirstImplementation.sol";
import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";
import {ImplementationManager} from "../deployers/ImplementationManager.sol";
import {ProxyUpgrader} from "../deployers/ProxyUpgrader.sol";

abstract contract PlentiFiFactory {
    FirstImplementation public immutable firstImplementation;
    ImplementationManager public immutable implementationManager;
    // the custom identifier for special purpose factories
    bytes32 public immutable ID;

    error DeploymentFailed();
    error ZeroAddress();

    event AccountDeployed(address indexed account, bytes32 salt);

    constructor(address implementationManager_, bytes32 id_) {
        if (implementationManager_ == address(0)) revert ZeroAddress();

        firstImplementation = new FirstImplementation();
        implementationManager = ImplementationManager(implementationManager_);
        ID = id_;
    }

    /**
     * @notice Creates a new account with specified initialization data
     * @param initData Initialization data for the account
     * @param salt Unique salt for address generation
     * @return address The address of the deployed account
     *
     * @dev The deployed account address only depends on the salt and the factory address
     */
    function _createAccount(
        bytes calldata initData,
        bytes32 salt
    ) internal returns (address) {
        try
            new ERC1967Proxy{salt: salt, value: msg.value}(
                address(firstImplementation),
                ""
            )
        returns (ERC1967Proxy proxy) {
            address newImplementation = implementationManager.implementation();
            address proxyAddress = address(proxy);

            // upgrade to the last available implementation and initialize
            ProxyUpgrader(implementationManager.proxyUpgrader()).upgrade(
                proxyAddress,
                newImplementation,
                initData
            );

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
    function getAddress(bytes32 salt) public view returns (address) {
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
     * it returns the contract address (because of the ethers' built-in function)
     * so we need to wrap the function to get the address
     */
    function getAddressWrapper(bytes32 salt) external view returns (address) {
        return getAddress(salt);
    }
}