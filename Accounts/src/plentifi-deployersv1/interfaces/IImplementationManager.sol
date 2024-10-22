// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

interface IImplementationManager {

    function implementation() external view returns (address);

    function proxyUpgrader() external view returns (address);

    function entryPoint() external view returns (address);
}
