// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

// A simple deterministic Contract Deployer created by PlentiFi
interface IDeterministicContractDeployer {
    function deploy(
        bytes memory bytecode,
        bytes32 salt
    ) external returns (address);

    function computeAddress(
        bytes memory bytecode,
        bytes32 salt
    ) external view returns (address);
}
