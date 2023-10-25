// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {LinkedPoolIntegrationTest} from "./LinkedPoolIntegration.sol";

import {CurveV1Module} from "../../../../contracts/router/modules/pool/curve/CurveV1Module.sol";
import {UniswapV3Module} from "../../../../contracts/router/modules/pool/uniswap/UniswapV3Module.sol";

contract LinkedPoolCurveV1UniswapV3ModuleBaseTestFork is LinkedPoolIntegrationTest {
    // 2023-10-25
    uint256 public constant BASE_BLOCK_NUMBER = 5729000;

    // Curve V1 USDC/USDcB/axlUSDC/crvUSD pool (4pool) on Base
    address public constant CURVE_V1_4POOL = 0xf6C5F01C7F3148891ad0e19DF78743D31E390D1f;

    // Uniswap V3 Router on Base
    address public constant UNI_V3_ROUTER = 0xacB8Ac8d5597A97267e16Dae214eE3F5dBd551BB;
    // Eden's Uniswap V3 Static Quoter on Base
    address public constant UNI_V3_STATIC_QUOTER = 0xbAD189BDF6a05FDaFA33CA917d094A64954093c4;
    // Uniswap V3 USDC/USDC.e pool on Base
    address public constant UNI_V3_USDC_POOL = 0x88492051E18a65FE00241A93699A6082aE95c828;

    // Native USDC on Base
    address public constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    // Base-Bridged USDC on Base
    address public constant USD_B_C = 0xd9aAEc86B65D86f6A7B5B1b0c42FFA531710b6CA;
    // Axelar-wrapped USDC on Base
    address public constant AXL_USDC = 0xEB466342C4d449BC9f53A865D5Cb90586f405215;
    // Base-Bridged crvUSD on Base
    address public constant CRV_USD = 0x417Ac0e078398C154EdFadD9Ef675d30Be60Af93;

    CurveV1Module public curveV1Module;
    UniswapV3Module public uniswapV3Module;

    constructor() LinkedPoolIntegrationTest("base", "CurveV1Module", BASE_BLOCK_NUMBER) {}

    function deployModule() public override {
        curveV1Module = new CurveV1Module();
        uniswapV3Module = new UniswapV3Module(UNI_V3_ROUTER, UNI_V3_STATIC_QUOTER);
    }

    function addExpectedTokens() public override {
        // Expected order of tokens:
        // 0: USDC
        // 1: USD_B_C
        // 2: AXL_USDC
        // 3: CRV_USD
        // 4: USD_B_C
        addExpectedToken(USDC, "USDC");
        addExpectedToken(USD_B_C, "USDbC");
        addExpectedToken(AXL_USDC, "axlUSDC");
        addExpectedToken(CRV_USD, "crvUSD");
        addExpectedToken(USD_B_C, "USDbC");
    }

    function addPools() public override {
        addPool({
            poolName: "USDC/USDbC/axlUSDC/crvUSD",
            nodeIndex: 0,
            pool: CURVE_V1_4POOL,
            poolModule: address(curveV1Module)
        });
        addPool({poolName: "USDC/USDbC", nodeIndex: 0, pool: UNI_V3_USDC_POOL, poolModule: address(uniswapV3Module)});
    }
}
