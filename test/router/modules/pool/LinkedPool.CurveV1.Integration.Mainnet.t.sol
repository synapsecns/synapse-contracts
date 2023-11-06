// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {LinkedPoolIntegrationTest} from "./LinkedPoolIntegration.sol";

import {CurveV1Module} from "../../../../contracts/router/modules/pool/curve/CurveV1Module.sol";

contract LinkedPoolCurveV1ModuleEthTestFork is LinkedPoolIntegrationTest {
    // 2023-11-03
    uint256 public constant ETH_BLOCK_NUMBER = 18490000;

    /// @dev Main Curve 3pool on Ethereum is using old interface which does not return the amount
    /// of swapped tokens in exchange() function, and therefore needs a modified module.

    // Curve V1 USDC/crvUSD pool on Ethereum
    address public constant CURVE_V1_CRV_USD_POOL = 0x4DEcE678ceceb27446b35C672dC7d61F30bAD69E;
    // Curve V1 FRAX/USDC pool on Ethereum
    address public constant CURVE_V1_FRAX_POOL = 0xDcEF968d416a41Cdac0ED8702fAC8128A64241A2;

    // Native USDC on Ethereum
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    // Native FRAX on Ethereum
    address public constant FRAX = 0x853d955aCEf822Db058eb8505911ED77F175b99e;
    // Native crvUSD on Ethereum
    address public constant CRV_USD = 0xf939E0A03FB07F59A73314E73794Be0E57ac1b4E;

    CurveV1Module public curveV1Module;

    constructor() LinkedPoolIntegrationTest("mainnet", "CurveV1Module", ETH_BLOCK_NUMBER) {}

    function deployModule() public override {
        curveV1Module = new CurveV1Module();
    }

    function addExpectedTokens() public override {
        // Expected order of tokens:
        // 0: USDC
        // 1: FRAX
        // 2: crvUSD
        addExpectedToken(USDC, "USDC");
        addExpectedToken(FRAX, "FRAX");
        addExpectedToken(CRV_USD, "crvUSD");
    }

    function addPools() public override {
        addPool({poolName: "FRAX/USDC", nodeIndex: 0, pool: CURVE_V1_FRAX_POOL, poolModule: address(curveV1Module)});
        addPool({
            poolName: "USDC/crvUSD",
            nodeIndex: 0,
            pool: CURVE_V1_CRV_USD_POOL,
            poolModule: address(curveV1Module)
        });
    }
}
