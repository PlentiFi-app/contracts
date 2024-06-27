// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import {ERC721} from "openzeppelin/contracts/token/ERC721/ERC721.sol";

// each call of increment will mint a new token
contract Increment721 is ERC721 {
    address public owner;

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {
        owner = msg.sender;
    }

    function mint(address to, uint256 tokenId) public {
        require(msg.sender == owner, "only owner can mint");
        _mint(to, tokenId);
    }
}
