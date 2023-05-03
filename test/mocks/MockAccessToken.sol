// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {AccessControl} from "@openzeppelin/contracts-4.8.0/access/AccessControl.sol";
import {MockToken} from "./MockToken.sol";

contract MockAccessToken is MockToken, AccessControl {
    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals
    ) MockToken(name, symbol, decimals) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
}
