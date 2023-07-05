// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {LinkedPoolIntegrationTest} from "./LinkedPoolIntegration.t.sol";

import {CurveV1Module} from "../../../../contracts/router/modules/pool/curve/CurveV1Module.sol";

contract LinkedPoolCurveV1ModuleArbUSDCTestFork is LinkedPoolIntegrationTest {
    string private constant ARB_ENV_RPC = "ARBITRUM_API";
    // 2023-07-03
    uint256 public constant ARB_BLOCK_NUMBER = 107596120;

    // Curve V1 USDC/USDT pool (2pool) on Arbitrum
    address public constant CURVE_V1_2POOL = 0x7f90122BF0700F9E7e1F688fe926940E8839F353;

    // nUSD/USDC.e/USDT DefaultPool on Arbitrum
    address public constant NUSD_POOL = 0x9Dd329F5411466d9e0C488fF72519CA9fEf0cb40;

    // Bridged USDC (USDC.e) on Arbitrum
    address public constant USDC_E = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
    // nUSD on Arbitrum
    address public constant NUSD = 0x2913E812Cf0dcCA30FB28E6Cac3d2DCFF4497688;
    // USDT on Arbitrum
    address public constant USDT = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;

    CurveV1Module public curveV1Module;

    constructor() LinkedPoolIntegrationTest(ARB_ENV_RPC, ARB_BLOCK_NUMBER) {}

    function afterBlockchainForked() public override {
        curveV1Module = new CurveV1Module();
    }

    function addExpectedTokens() public override {
        // Expected order of tokens:
        // 0: USDC.e
        // 1: USDT
        // 2: nUSD
        addExpectedToken(USDC_E, "USDC.e");
        addExpectedToken(USDT, "USDT");
        addExpectedToken(NUSD, "nUSD");
    }

    function addPools() public override {
        addPool({poolName: "USDC.e/USDT", nodeIndex: 0, pool: CURVE_V1_2POOL, poolModule: address(curveV1Module)});
        addPool({poolName: "nUSD/USDC.e/USDT", nodeIndex: 1, pool: NUSD_POOL});
    }
}
