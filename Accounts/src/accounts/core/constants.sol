// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

bytes4 constant ERC1271_MAGICVALUE = 0x1626ba7e;
bytes4 constant ERC1271_INVALID = 0xffffffff;
// erc4337
uint256 constant SIG_VALIDATION_FAILED_UINT = 1;
uint256 constant SIG_VALIDATION_SUCCESS_UINT = 0;

bytes1 constant MODULE_TYPE_VALIDATOR = 0x01;
bytes1 constant MODULE_TYPE_HOOK = 0x02;

bytes32 constant ERC1967_IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
