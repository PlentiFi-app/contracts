// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import {UUPSUpgradeable} from "openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

// This contract is the base implementation for all the erc1967 proxies deployed by the factory
// It MUST never change
// it MUST always have the same address on any evm compatible chain
contract FirstImplementation is UUPSUpgradeable {
    error InitializeError();

    string public constant versionId = "FirstImplementation-v0.0.1";

    function _authorizeUpgrade(
        address newImplementation
    ) internal pure override {
        require(newImplementation != address(0), "Unauthorized");
    }

    // function upgradeToAndCall(address newImplementation, bytes memory data, bool forceCall) external {
    //     _upgradeToAndCall(newImplementation, data, forceCall);
    // }

    function upgradeToAndCall(
        address newImplementation,
        bytes memory data,
        bool forceCall
    ) external {
        _upgradeToAndCall(newImplementation, data, forceCall);

        // (bool success, ) = newImplementation.call(data);
        // if (!success) {
        //     revert InitializeError();
        // }


    }
}
