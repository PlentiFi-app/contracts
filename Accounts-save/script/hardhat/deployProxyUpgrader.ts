/*
Deploy the ProxyUpgrader contract
*/

import { ethers } from 'hardhat';
import 'dotenv/config'

async function main() {
 
  const ProxyUpgrader = await ethers.getContractFactory('ProxyUpgrader'); // ProxyUpgrader

  // deploy ProxyUpgrader
  const tx = await ProxyUpgrader.deploy(); 
   
  console.log('ProxyUpgrader deployed to:', tx.target);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });