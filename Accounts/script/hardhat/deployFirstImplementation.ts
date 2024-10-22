/*
Deploy the FirstImplementation contract
*/

import { ethers } from 'hardhat';
import 'dotenv/config'

async function main() {
 
  const FirstImplementation = await ethers.getContractFactory('FirstImplementation'); // FirstImplementation

  // deploy FirstImplementation
  const tx = await FirstImplementation.deploy(); 
   
  console.log('FirstImplementation deployed to:', tx.target);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });