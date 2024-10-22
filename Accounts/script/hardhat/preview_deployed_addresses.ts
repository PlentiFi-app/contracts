/*
Precompute the addresses of:
- Canonical FactoryStaker
- ImplementationManager
- Canonical Account Factory
*/

import { keccak256, AbiCoder } from 'ethers';
import { ethers } from 'hardhat';
import 'dotenv/config'

async function main() {
  /* -------------SETUP DETERMINISTIC FACTORY----------------- */
  const deterministicFactoryAddress = process.env.DETERMINISTIC_FACTORY_ADDRESS;
  if (!deterministicFactoryAddress) throw new Error('DETERMINISTIC_FACTORY_ADDRESS not set in env');
  const deterministicFactoryAbi = require('../../../ScDeployer/out/ScDeployer.sol/DeterministicContractDeployer.json').abi;
  const deterministicFactory = await ethers.getContractAt(deterministicFactoryAbi, deterministicFactoryAddress);

  /* -------------GET THE EXPECTED ADDRESSES----------------- */

  // Canonical FactoryStaker
  const factoryStakerOwner = process.env.FACTORY_STAKER_OWNER;
  if (!factoryStakerOwner) throw new Error('FACTORY_STAKER_OWNER not set in env');
  const locked = false;
  const factoryStakerConstructorArgs = (new AbiCoder).encode(['address', 'bool'], [factoryStakerOwner, locked]);
  const FactoryStaker = await ethers.getContractFactory('PlentifiFactoryStaker'); // FactoryStaker
  const factoryStakerBytecode = `${FactoryStaker.bytecode}${factoryStakerConstructorArgs.slice(2)}`; // Concatenate bytecode with encoded args
  const factoryStakerSalt = keccak256(factoryStakerBytecode);
  const preComputedFactoryStaker = await deterministicFactory.computeAddress(factoryStakerBytecode, factoryStakerSalt);

  // ImplementationManager
  const ImplementationManager = await ethers.getContractFactory('ImplementationManager'); // ImplementationManager
  const implManagerConstructorArgs = (new AbiCoder).encode(['address'], [factoryStakerOwner]);
  const implManagerBytecode = `${ImplementationManager.bytecode}${implManagerConstructorArgs.slice(2)}`; // Concatenate bytecode with encoded args
  const implManagerSalt = keccak256(implManagerBytecode);
  const implManagerPreComputedAddress = await deterministicFactory.computeAddress(implManagerBytecode, implManagerSalt);

  // Canonical Account Factory
  const factory_id = process.env.FACTORY_ID;
  if (!factory_id) throw new Error('FACTORY_ID not set in env');
  const Factory = await ethers.getContractFactory('PlentiFiAccountFactory'); // PlentiFiAccountFactory
  const accountFactoryConstructorArgs = (new AbiCoder).encode(['address', 'bytes32'], [implManagerPreComputedAddress, factory_id]);
  const accountFactoryBytecode = `${Factory.bytecode}${accountFactoryConstructorArgs.slice(2)}`; // Concatenate bytecode with encoded args
  const accountFactorySalt = keccak256(accountFactoryBytecode);
  const accountFactoryPreComputedAddress = await deterministicFactory.computeAddress(accountFactoryBytecode, accountFactorySalt);

  console.log('FactoryStaker precomputed address:', preComputedFactoryStaker);
  console.log('ImplementationManager precomputed address:', implManagerPreComputedAddress);
  console.log('Canonical PlentiFi Canonical Factory precomputed address:', accountFactoryPreComputedAddress);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });