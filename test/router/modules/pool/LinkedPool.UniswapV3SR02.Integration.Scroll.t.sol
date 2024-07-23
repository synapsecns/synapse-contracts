// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {LinkedPoolIntegrationTest} from "./LinkedPoolIntegration.sol";

import {UniswapV3SR02Module} from "../../../../contracts/router/modules/pool/uniswap/UniswapV3SR02Module.sol";

contract LinkedPoolUniswapV3SR02ModuleScrollTestFork is LinkedPoolIntegrationTest {
    // 2024-07-23
    uint256 public constant SCROLL_BLOCK_NUMBER = 7704400;

    // Uniswap V3 Router on Scroll
    address public constant UNI_V3_ROUTER = 0xfc30937f5cDe93Df8d48aCAF7e6f5D8D8A31F636;
    // Eden's Uniswap V3 Static Quoter on Scroll
    address public constant UNI_V3_STATIC_QUOTER = 0x9Ffa621e973CB1f9Be6B75848a55a71A66f227d7;
    // Uniswap V3 USDC/USDT pool on Scroll
    address public constant UNI_V3_USDC_USDT_POOL = 0xf1783F3377b3A70465C193eF33942c0803121ba0;

    // USDC on Scroll
    address public constant USDC = 0x06eFdBFf2a14a7c8E15944D1F4A48F9F95F663A4;
    // USDT on Scroll
    address public constant USDT = 0xf55BEC9cafDbE8730f096Aa55dad6D22d44099Df;

    UniswapV3SR02Module public uniswapV3SR02Module;

    constructor() LinkedPoolIntegrationTest("scroll", "UniswapV3SR02Module", SCROLL_BLOCK_NUMBER) {}

    function deployModule() public override {
        uniswapV3SR02Module = new UniswapV3SR02Module(UNI_V3_ROUTER, UNI_V3_STATIC_QUOTER);
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
            poolModule: address(uniswapV3SR02Module)
        });
    }
}
