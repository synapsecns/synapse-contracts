// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {ERC20} from "@openzeppelin/contracts-4.8.0/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    uint8 private _decimals;

    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals
    ) ERC20(name, symbol) {
        _decimals = decimals;
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function mint(address user, uint256 amount) external {
        _mint(user, amount);
    }

    function burn(address user, uint256 amount) external {
        _burn(user, amount);
    }
}
