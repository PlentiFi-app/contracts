/*
Deploy the FirstImplementation contract using create2
*/

import { keccak256, AbiCoder } from 'ethers';
import { ethers } from 'hardhat';
import 'dotenv/config'

async function main() {
  /* -------------CONSTRUCTOR ARGUMENTS----------------- */
  const owner = process.env.IMPLEMENTATION_MANAGER_OWNER_ADDRESS;
  if (!owner) throw new Error('IMPLEMENTATION_MANAGER_OWNER_ADDRESS not set in env');

  /* -------------SETUP DETERMINISTIC FACTORY----------------- */
  const deterministicFactoryAddress = process.env.DETERMINISTIC_FACTORY_ADDRESS;
  if (!deterministicFactoryAddress) throw new Error('DETERMINISTIC_FACTORY_ADDRESS not set in env');
  const deterministicFactoryAbi = require('../../../ScDeployer/out/ScDeployer.sol/DeterministicContractDeployer.json').abi;
  const deterministicFactory = await ethers.getContractAt(deterministicFactoryAbi, deterministicFactoryAddress);

  /* -------------SETUP FACTORY FOR DEPLOYMENT----------------- */
  const ImplementationManager = await ethers.getContractFactory('ImplementationManager'); // ImplementationManager
  // Encode constructor arguments
  const constructorArgs = (new AbiCoder).encode(['address'], [owner]);
  // Get the bytecode to deploy (including constructor arguments)
  const bytecode = `${ImplementationManager.bytecode}${constructorArgs.slice(2)}`; // Concatenate bytecode with encoded args
  const salt = keccak256(bytecode);


  /* -------------ENSURE ADDRESS IS THE EXPECTED ONE----------------- */
  // call computeAddress to ensure the address is the expected one
  const expectedAddress = process.env.EXPECTED_IMPLEMENTATION_MANAGER_ADDRESS;
  const preComputedAddress = await deterministicFactory.computeAddress(bytecode, salt);
  console.log('==expectedAddress=: ', expectedAddress, '\n==preComputedAddress=: ', preComputedAddress);
  if (!expectedAddress || expectedAddress !== preComputedAddress) {
    throw new Error('ImplementationManager computed address does not match expected address');
  }

  // Deploy the PlentiFiFactory contract using deterministicFactory.deploy(bytes memory bytecode, bytes32 salt)
  const tx = await deterministicFactory.deploy(bytecode, salt);
  const receipt = await tx.wait();

  // from the txHash, get the logs and extract the deployed address
  const logged_address = receipt.logs.map(log => deterministicFactory.interface.parseLog(log))[1].args[0];

  console.log('ImplementationManager deployed to:', logged_address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });