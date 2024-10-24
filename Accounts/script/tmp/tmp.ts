/*
Test the user account deployment process by deploying an account (with dummy values)
*/

import { keccak256, AbiCoder } from 'ethers';
import { ethers } from 'hardhat';
import 'dotenv/config'

async function main() {

  /* -------------GET THE RELEVANT VALUES----------------- */
  const factoryStakerAddress = process.env.EXPECTED_PLENTIFI_FACTORY_STAKER_ADDRESS;
  if (!factoryStakerAddress) throw new Error('EXPECTED_PLENTIFI_FACTORY_STAKER_ADDRESS not set in env');
  const accountFactoryAddress = process.env.EXPECTED_PLENTIFI_CANONICAL_FACTORY_ADDRESS;
  if (!accountFactoryAddress) throw new Error('EXPECTED_PLENTIFI_CANONICAL_FACTORY_ADDRESS not set in env');
  const abiCoder = new AbiCoder();

  ///////////////////
  // const rawWithSelector = "0xc5265d5d00000000000000000000000043682A44f6bF6A4B7FA9Fa7Fbb8f018e0f332b480000000000000000000000000000000000000000000000000000000000000060b3e5198d543c6bc39bfb99ca47e4be7508c2c5db3d9a3c909edde474bf1bcc8b00000000000000000000000000000000000000000000000000000000000001243c3b752b01724B7836c64F370691826D9654a75aACbc1855Be0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000156000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
  // const raw ="0x00000000000000000000000043682A44f6bF6A4B7FA9Fa7Fbb8f018e0f332b480000000000000000000000000000000000000000000000000000000000000060b3e5198d543c6bc39bfb99ca47e4be7508c2c5db3d9a3c909edde474bf1bcc8b00000000000000000000000000000000000000000000000000000000000001243c3b752b01724B7836c64F370691826D9654a75aACbc1855Be0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000156000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
  // // decode using abi decoder
  // const decoded = abiCoder.decode(
  //   ['address', 'bytes', 'bytes32'],
  //   raw
  // );
  // console.log('decoded:', decoded);
  // return;
  ///////////////////
  // bytes 3c3b752b
  const createDataTest = "0x3c3b752b01724b7836c64f370691826d9654a75aacbc1855be0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000001560000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
  // ///////////////////
  // const decodedCreateData = abiCoder.decode(
  //   ['bytes21', 'address', 'bytes', 'bytes', 'bytes[]'],
  //   createDataTest
  // );
  // console.log('decodedCreateData:', parseInitData(createDataTest));
  // return;
  ///////////////////
  const createData = createDataTest;

  // const createData = abiCoder.encode(
  //   ['bytes21', 'address', 'bytes', 'bytes', 'bytes[]'],
  //   [
  //     '0x0123456789abcdef0123456789abcdef0123456789',
  //     "0xfedcba9876543210fedcba9876543210fedcba98",
  //     '0x01',
  //     '0x02',
  //     []
  //   ]
  // );

  console.log('createData:', createData);

  // bytes32 
  const salt = "0xb3e5198d543c6bc39bfb99ca47e4be7508c2c5db3d9a3c909edde474bf1bcc9b"; // keccak256('0x0123456789abcdef');

  /* -------------ENSURE accountFactory IS APPROVED----------------- */
  const FactoryStaker = await ethers.getContractAt('PlentifiFactoryStaker', factoryStakerAddress);

  const isApproved = await FactoryStaker.approved(accountFactoryAddress);
  if (!isApproved) {
    console.log('Account Factory  at ', accountFactoryAddress, 'not approved for FactoryStaker at ', factoryStakerAddress);
    return;
  }
  console.log('FactoryStaker is approved');

  /* -------------DEPLOY THE ACCOUNT----------------- */


  const tx = await FactoryStaker.deployWithFactory(accountFactoryAddress, createData, salt);

  const receipt = await tx.wait();

  console.log('tx hash:', receipt.hash);

}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

function parseInitData(initData: string): {
  rootValidator: string;  // Assuming ValidationId is a bytes21
  hook: string;  // Assuming IHook is an address
  validatorData: string;
  hookData: string;
  initConfig: string[];
} {
  // Define the parameter types in the order of the Solidity function
  const types = [
    "bytes21",  // rootValidator
    "address",  // hook
    "bytes",    // validatorData
    "bytes",    // hookData
    "bytes[]"   // initConfig
  ];

  // Use ethers ABI coder to decode the data
  const abiCoder = new ethers.AbiCoder();
  const decoded = abiCoder.decode(types, initData);

  // Return the decoded values as an object
  return {
    rootValidator: decoded[0],
    hook: decoded[1],
    validatorData: decoded[2],
    hookData: decoded[3],
    initConfig: decoded[4]
  };
}