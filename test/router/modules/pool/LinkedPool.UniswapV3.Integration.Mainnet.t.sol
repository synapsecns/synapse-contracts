// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {LinkedPoolIntegrationTest} from "./LinkedPoolIntegration.sol";

import {UniswapV3Module} from "../../../../contracts/router/modules/pool/uniswap/UniswapV3Module.sol";

contract LinkedPoolUniswapV3ModuleEthTestFork is LinkedPoolIntegrationTest {
    // 2023-11-03
    uint256 public constant ETH_BLOCK_NUMBER = 18490000;

    // Uniswap V3 Router on Ethereum
    address public constant UNI_V3_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    // Eden's Uniswap V3 Static Quoter on Ethereum
    address public constant UNI_V3_STATIC_QUOTER = 0xc80f61d1bdAbD8f5285117e1558fDDf8C64870FE;
    // Uniswap V3 USDC/USDT pool on Ethereum
    address public constant UNI_V3_USDC_POOL = 0x3416cF6C708Da44DB2624D63ea0AAef7113527C6;

    // DAI/USDC/USDT Nexus DefaultPool on Ethereum
    address public constant NEXUS_POOL = 0x1116898DdA4015eD8dDefb84b6e8Bc24528Af2d8;

    // Native USDC on Ethereum
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    // Native USDT on Ethereum
    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    // Native DAI on Ethereum
    address public constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    UniswapV3Module public uniswapV3Module;

    constructor() LinkedPoolIntegrationTest("mainnet", "UniswapV3Module", ETH_BLOCK_NUMBER) {}

    function deployModule() public override {
        uniswapV3Module = new UniswapV3Module(UNI_V3_ROUTER, UNI_V3_STATIC_QUOTER);
    }

    function addExpectedTokens() public override {
        // Expected order of tokens:
        // 0: USDC
        // 1: DAI
        // 2: USDT
        // 3: USDT
        addExpectedToken(USDC, "USDC");
        addExpectedToken(DAI, "DAI");
        addExpectedToken(USDT, "USDT");
        addExpectedToken(USDT, "USDT");
    }

    function addPools() public override {
        addPool({poolName: "DAI/USDC/USDT", nodeIndex: 0, pool: NEXUS_POOL});
        addPool({poolName: "USDC/USDT", nodeIndex: 0, pool: UNI_V3_USDC_POOL, poolModule: address(uniswapV3Module)});
    }
}
