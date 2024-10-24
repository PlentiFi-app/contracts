/*
This script update the kernel implementation in the ImplementationManager 
*/

import { keccak256, AbiCoder } from 'ethers';
import { ethers } from 'hardhat';
import 'dotenv/config'

async function main() {
  const implementationManagerAddress = process.env.EXPECTED_IMPLEMENTATION_MANAGER_ADDRESS;
  if (!implementationManagerAddress) throw new Error('EXPECTED_IMPLEMENTATION_MANAGER_ADDRESS not set in env');
  const kernel = process.env.KERNEL_IMPLEMENTATION_ADDRESS;
  if (!kernel) throw new Error('EXPECTED_IMPLEMENTATION_MANAGER_ADDRESS not set in env');


  /* -------------ENSURE CONTRACTS ARE DEPLOYED----------------- */
  if (await ethers.provider.getCode(implementationManagerAddress) === '0x') throw new Error('ImplementationManager not deployed');
  if (await ethers.provider.getCode(kernel) === '0x') throw new Error('Kernel not deployed');

  /* -------------INITIALIZE ImplementationManager----------------- */
  const implementationManagerAbi = require('../../artifacts/src/plentifi-deployersv1/ImplementationManager.sol/ImplementationManager.json').abi;
  const ImplementationManager = await ethers.getContractAt(implementationManagerAbi, implementationManagerAddress);

  // check if the implementationManager is already initialized
  const isInitialized = await ImplementationManager.isInitialized();
  if (!isInitialized) {
    throw new Error('ImplementationManager not initialized');
  }

  // check if kernel is already set to the new value
  const currentKernel = await ImplementationManager.implementation();
  if (currentKernel === kernel) {
    console.log('Kernel already updated to the new value: ', kernel);
    return;
  }


  /* -------------UPDATE kernel address----------------- */
  const tx = await ImplementationManager.setImplementation(kernel);
  await tx.wait();

  console.log('kernel updated to ', kernel, ' with in tx: ', tx.hash);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });