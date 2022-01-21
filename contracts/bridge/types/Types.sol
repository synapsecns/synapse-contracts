// SPDX-License-Identifier: MIT

pragma solidity >=0.6.12;
pragma experimental ABIEncoderV2;

library Types {
    struct RouterTrade {
        address[] path;
        address[] adapters;
        uint256 maxBridgeSlippage;
    }
}
