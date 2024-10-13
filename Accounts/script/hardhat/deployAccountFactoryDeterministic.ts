/*
Deploy the KernelFactory and FactoryStaker contracts using create2
*/

import { keccak256, AbiCoder } from 'ethers';
import { ethers } from 'hardhat';
import 'dotenv/config'

async function main() {
  const provider = ethers.provider;
  const [signer] = await ethers.getSigners();
  const from = await signer.getAddress();

  const deterministicFactoryAddress = process.env.DETERMINISTIC_FACTORY_ADDRESS;
  if (!deterministicFactoryAddress) throw new Error('DETERMINISTIC_FACTORY_ADDRESS not set in env');
  const deterministicFactoryAbi = require('../../../ScDeployer/out/ScDeployer.sol/DeterministicContractDeployer.json').abi;
  const deterministicFactory = await ethers.getContractAt(deterministicFactoryAbi, deterministicFactoryAddress);

  // deploy FactoryStaker
  const owner = process.env.FACTORY_STAKER_OWNER;
  if (!owner) throw new Error('FACTORY_STAKER_OWNER not set in env');
  const FactoryStaker = await ethers.getContractFactory('PlentifiFactoryStaker'); // FactoryStaker
  const locked = true;
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