//SPDX-License-Identifier: UNLICENSED
pragma solidity =0.6.6;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract ERC20Mock is ERC20 {
    constructor(string memory name_, string memory symbol_) public ERC20(name_, symbol_) {}

    function mint(address to, uint256 x) public {
        _mint(to, x);
    }

    function burn(address from, uint256 x) public {
        _burn(from, x);
    }

    function burnAll(address from) public {
        _burn(from, balanceOf(from));
    }
}
