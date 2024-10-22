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

    string public constant versionId = "PlentiFi-AccountFactory-v0.0.2";
    FirstImplementation public immutable firstImplementation;
    IImplementationManager public immutable implementationManager;

    // the custom identifier for special purpose factories
    bytes32 public immutable ID;

    event AccountCreated(address indexed account, bytes32 salt);

    /**
     * @param implementationManager_ the implementation manager contract
     * @param id_ the custom identifier for special purpose factories
     */
    constructor(
        address implementationManager_,
        bytes32 id_
    ) {
        implementationManager = IImplementationManager(implementationManager_);
        firstImplementation = new FirstImplementation();

        ID = id_;
    }

    function createAccount(
        bytes calldata data,
        bytes32 salt
    ) public payable returns (address) {
        address addr = getAddress(data, salt);
        uint256 codeSize = addr.code.length;

        if (codeSize > 0) {
            return address(payable(addr));
        }

        FirstImplementation proxy = FirstImplementation(
            address(
                new ERC1967Proxy{salt: salt}(address(firstImplementation), "")
            )
        );

        address newImplementation = implementationManager.implementation();

        // upgrade to the last available implementation and initialize the proxy
        ProxyUpgrader(address(implementationManager.proxyUpgrader())).upgrade(
            address(proxy),
            newImplementation,
            data
        );

        emit AccountCreated(address(proxy), salt);

        return address(proxy);
    }

    /**
     * calculate the counterfactual address of this account as it would be returned by createAccount()
     */
    function getAddress(
        bytes calldata login,
        bytes32 salt
    ) public view returns (address) {
        bytes32 saltHash = _getSalt(login, salt);
        bytes memory bytecode = abi.encodePacked(
            type(ERC1967Proxy).creationCode,
            abi.encode(address(firstImplementation), "")
        );

        return
            Create2.computeAddress(
                saltHash,
                keccak256(bytecode),
                address(this)
            );
    }

    // wrapper for getAddress() since with ethers 6, proxyFactoryContract.getAddress(login, salt); returns the factory address
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
