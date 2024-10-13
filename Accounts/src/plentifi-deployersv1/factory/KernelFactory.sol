// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ERC1967Proxy} from "openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IImplementationManager} from "../interfaces/IImplementationManager.sol";
import {IFirstImplementation} from "../interfaces/IFirstImplementation.sol";
import {Create2} from "openzeppelin/contracts/utils/Create2.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {ProxyUpgrader} from "../ProxyUpgrader.sol";

contract PlentiFiAccountFactory {
    error InitializeError();

    string public constant versionId = "PlentiFi-AccountFactory-v0.0.2";
    IFirstImplementation public immutable firstImplementation;
    IImplementationManager public immutable implementationManager;

    string public constant id;

    event AccountCreated(address indexed account, bytes32 salt);

    constructor(address implementationManager_, address firstImplementation_, string memory id_) {
        implementationManager = IImplementationManager(implementationManager_);
        firstImplementation = IFirstImplementation(firstImplementation_);
        assign id (custom identifier for special purpose factories)
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

        IFirstImplementation proxy = IFirstImplementation(
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
        bytes calldata /* data */, // not removed from the kernel factory so the function signature is the same as the one called by the permissionless sdk
        bytes32 salt
    ) public view virtual returns (address) {
        bytes memory bytecode = abi.encodePacked(
            type(ERC1967Proxy).creationCode,
            abi.encode(address(firstImplementation), "")
        );

        return Create2.computeAddress(salt, keccak256(bytecode), address(this));
    }
}
