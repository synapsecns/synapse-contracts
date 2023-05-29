// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {Test} from "forge-std/Test.sol";

abstract contract SwapQuoterV2Setup is Test {
    function deploySwapQuoter(
        address router_,
        address weth_,
        address owner
    ) internal virtual returns (address quoter_) {
        // Use deployCode to deploy 0.8 contracts from 0.6 test
        // new DefaultPoolCalc();
        address defaultPoolCalc = deployCode("DefaultPoolCalc.sol");
        // new SwapQuoterV2(router, defaultPoolCalc, weth_, owner);
        quoter_ = deployCode("SwapQuoterV2.sol", abi.encode(router_, defaultPoolCalc, weth_, owner));
        vm.label(defaultPoolCalc, "DefaultPoolCalc");
        vm.label(quoter_, "SwapQuoterV2");
    }
}
