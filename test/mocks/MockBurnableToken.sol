// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20, ERC20Burnable} from "@openzeppelin/contracts-4.5.0/token/ERC20/extensions/ERC20Burnable.sol";

// solhint-disable no-empty-blocks
/// @notice Obviously, do NOT use this token in production. It's only for testing purposes.
contract MockBurnableToken is ERC20Burnable {
    uint8 private _decimals;

    constructor(string memory name_, uint8 decimals_) ERC20(name_, name_) {
        _decimals = decimals_;
    }

    /// @notice We include an empty "test" function so that this contract does not appear in the coverage report.
    function testMockBurnableToken() external {}

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function mintTestTokens(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
