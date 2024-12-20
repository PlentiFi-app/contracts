// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

// A simple deterministic Contract Deployer created by PlentiFi
contract DeterministicContractDeployer {

    event ContractDeployerDeployed(address indexed contractAddress);
    event ContractDeployed(address indexed contractAddress);

    constructor() {
        emit ContractDeployerDeployed(address(this));
    }

    function deploy(bytes memory bytecode, bytes32 salt) public returns (address) {
        address addr;
        // Use assembly to call create2
        assembly {
            addr := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
            if iszero(extcodesize(addr)) {
                revert(0, 0)
            }
        }
        emit ContractDeployed(addr);
        return addr;
    }

    function computeAddress(bytes memory bytecode, bytes32 salt) public view returns (address) {
        bytes32 codeHash = keccak256(abi.encodePacked(bytecode));
        return address(uint160(uint256(keccak256(abi.encodePacked(
            bytes1(0xff),
            address(this),
            salt,
            codeHash
        )))));
    }

    fallback() external {
        revert("DeterministicContractDeployer: fallback");
    }

    receive() external payable {
        revert("DeterministicContractDeployer: receive");
    }
}
