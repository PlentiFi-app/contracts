/*
This script update the ProxyUpgrader in the ImplementationManager 
*/

import { keccak256, AbiCoder } from 'ethers';
import { ethers } from 'hardhat';
import 'dotenv/config'

async function main() {
  const implementationManagerAddress = process.env.EXPECTED_IMPLEMENTATION_MANAGER_ADDRESS;
  if (!implementationManagerAddress) throw new Error('EXPECTED_IMPLEMENTATION_MANAGER_ADDRESS not set in env');
  const proxyUpgrader = process.env.PROXY_UPGRADER_ADDRESS;
  if (!proxyUpgrader) throw new Error('PROXY_UPGRADER_ADDRESS not set in env');


  /* -------------ENSURE CONTRACTS ARE DEPLOYED----------------- */
  if (await ethers.provider.getCode(implementationManagerAddress) === '0x') throw new Error('ImplementationManager not deployed');
  if (await ethers.provider.getCode(proxyUpgrader) === '0x') throw new Error('ProxyUpgrader not deployed');

  /* -------------INITIALIZE ImplementationManager----------------- */
  const implementationManagerAbi = require('../../artifacts/src/plentifi-deployersv1/ImplementationManager.sol/ImplementationManager.json').abi;
  const ImplementationManager = await ethers.getContractAt(implementationManagerAbi, implementationManagerAddress);

  // check if the implementationManager is already initialized
  const isInitialized = await ImplementationManager.isInitialized();
  if (!isInitialized) {
    throw new Error('ImplementationManager not initialized');
  }

  // check if the proxyUpgrader is already set to the new value
  const currentProxyUpgrader = await ImplementationManager.proxyUpgrader();
  if (currentProxyUpgrader === proxyUpgrader) {
    console.log('ProxyUpgrader already updated to the new value: ', proxyUpgrader);
    return;
  }


  /* -------------UPDATE proxyUpgrader address----------------- */
  const tx = await ImplementationManager.setProxyUpgrader(proxyUpgrader);
  await tx.wait();

  console.log('proxyUpgrader updated to ', proxyUpgrader, ' with in tx: ', tx.hash);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });