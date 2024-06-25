// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

// Import the required libraries and contracts
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PaymasterErc20 is ERC20, Ownable {

    // Define the constructor
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 100 * 10 ** decimals());
    }

  function mint(address to, uint256 amount) public onlyOwner {
    _mint(to, amount);
  }

  function burn(address from, uint256 amount) public onlyOwner {
    _burn(from, amount);
  }

  function decimals() public view virtual override returns (uint8) {
    return 16;
  }
}
