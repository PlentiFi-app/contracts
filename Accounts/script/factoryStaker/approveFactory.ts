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
  const factoryStakerAddress = process.env.EXPECTED_PLENTIFI_FACTORY_STAKER_ADDRESS;
  if (!factoryStakerAddress) throw new Error('EXPECTED_PLENTIFI_FACTORY_STAKER_ADDRESS not set in env');
  const accountFactoryAddress = process.env.EXPECTED_PLENTIFI_CANONICAL_FACTORY_ADDRESS;
  if (!accountFactoryAddress) throw new Error('EXPECTED_PLENTIFI_CANONICAL_FACTORY_ADDRESS not set in env');

  /* -------------ENSURE CONTRACTS ARE DEPLOYED----------------- */
  if (await ethers.provider.getCode(factoryStakerAddress) === '0x') throw new Error('FactoryStaker not deployed');
  if (await ethers.provider.getCode(accountFactoryAddress) === '0x') throw new Error('AccountFactory not deployed');

  /* -------------REGISTER AccountFactory in FactoryStaker----------------- */
  const FactoryStaker = await ethers.getContractAt("PlentifiFactoryStaker", factoryStakerAddress);

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