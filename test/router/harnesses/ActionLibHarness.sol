// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Action, ActionLib} from "../../../contracts/router/libs/Structs.sol";

contract ActionLibHarness {
    function allActions() public pure returns (uint256) {
        uint256 result = ActionLib.allActions();
        return result;
    }

    function isIncluded(Action action, uint256 actionMask) public pure returns (bool) {
        bool result = ActionLib.isIncluded(action, actionMask);
        return result;
    }

    function mask(Action action) public pure returns (uint256) {
        uint256 result = ActionLib.mask(action);
        return result;
    }

    function mask(Action a, Action b) public pure returns (uint256) {
        uint256 result = ActionLib.mask(a, b);
        return result;
    }
}
