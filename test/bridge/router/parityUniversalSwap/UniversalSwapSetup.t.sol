// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {SwapQuoter} from "../SynapseRouterSuite.t.sol";

import {Test} from "forge-std/Test.sol";

interface IUniversalSwap {
    function addPool(
        uint256 nodeIndex,
        address pool,
        address poolModule,
        uint256 tokensAmount
    ) external;
}

/// Helper contract to deploy UniversalSwap contract and add it to SwapQuoter instead of the underlying pool.
abstract contract UniversalSwapSetup is Test {
    mapping(address => address) internal tokenToUniversalSwap;

    function deployUniversalSwap(
        address bridgeToken,
        address pool,
        uint256 tokensAmount
    ) public returns (address universalSwap) {
        // Deploy 0.8 UniversalSwap contract: new UniversalSwap(bridgeToken)
        universalSwap = deployCode("UniversalSwap.sol", abi.encode(bridgeToken));
        vm.label(universalSwap, "UniversalSwap");
        // Add pool to UniversalSwap
        IUniversalSwap(universalSwap).addPool(0, pool, address(0), tokensAmount);
        // Save UniversalSwap address for later use
        tokenToUniversalSwap[bridgeToken] = universalSwap;
    }

    function addUniversalSwap(SwapQuoter swapQuoter, address bridgeToken) public {
        // Add UniversalSwap to SwapQuoter as a simple pool
        beforeOwnerOperation();
        swapQuoter.addPool(tokenToUniversalSwap[bridgeToken]);
    }

    function removeUniversalSwap(SwapQuoter swapQuoter, address bridgeToken) public {
        beforeOwnerOperation();
        swapQuoter.removePool(tokenToUniversalSwap[bridgeToken]);
    }

    function beforeOwnerOperation() public virtual {}
}
