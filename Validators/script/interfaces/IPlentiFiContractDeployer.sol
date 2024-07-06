// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

interface IPlentiFiContractDeployer {
    function addDeployer(address deployer) external;

    function removeDeployer(address deployer) external;

    function deploy(
        bytes memory bytecode,
        bytes32 salt
    ) external returns (address);

    function computeAddress(
        bytes memory bytecode,
        bytes32 salt
    ) external view returns (address);
}
