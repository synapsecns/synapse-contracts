// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IPausable} from "../../contracts/router/interfaces/IPausable.sol";

import {MockSaddlePool} from "./MockSaddlePool.sol";

contract MockSaddlePausablePool is MockSaddlePool, IPausable {
    // solhint-disable-next-line no-empty-blocks
    constructor(address[] memory tokens) MockSaddlePool(tokens) {}

    function paused() external view override returns (bool) {
        return _paused;
    }

    function setPaused(bool paused_) external {
        _paused = paused_;
    }
}
