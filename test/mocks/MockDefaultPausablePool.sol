// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IPausable} from "../../contracts/router/interfaces/IPausable.sol";

import {MockDefaultPool} from "./MockDefaultPool.sol";

contract MockDefaultPausablePool is MockDefaultPool, IPausable {
    // solhint-disable-next-line no-empty-blocks
    constructor(address[] memory tokens) MockDefaultPool(tokens) {}

    function paused() external view override returns (bool) {
        return _paused;
    }

    function setPaused(bool paused_) external {
        _paused = paused_;
    }
}
