// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {LinkedPoolIntegrationTest} from "./LinkedPoolIntegration.sol";

import {UniswapV3Module} from "../../../../contracts/router/modules/pool/uniswap/UniswapV3Module.sol";

contract LinkedPoolUniswapV3ModuleScrollTestFork is LinkedPoolIntegrationTest {
    // 2024-04-30
    uint256 public constant SCROLL_BLOCK_NUMBER = 5264400;

    // Uniswap V3 Router on Scroll
    address public constant UNI_V3_ROUTER = 0xC6433c65ED684e987287d4DE87869a0A7cc4C2eB;
    // Eden's Uniswap V3 Static Quoter on Scroll
    address public constant UNI_V3_STATIC_QUOTER = 0x1Db5a1d5D80fDEfc098635d3869Fa94d6fA44F5a;
    // Uniswap V3 USDC/USDT pool on Scroll
    address public constant UNI_V3_USDC_USDT_POOL = 0x887B414d34bA20Ae7ED5378380682f22071d08c2;

    // USDC on Scroll
    address public constant USDC = 0x06eFdBFf2a14a7c8E15944D1F4A48F9F95F663A4;
    // USDT on Scroll
    address public constant USDT = 0xf55BEC9cafDbE8730f096Aa55dad6D22d44099Df;

    UniswapV3Module public uniswapV3Module;

    constructor() LinkedPoolIntegrationTest("scroll", "UniswapV3Module", SCROLL_BLOCK_NUMBER) {}

    function deployModule() public override {
        uniswapV3Module = new UniswapV3Module(UNI_V3_ROUTER, UNI_V3_STATIC_QUOTER);
    }

    function addExpectedTokens() public override {
        // Expected order of tokens:
        // 0: USDC
        // 1: USDT
        addExpectedToken(USDC, "USDC");
        addExpectedToken(USDT, "USDT");
    }

    function addPools() public override {
        addPool({
            poolName: "USDC/USDT",
            nodeIndex: 0,
            pool: UNI_V3_USDC_USDT_POOL,
            poolModule: address(uniswapV3Module)
        });
    }
}
