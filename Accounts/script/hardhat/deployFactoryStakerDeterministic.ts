/*
Deploy the FactoryStaker contract using create2
*/

import { keccak256, AbiCoder } from 'ethers';
import { ethers } from 'hardhat';
import 'dotenv/config'

async function main() {

  const deterministicFactoryAddress = process.env.DETERMINISTIC_FACTORY_ADDRESS;
  if (!deterministicFactoryAddress) throw new Error('DETERMINISTIC_FACTORY_ADDRESS not set in env');
  const deterministicFactoryAbi = require('../../../ScDeployer/out/ScDeployer.sol/DeterministicContractDeployer.json').abi;
  const deterministicFactory = await ethers.getContractAt(deterministicFactoryAbi, deterministicFactoryAddress);

  // deploy FactoryStaker
  const owner = process.env.FACTORY_STAKER_OWNER;
  if (!owner) throw new Error('FACTORY_STAKER_OWNER not set in env');
  const locked = false;
  const FactoryStaker = await ethers.getContractFactory('PlentifiFactoryStaker'); // FactoryStaker
  // Encode constructor arguments
  const constructorArgs = (new AbiCoder).encode(['address', 'bool'], [owner, locked]);
  // Get the bytecode to deploy (including constructor arguments)
  const bytecode = `${FactoryStaker.bytecode}${constructorArgs.slice(2)}`; // Concatenate bytecode with encoded args
  const salt = keccak256(bytecode);

  // call computeAddress to ensure the address is the expected one
  const expectedAddress = process.env.EXPECTED_PLENTIFI_FACTORY_STAKER_ADDRESS;
  const preComputedAddress = await deterministicFactory.computeAddress(bytecode, salt);
  console.log('==expectedAddress=: ', expectedAddress, '\n==preComputedAddress=: ', preComputedAddress);
  if (!expectedAddress || expectedAddress !== preComputedAddress) {
    throw new Error('Computed address does not match expected address');
  }
  // check if the contract is already deployed at this address
  const code = await ethers.provider.getCode(expectedAddress);
  if (code !== '0x') {
    console.log('FactoryStaker already deployed at:', expectedAddress);
    return;
  }

  // Deploy the PlentiFiFactoryStaker contract using deterministicFactory.deploy(bytes memory bytecode, bytes32 salt)
  const tx = await deterministicFactory.deploy(bytecode, salt);
  const receipt = await tx.wait();

  // from the txHash, get the logs and extract the deployed address
  const logs = receipt.logs.map(log => deterministicFactory.interface.parseLog(log))[1].args[0];

  console.log('PlentiFiFactoryStaker deployed to:', logs);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });