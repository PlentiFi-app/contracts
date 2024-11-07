/*
Calls the stake function of the factoryStaker contract
*/

import { ethers } from 'hardhat';
import 'dotenv/config'

async function main() {
  const factoryStakerAddress = process.env.EXPECTED_PLENTIFI_FACTORY_STAKER_ADDRESS;
  if (!factoryStakerAddress) throw new Error('EXPECTED_PLENTIFI_FACTORY_STAKER_ADDRESS not set in env');
  const entryPoint = process.env.ENTRYPOINT_V_0_7_0;
  if (!entryPoint) throw new Error('ENTRYPOINT_V_0_7_0 not set in env');

  /* -------------ENSURE CONTRACTS ARE DEPLOYED----------------- */
  if (await ethers.provider.getCode(factoryStakerAddress) === '0x') throw new Error('FactoryStaker not deployed');

  /* -------------STAKE----------------- */
  const amountToStake = "1" // wei
  const unstakeDelay = "100" // seconds
  const FactoryStaker = await ethers.getContractAt("PlentiFiFactoryStaker", factoryStakerAddress);

  const stakeTx = await FactoryStaker.stake(entryPoint, unstakeDelay, { value: amountToStake });
  await stakeTx.wait();
  console.log('FactoryStaker staked ', amountToStake, ' wei in tx: ', stakeTx.hash);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });