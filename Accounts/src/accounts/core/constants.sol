// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

bytes4 constant ERC1271_MAGICVALUE = 0x1626ba7e;
bytes4 constant ERC1271_INVALID = 0xffffffff;
// erc4337
uint256 constant SIG_VALIDATION_FAILED_UINT = 1;
uint256 constant SIG_VALIDATION_SUCCESS_UINT = 0;

bytes1 constant MODULE_TYPE_VALIDATOR = 0x01;
bytes1 constant MODULE_TYPE_HOOK = 0x02;
