// SPDX-License-Identifier: MIT

pragma solidity ^0.8.21;

import {IFirstImplementation} from "./interfaces/IFirstImplementation.sol";

/**
 * @title ProxyUpgrader
 * @notice Contract responsible for upgrading proxy implementations and initializing them
 * @dev This contract handles the upgrade process for upgradeable proxies following the ERC1967 standard
 */
contract ProxyUpgrader {
    string public constant versionId = "Plentifi-ProxyUpgrader-v0.0.1";

    error UpgradeFailed();
    error ZeroAddress();

    /**
     * @notice Upgrades a proxy to a new implementation and initializes it
     * @param proxy Address of the proxy to upgrade
     * @param newImplementation Address of the new implementation
     * @param initData Initialization data to be called on the proxy after upgrade
     */
    function upgrade(
        address proxy,
        address newImplementation,
        bytes calldata initData
    ) public {
        if (proxy == address(0) || newImplementation == address(0)) {
            revert ZeroAddress();
        }

        try
            IFirstImplementation(proxy).upgradeToAndCall(
                newImplementation,
                initData
            )
        {
            // event Upgraded is already emitted by the proxy itself
        } catch {
            revert UpgradeFailed();
        }
    }
}
