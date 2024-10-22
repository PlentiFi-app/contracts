/*
Deploy the PlentiFiAccountFactory contract using create2
*/

import { keccak256, AbiCoder } from 'ethers';
import { ethers } from 'hardhat';
import 'dotenv/config'

async function main() {
  /* -------------CONSTRUCTOR ARGUMENTS----------------- */
  const implementationManager = process.env.IMPLEMENTATION_MANAGER_ADDRESS;
  if (!implementationManager) throw new Error('IMPLEMENTATION_ADDRESS not set in env');
  const firstImplementation_ = process.env.FIRST_IMPLEMENTATION_ADDRESS;
  if (!firstImplementation_) throw new Error('FIRST_IMPLEMENTATION_ADDRESS not set in env');
  const factory_id = process.env.FACTORY_ID;
  if (!factory_id) throw new Error('FACTORY_ID not set in env');

  /* -------------SETUP DETERMINISTIC FACTORY----------------- */
  const deterministicFactoryAddress = process.env.DETERMINISTIC_FACTORY_ADDRESS;
  if (!deterministicFactoryAddress) throw new Error('DETERMINISTIC_FACTORY_ADDRESS not set in env');
  const deterministicFactoryAbi = require('../../../ScDeployer/out/ScDeployer.sol/DeterministicContractDeployer.json').abi;
  const deterministicFactory = await ethers.getContractAt(deterministicFactoryAbi, deterministicFactoryAddress);

  /* -------------SETUP FACTORY FOR DEPLOYMENT----------------- */
  const Factory = await ethers.getContractFactory('PlentiFiAccountFactory'); // PlentiFiAccountFactory
  // Encode constructor arguments
  const constructorArgs = (new AbiCoder).encode(['address', 'address', 'bytes32'], [implementationManager, firstImplementation_, factory_id]);
  // Get the bytecode to deploy (including constructor arguments)
  const bytecode = `${Factory.bytecode}${constructorArgs.slice(2)}`; // Concatenate bytecode with encoded args
  const salt = keccak256(bytecode);


  /* -------------ENSURE CANONICAL ADDRESS IS THE EXPECTED ONE----------------- */
  // if id == bytes32(1), then the factory is the canonical factory
  // call computeAddress to ensure the address is the expected one
  if (factory_id === '0x0000000000000000000000000000000000000000000000000000000000000001') {
    const expectedAddress = process.env.EXPECTED_PLENTIFI_CANONICAL_FACTORY_ADDRESS;
    const preComputedAddress = await deterministicFactory.computeAddress(bytecode, salt);
    console.log('==expectedAddress=: ', expectedAddress, '\n==preComputedAddress=: ', preComputedAddress);
    if (!expectedAddress || expectedAddress !== preComputedAddress) {
      throw new Error('Canonical Factory computed address does not match expected address');
    }
  } else {
    console.log('factory_id != bytes32(1), Canonical Factory address check skipped, stop now if this is not expected');
    await new Promise(resolve => setTimeout(resolve, 10000));
  }

  // Deploy the PlentiFiFactory contract using deterministicFactory.deploy(bytes memory bytecode, bytes32 salt)
  const tx = await deterministicFactory.deploy(bytecode, salt);
  const receipt = await tx.wait();

  // from the txHash, get the logs and extract the deployed address
  const logged_address = receipt.logs.map(log => deterministicFactory.interface.parseLog(log))[1].args[0];

  console.log('PlentiFiAccountFactory deployed to:', logged_address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });