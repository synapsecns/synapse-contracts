// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {MockERC20} from "./MockERC20.sol";

contract MockWrapperToken is MockERC20 {
    MockERC20 private underlying;

    constructor(address underlying_)
        MockERC20(string.concat(MockERC20(underlying_).symbol(), "[W]"), MockERC20(underlying_).decimals())
    {
        underlying = MockERC20(underlying_);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        underlying.burn(from, amount);
        underlying.mint(to, amount);
    }

    function _mint(address account, uint256 amount) internal virtual override {
        underlying.mint(account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual override {
        underlying.burn(account, amount);
    }
}
