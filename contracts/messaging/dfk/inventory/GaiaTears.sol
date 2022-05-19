// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./InventoryItem.sol";

/// @title Gaia's Tears.
/// @author Frisky Fox - Defi Kingdoms
contract GaiaTears is InventoryItem {
    constructor() InventoryItem("Gaia's Tears", "DFKTEARS") {}
}
