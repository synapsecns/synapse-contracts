// SPDX-License-Identifier: MIT

pragma solidity 0.8.11;


library Types {
    struct RouterTrade {
        address[] path;
        address[] adapters;
        uint256 maxBridgeSlippage;
    }
}
