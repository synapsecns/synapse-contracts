// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IWETH9} from "../../../contracts/router/interfaces/IWETH9.sol";

import {CommonBase} from "forge-std/Base.sol";
import {ERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/ERC20.sol";

contract MockWETH is CommonBase, ERC20, IWETH9 {
    constructor() ERC20("Mock WETH", "Mock WETH") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
        // Make sure ETH reserves are sufficient
        uint256 newBalance = address(this).balance + amount;
        vm.deal(address(this), newBalance);
    }

    function burn(address from, uint256 amount) external {
        _burn(from, amount);
        uint256 newBalance = address(this).balance - amount;
        vm.deal(address(this), newBalance);
    }

    function deposit() external payable {
        _mint(msg.sender, msg.value);
    }

    function withdraw(uint256 wad) external {
        _burn(msg.sender, wad);
        payable(msg.sender).transfer(wad);
    }
}
