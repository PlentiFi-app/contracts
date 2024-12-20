// SPDX-License-Identifier: MIT

// simple counter contract to test the sdk

pragma solidity ^0.8.19;

contract Increment {
  uint256 public count = 0;
  address lastIncrementer;

  function increment() public {
    count += 1;
    lastIncrementer = msg.sender;
  }

  function getLastIncrementer() public view returns (address) {
    return lastIncrementer;
  }
}
