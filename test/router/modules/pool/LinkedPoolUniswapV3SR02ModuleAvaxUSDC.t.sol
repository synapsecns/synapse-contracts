// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {LinkedPoolIntegrationTest} from "./LinkedPoolIntegration.t.sol";

import {UniswapV3SR02Module} from "../../../../contracts/router/modules/pool/uniswap/UniswapV3SR02Module.sol";

contract LinkedPoolUniswapV3SR02ModuleAvaxUSDCTestFork is LinkedPoolIntegrationTest {
    string private constant AVAX_ENV_RPC = "AVALANCHE_API";
    // 2023-09-05
    uint256 public constant AVAX_BLOCK_NUMBER = 34800000;

    // Uniswap V3 SwapRouter02 on Avalanche
    address public constant UNI_V3_SWAP_ROUTER_02 = 0xbb00FF08d01D300023C629E8fFfFcb65A5a578cE;

    // Eden's Uniswap V3 Static Quoter on Avalanche
    address public constant UNI_V3_STATIC_QUOTER = 0xc15804984E3e77B7f8A60E4553e2289c5fdeAe8B;

    // Uniswap V3 USDC/USDT pool on Avalanche
    address public constant UNI_V3_USDC_POOL = 0x804226cA4EDb38e7eF56D16d16E92dc3223347A0;

    // Native USDC on Avalanche
    address public constant USDC = 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E;
    // Native USDT on Avalanche
    address public constant USDT = 0x9702230A8Ea53601f5cD2dc00fDBc13d4dF4A8c7;

    UniswapV3SR02Module public uniswapV3SR02Module;

    constructor() LinkedPoolIntegrationTest(AVAX_ENV_RPC, AVAX_BLOCK_NUMBER) {}

    function afterBlockchainForked() public override {
        uniswapV3SR02Module = new UniswapV3SR02Module(UNI_V3_SWAP_ROUTER_02, UNI_V3_STATIC_QUOTER);
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
            pool: UNI_V3_USDC_POOL,
            poolModule: address(uniswapV3SR02Module)
        });
    }
}
