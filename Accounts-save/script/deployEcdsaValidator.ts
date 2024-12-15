/*
Deploy the ECDSAValidator contract
*/

import { ethers } from 'hardhat';
import 'dotenv/config'

async function main() {
 
  const ECDSAValidator = await ethers.getContractFactory('ECDSAValidator'); // ECDSAValidator

  // deploy Counter
  const tx = await ECDSAValidator.deploy();
   
  console.log('ECDSAValidator deployed to:', tx.target);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });