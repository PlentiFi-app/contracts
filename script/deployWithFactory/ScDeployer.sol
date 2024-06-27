// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

// PlentiFi Contract Deployer

import "openzeppelin/contracts/access/Ownable.sol";

contract PlentiFiContractDeployer is Ownable {

    // addresses allowed to deploy through this contract
    mapping (address => bool) public deployers;

    event PlentiFiContractDeployed(address indexed contractAddress);
    event ContractDeployed(address indexed contractAddress);
    event DeployerAdded(address indexed deployer);
    event DeployerRemoved(address indexed deployer);

    constructor() Ownable() {
        emit PlentiFiContractDeployed(address(this));
    }

    modifier onlyDeployer() {
        require(deployers[msg.sender] || owner() == msg.sender, "Not allowed to deploy");
        _;
    }

    function addDeployer(address deployer) external onlyOwner {
        deployers[deployer] = true;
        emit DeployerAdded(deployer);
    }

    function removeDeployer(address deployer) external onlyOwner {
        deployers[deployer] = false;
        emit DeployerRemoved(deployer);
    }

    function deploy(bytes memory bytecode, bytes32 salt) public onlyDeployer returns (address) {
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
        revert("PlentiFiContractDeployer: fallback");
    }

    receive() external payable {
        revert("PlentiFiContractDeployer: receive");
    }
}
