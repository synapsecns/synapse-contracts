// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {LinkedPoolIntegrationTest} from "./LinkedPoolIntegration.sol";

import {AlgebraModule} from "../../../../contracts/router/modules/pool/algebra/AlgebraModule.sol";

contract LinkedPoolAlgebraModuleBaseTestFork is LinkedPoolIntegrationTest {
    // 2023-10-25
    uint256 public constant BASE_BLOCK_NUMBER = 5731450;

    // Eden's Algebra Static Quoter on Base
    address public constant SYNTH_SWAP_STATIC_QUOTER = 0x1Db5a1d5D80fDEfc098635d3869Fa94d6fA44F5a;

    // SynthSwap Router on Base
    address public constant SYNTH_SWAP_ROUTER = 0x2dD788D8B399caa4eE92B5492A6A238Fdf2437de;
    // SynthSwap USDC.e/DAI pool on Base
    address public constant SYNTH_SWAP_DAI_POOL = 0x2C1E1A69ee809d3062AcE40fB83A9bFB59623d95;
    // SynthSwap USDC.e/WETH pool on Base
    address public constant SYNTH_SWAP_WETH_POOL = 0xE0712C087ECb8A0Dd20914626152eBf4890708c2;

    // Bridged USDC (USDC_E) on Base
    address public constant USDC_E = 0xd9aAEc86B65D86f6A7B5B1b0c42FFA531710b6CA;
    // DAI on Base
    address public constant DAI = 0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb;
    // WETH on Base
    address public constant WETH = 0x4200000000000000000000000000000000000006;

    address public synthSwapModule;

    constructor() LinkedPoolIntegrationTest("base", "AlgebraModule.SynthSwap", BASE_BLOCK_NUMBER) {}

    function deployModule() public override {
        synthSwapModule = address(new AlgebraModule(SYNTH_SWAP_ROUTER, SYNTH_SWAP_STATIC_QUOTER));
    }

    function addExpectedTokens() public override {
        // Expected order of tokens:
        // 0: USDC.e
        // 1: DAI
        // 2: WETH
        addExpectedToken(USDC_E, "USDC.e");
        addExpectedToken(DAI, "DAI");
        addExpectedToken(WETH, "WETH");
    }

    function addPools() public override {
        addPool({poolName: "USDC.e/DAI", nodeIndex: 0, pool: SYNTH_SWAP_DAI_POOL, poolModule: synthSwapModule});
        addPool({poolName: "USDC.e/WETH", nodeIndex: 0, pool: SYNTH_SWAP_WETH_POOL, poolModule: synthSwapModule});
    }
}
