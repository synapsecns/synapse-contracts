// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "./RateLimitedBridge.sol";

contract BridgeRateLimiterTestAvax is RateLimitedBridge {
    address public constant BRIDGE = 0xC05e61d0E7a63D27546389B7aD62FdFf5A91aACE;
    address public constant NUSD_POOL =
        0xED2a7edd7413021d440b09D654f3b87712abAB66;

    IERC20 public constant NUSD =
        IERC20(0xCFc37A6AB183dd4aED08C204D1c2773c0b1BDf46);

    constructor() RateLimitedBridge(BRIDGE) {
        this;
    }

    function testUpgradedCorrectly() public {
        bytes32[] memory kappas = new bytes32[](4);
        kappas[
            0
        ] = 0x86b8965e37f1cce9f656ba75889b2f2298b263eed1c63aea02bed5c8974f63f8;
        kappas[
            1
        ] = 0x0a0f257cd271a186e37f9a27eba2449eb6e653f8504cdcf1da5a3136457bd352;
        kappas[
            2
        ] = 0x3d8fdbb615d44bd698866ece843f3a61b8c9bfc8d63a7ee59687b9af73132db5;
        kappas[
            3
        ] = 0x9d227741cf4247722bbdcd1a910991a24efbb12e5f538410922d07fa0fa42247;

        _testUpgrade(kappas);
    }

    function testMintAndSwap(uint96 amount) public {
        _testBridgeFunction(
            amount,
            NUSD,
            false,
            false,
            IBridge.mintAndSwap.selector,
            abi.encode(NUSD_POOL, 0, 1, 0, type(uint256).max)
        );
    }
}
