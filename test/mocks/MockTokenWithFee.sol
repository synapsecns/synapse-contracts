// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {Ownable} from "@openzeppelin/contracts-4.8.0/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts-4.8.0/token/ERC20/ERC20.sol";
import {Math} from "@openzeppelin/contracts-4.8.0/utils/math/Math.sol";

contract MockTokenWithFee is ERC20, Ownable {
    uint256 internal constant wad = 1e18;
    uint8 private _decimals;
    uint256 public fee; // in wad

    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals,
        uint256 _fee
    ) ERC20(name, symbol) {
        _decimals = decimals;

        require(_fee < wad, "fee > max");
        fee = _fee;
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

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        // mimics USDT: https://etherscan.io/token/0xdac17f958d2ee523a2206206994597c13d831ec7?a=0xcffad3200574698b78f32232aa9d63eabd290703#code
        uint256 feeAmount = Math.mulDiv(amount, fee, wad);
        _transfer(to, owner(), feeAmount);
    }
}
