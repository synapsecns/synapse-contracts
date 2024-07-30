// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {LinkedPoolIntegrationTest} from "./LinkedPoolIntegration.sol";

import {AlgebraModule} from "../../../../contracts/router/modules/pool/algebra/AlgebraModule.sol";

contract LinkedPoolAlgebraModuleLineaTestFork is LinkedPoolIntegrationTest {
    // 2024-07-23
    uint256 public constant LINEA_BLOCK_NUMBER = 0;

    // Eden's Algebra Static Quoter on Linea
    address public constant ALGEBRA_STATIC_QUOTER = 0x70CeB9E0237546115E2F108f8F7658e42dAF3296;

    // Algebra Router on Linea
    address public constant ALGEBRA_ROUTER = 0x3921e8cb45B17fC029A0a6dE958330ca4e583390;
    // Algebra USDC.e/USDT pool on Linea
    address public constant ALGEBRA_USDT_POOL = 0x6E9AD0B8A41E2c148e7B0385d3EcBFDb8A216a9B;

    // Bridged USDC (USDC_E) on Linea
    address public constant USDC_E = 0x176211869cA2b568f2A7D4EE941E073a821EE1ff;
    // USDT on Linea
    address public constant USDT = 0xA219439258ca9da29E9Cc4cE5596924745e12B93;

    address public algebraModule;

    constructor() LinkedPoolIntegrationTest("linea", "AlgebraModule.Lynex", LINEA_BLOCK_NUMBER) {}

    function deployModule() public override {
        algebraModule = address(new AlgebraModule(ALGEBRA_ROUTER, ALGEBRA_STATIC_QUOTER));
    }

    function addExpectedTokens() public override {
        // Expected order of tokens:
        // 0: USDC.e
        // 1: USDT
        addExpectedToken(USDC_E, "USDC.e");
        addExpectedToken(USDT, "USDT");
    }

    function addPools() public override {
        addPool({poolName: "USDC.e/USDT", nodeIndex: 0, pool: ALGEBRA_USDT_POOL, poolModule: algebraModule});
    }
}
