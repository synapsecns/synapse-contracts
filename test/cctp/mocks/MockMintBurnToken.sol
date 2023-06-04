// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IMintBurnToken} from "../../../contracts/cctp/interfaces/IMintBurnToken.sol";
import {ERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/ERC20.sol";

contract MockMintBurnToken is ERC20, IMintBurnToken {
    address public minter;

    constructor(address minter_) ERC20("MockC", "MockC") {
        minter = minter_;
    }

    function mint(address to, uint256 amount) external returns (bool) {
        require(msg.sender == minter, "Only minter can mint");
        _mint(to, amount);
        return true;
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}
