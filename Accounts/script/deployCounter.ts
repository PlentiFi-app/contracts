/*
Deploy the Counter contract
*/

import { ethers } from 'hardhat';
import 'dotenv/config'

async function main() {
 
  const Counter = await ethers.getContractFactory('Counter'); // Counter

  // deploy Counter
  const tx = await Counter.deploy();
   
  console.log('Counter deployed to:', tx.target);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });