// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Ownable} from "@openzeppelin/contracts-4.5.0/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/ERC20.sol";

contract MockERC20TransferFees is ERC20, Ownable {
    uint8 private _decimals;

    uint256 public constant FEE_DECIMALS = 10**10;
    uint256 public immutable feeRate;

    constructor(
        string memory name_,
        uint8 decimals_,
        uint256 feeRate_
    ) ERC20(name_, name_) {
        _decimals = decimals_;
        feeRate = feeRate_;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function burn(address account, uint256 amount) external {
        _burn(account, amount);
    }

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        uint256 amountFees = (amount * feeRate) / FEE_DECIMALS;
        super._transfer(from, owner(), amountFees);

        amount -= amountFees;
        super._transfer(from, to, amount);
    }
}
