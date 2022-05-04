// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-4.5.0/token/ERC20/presets/ERC20PresetMinterPauser.sol";

/// @title Base class for Inventory Items.
/// @author Frisky Fox - Defi Kingdoms
contract InventoryItem is ERC20PresetMinterPauser {
    constructor(string memory _name, string memory _symbol) ERC20PresetMinterPauser(_name, _symbol) {}

    function decimals() public view virtual override returns (uint8) {
        return 0;
    }
}
