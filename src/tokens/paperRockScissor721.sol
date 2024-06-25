// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract PaperRockScissor721 is ERC721 {

  uint256 public nextTokenId = 0;
  mapping(uint256 => string) public gameResult;

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {
    }

    function mint(address to, string memory result) external {
        _mint(to, nextTokenId);
        setGameResult(nextTokenId, result);

        nextTokenId++;
    }

    function burn(uint256 tokenId) external {
        _burn(tokenId);
        delete gameResult[tokenId];
    }

    function setGameResult(uint256 tokenId, string memory result) internal {
        gameResult[tokenId] = result;
    }
}
