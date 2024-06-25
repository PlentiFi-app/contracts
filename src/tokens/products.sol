// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract TestProducts721 is ERC721 {
    uint256 public nextTokenId = 0;
    mapping(uint256 => string) public item;

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {
        _mint(msg.sender, nextTokenId);

        nextTokenId++;
    }

    function buy(address to, string memory _item) external {
        _mint(to, nextTokenId);
        item[nextTokenId] = _item;

        nextTokenId++;
    }

    function burn(uint256 tokenId) external {
        _burn(tokenId);

        delete item[tokenId];
    }
}
