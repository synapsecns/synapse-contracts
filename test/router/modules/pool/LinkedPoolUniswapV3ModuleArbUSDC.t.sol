// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {LinkedPoolIntegrationTest} from "./LinkedPoolIntegration.sol";

import {UniswapV3Module} from "../../../../contracts/router/modules/pool/uniswap/UniswapV3Module.sol";

contract LinkedPoolUniswapV3ModuleArbUSDCTestFork is LinkedPoolIntegrationTest {
    string private constant ARB_ENV_RPC = "ARBITRUM_API";
    // 2023-06-27
    uint256 public constant ARB_BLOCK_NUMBER = 105400000;

    // Uniswap V3 Router on Arbitrum
    address public constant UNI_V3_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    // Eden's Uniswap V3 Static Quoter on Arbitrum
    address public constant UNI_V3_STATIC_QUOTER = 0xc80f61d1bdAbD8f5285117e1558fDDf8C64870FE;
    // Uniswap V3 USDC/USDC.e pool on Arbitrum
    address public constant UNI_V3_USDC_POOL = 0x8e295789c9465487074a65b1ae9Ce0351172393f;

    // nUSD/USDC.e/USDT DefaultPool on Arbitrum
    address public constant NUSD_POOL = 0x9Dd329F5411466d9e0C488fF72519CA9fEf0cb40;

    // Bridged USDC (USDC.e) on Arbitrum
    address public constant USDC_E = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
    // Native USDC on Arbitrum
    address public constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    // nUSD on Arbitrum
    address public constant NUSD = 0x2913E812Cf0dcCA30FB28E6Cac3d2DCFF4497688;
    // USDT on Arbitrum
    address public constant USDT = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;

    UniswapV3Module public uniswapV3Module;

    constructor() LinkedPoolIntegrationTest(ARB_ENV_RPC, ARB_BLOCK_NUMBER) {}

    function afterBlockchainForked() public override {
        uniswapV3Module = new UniswapV3Module(UNI_V3_ROUTER, UNI_V3_STATIC_QUOTER);
    }

    function addExpectedTokens() public override {
        // Expected order of tokens:
        // 0: USDC
        // 1: USDC.e
        // 2: nUSD
        // 3: USDT
        addExpectedToken(USDC, "USDC");
        addExpectedToken(USDC_E, "USDC.e");
        addExpectedToken(NUSD, "nUSD");
        addExpectedToken(USDT, "USDT");
    }

    function addPools() public override {
        addPool({poolName: "USDC.e/USDC", nodeIndex: 0, pool: UNI_V3_USDC_POOL, poolModule: address(uniswapV3Module)});
        addPool({poolName: "nUSD/USDC.e/USDT", nodeIndex: 1, pool: NUSD_POOL});
    }
}
