// SPDX-License-Identifier: MIT

// simple counter contract to test the PlentiFi toolkit

pragma solidity ^0.8.19;

import {Increment721} from "./Increment721.sol";

contract Increment {
  uint256 public count = 0;
  uint256 public differentCallers = 0;
  address lastIncrementer;
  Increment721 increment721;

  mapping (address => bool) public hasIncremented;

  constructor() {
    // create a new instance of the Increment721 contract
    increment721 = new Increment721("PlentiFi-Demo-Increment721", "INC721");
  }

  function increment() public {
    count += 1;
    lastIncrementer = msg.sender;

    if (!hasIncremented[msg.sender]) {
      differentCallers += 1;
      hasIncremented[msg.sender] = true;
    }

    increment721.mint(msg.sender, count);
  }

  function getLastIncrementer() public view returns (address) {
    return lastIncrementer;
  }

  function getCount() public view returns (uint256) {
    return count;
  }
}
