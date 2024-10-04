// SPDX-License-Identifier: MIT

pragma solidity ^0.8.21;

// import {LibClone} from "solady/utils/LibClone.sol";
import {IImplementationManager} from "./interfaces/IImplementationManager.sol";
import {Create2} from "openzeppelin/contracts/utils/Create2.sol";
import {IFirstImplementation} from "./interfaces/IFirstImplementation.sol";
import {Kernel} from "../kernel/Kernel.sol";
import {ERC1967Proxy} from "openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Initializable} from "openzeppelin/contracts/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import {ProxyUpgrader} from "./ProxyUpgrader.sol";

import {IHook} from "../kernel/interfaces/IERC7579Modules.sol";
import {ValidationId} from "../kernel/core/ValidationManager.sol";

contract ProxyFactory {
    string public constant versionId = "ProxyFactory-v0.0.1";
    IFirstImplementation public immutable firstImplementation;
    IImplementationManager public immutable implementationManager;

    event test(string message, address addr);

    constructor(address implementationManager_, address firstImplementation_) {
        implementationManager = IImplementationManager(implementationManager_);
        firstImplementation = IFirstImplementation(firstImplementation_);
    }

    function createAccount(
        string calldata login,
        bytes32 salt,
        bytes calldata initData
    ) public payable virtual returns (address) {
        address addr = getAddress(login, salt);
        uint256 codeSize = addr.code.length;

        if (codeSize > 0) {
            return address(payable(addr));
        }

        IFirstImplementation proxy = IFirstImplementation(
            address(new ERC1967Proxy{salt : _getSalt(login, salt)}(address(firstImplementation), ""))
        );

        address newImplementation = implementationManager.implementation();

        // upgrade to the last available implementation and initialize the proxy
        ProxyUpgrader(address(implementationManager.proxyUpgrader())).upgrade(
            address(proxy),
            newImplementation,
            initData
        );

        return address(proxy);
    }

    /**
     * calculate the counterfactual address of this account as it would be returned by createAccount()
     */
    function getAddress(string calldata login, bytes32 salt) public view returns (address) {
        bytes32 saltHash = _getSalt(login, salt);
        bytes memory bytecode = abi.encodePacked(
            type(ERC1967Proxy).creationCode,
            abi.encode(address(firstImplementation), "")
        );

        return Create2.computeAddress(saltHash, keccak256(bytecode), address(this));
    }

    // wrapper for getAddress() since with ethers 6, proxyFactoryContract.getAddress(login, salt); returns the factory address
    function getAddressWrapper(string calldata login, bytes32 salt) public view returns (address) {
        return getAddress(login, salt);
    }

    function _getSalt(
        string calldata login,
        bytes32 _salt
    ) public pure returns (bytes32 salt) {
        salt = keccak256(abi.encodePacked(login, _salt));
    }
}
