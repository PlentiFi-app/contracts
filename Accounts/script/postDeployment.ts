/*
Script to run when all the deployment is done:
- ImplementationManager
- FactoryStaker
- AccountFactory

This script: 
- initializes the ImplementationManager with the useful addresses
- register the AccountFactory in the FactoryStaker
*/
// SHOULD BE RAN WITH THE ENV FROM ../.env LOADED

import { keccak256, AbiCoder } from 'ethers';
import { ethers } from 'hardhat';
import 'dotenv/config'

async function main() {
  const implementationManagerAddress = process.env.EXPECTED_IMPLEMENTATION_MANAGER_ADDRESS;
  if (!implementationManagerAddress) throw new Error('EXPECTED_IMPLEMENTATION_MANAGER_ADDRESS not set in env');
  const factoryStakerAddress = process.env.EXPECTED_PLENTIFI_FACTORY_STAKER_ADDRESS;
  if (!factoryStakerAddress) throw new Error('EXPECTED_PLENTIFI_FACTORY_STAKER_ADDRESS not set in env');
  const accountFactoryAddress = process.env.EXPECTED_PLENTIFI_CANONICAL_FACTORY_ADDRESS;
  if (!accountFactoryAddress) throw new Error('EXPECTED_PLENTIFI_CANONICAL_FACTORY_ADDRESS not set in env');
  const kernelAddress = process.env.KERNEL_IMPLEMENTATION_ADDRESS;
  if (!kernelAddress) throw new Error('KERNEL_IMPLEMENTATION_ADDRESS not set in env');
  const proxyUpgrader = process.env.PROXY_UPGRADER_ADDRESS;
  if (!proxyUpgrader) throw new Error('PROXY_UPGRADER_ADDRESS not set in env');


  /* -------------ENSURE CONTRACTS ARE DEPLOYED----------------- */
  if (await ethers.provider.getCode(implementationManagerAddress) === '0x') throw new Error('ImplementationManager not deployed');
  if (await ethers.provider.getCode(factoryStakerAddress) === '0x') throw new Error('FactoryStaker not deployed');
  if (await ethers.provider.getCode(accountFactoryAddress) === '0x') throw new Error('AccountFactory not deployed');
  if (await ethers.provider.getCode(kernelAddress) === '0x') throw new Error('Kernel not deployed');
  if (await ethers.provider.getCode(proxyUpgrader) === '0x') throw new Error('ProxyUpgrader not deployed');

  /* -------------INITIALIZE ImplementationManager----------------- */
  const implementationManagerAbi = require('../artifacts/src/plentifi-deployersv1/ImplementationManager.sol/ImplementationManager.json').abi;
  const ImplementationManager = await ethers.getContractAt(implementationManagerAbi, implementationManagerAddress);

  // check if already initialized
  const isInitialized = await ImplementationManager.isInitialized();
  if (isInitialized) {
    // get the current implementation, entrypoint and proxyUpgrader 
    const currentImplementation = await ImplementationManager.implementation();
    const currentEntrypoint = await ImplementationManager.entryPoint();
    const currentProxyUpgrader = await ImplementationManager.proxyUpgrader();

    if (currentImplementation !== kernelAddress || currentProxyUpgrader !== proxyUpgrader) {
      throw new Error('ImplementationManager already initialized with different values');
    }
  } else {

    const initializationTx = await ImplementationManager.initialize(kernelAddress, proxyUpgrader);
    await initializationTx.wait();
    console.log('ImplementationManager initialized with Kernel, Entrypoint and ProxyUpgrader in tx: ', initializationTx.hash);
  }
  /* -------------REGISTER AccountFactory in FactoryStaker----------------- */
  const factoryStakerAbi = require('../artifacts/src/plentifi-deployersv1/factory/FactoryStaker.sol/PlentifiFactoryStaker.json').abi;
  const FactoryStaker = await ethers.getContractAt(factoryStakerAbi, factoryStakerAddress);

  const approvalTx = await FactoryStaker.approveFactory(accountFactoryAddress, true);
  await approvalTx.wait();
  console.log('AccountFactory registered in FactoryStaker in tx: ', approvalTx.hash);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });