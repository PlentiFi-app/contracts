/*
Deploy the Kernel contract
*/

import { ethers } from 'hardhat';
import 'dotenv/config'

async function main() {
 
  const Kernel = await ethers.getContractFactory('Kernel'); // Kernel

  const entrypointV07 = process.env.ENTRYPOINT_V_0_7_0;
  if(!entrypointV07) throw new Error('ENTRYPOINT_V_0_7_0 not set in env');

  // deploy Kernel
  const tx = await Kernel.deploy(entrypointV07);
   
  console.log('Kernel deployed to:', tx.target);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });