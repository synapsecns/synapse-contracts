// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {LinkedPoolIntegrationTest} from "./LinkedPoolIntegration.sol";

import {GMXV1StableAvalancheModule} from "../../../../contracts/router/modules/pool/gmx/GMXV1StableAvalancheModule.sol";

contract LinkedPoolGMXV1ModuleAvaxUSDCTestFork is LinkedPoolIntegrationTest {
    // 2023-09-05
    uint256 public constant AVAX_BLOCK_NUMBER = 34807165;

    // GMX V1 router on Avalanche
    address public constant GMX_V1_ROUTER = 0x5F719c2F1095F7B9fc68a68e35B51194f4b6abe8;

    // GMX V1 vault pool on Avalanche
    address public constant GMX_V1_VAULT = 0x9ab2De34A33fB459b538c43f251eB825645e8595;

    // GMX V1 reader on Avalanche
    address public constant GMX_V1_READER = 0x67b789D48c926006F5132BFCe4e976F0A7A63d5D;

    // nUSD/DAI.e/USDC.e/USDT.e DefaultPool on Avalanche
    address public constant NUSD_POOL = 0xED2a7edd7413021d440b09D654f3b87712abAB66;

    // nUSD on Avalanche
    address public constant NUSD = 0xCFc37A6AB183dd4aED08C204D1c2773c0b1BDf46;
    // Bridged DAI on Avalanche
    address public constant DAI_E = 0xd586E7F844cEa2F87f50152665BCbc2C279D8d70;
    // Bridged USDT on Avalanche
    address public constant USDT_E = 0xc7198437980c041c805A1EDcbA50c1Ce5db95118;
    // Native WAVAX on Avalanche
    address public constant WAVAX = 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7;
    // Bridged WBTC on Avalanche
    address public constant WBTC_E = 0x50b7545627a5162F82A992c33b87aDc75187B218;
    // Bridged WETH on Avalanche
    address public constant WETH_E = 0x49D5c2BdFfac6CE2BFdB6640F4F80f226bc10bAB;
    // MIM on Avalanche
    address public constant MIM = 0x130966628846BFd36ff31a822705796e8cb8C18D;
    // Bridged USDC on Avalance
    address public constant USDC_E = 0xA7D7079b0FEaD91F3e65f86E8915Cb59c1a4C664;
    // Native USDC on Avalanche
    address public constant USDC = 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E;
    // Bridged BTC on Avalanche
    address public constant BTC_B = 0x152b9d0FdC40C096757F570A51E494bd4b943E50;

    GMXV1StableAvalancheModule public gmxV1Module;

    constructor() LinkedPoolIntegrationTest("avalanche", "GMXV1StableAvalancheModule", AVAX_BLOCK_NUMBER) {}

    function deployModule() public override {
        gmxV1Module = new GMXV1StableAvalancheModule(GMX_V1_ROUTER, GMX_V1_READER);
    }

    function addExpectedTokens() public override {
        // Expected order of tokens:
        // 0: nUSD
        // 1: DAI.e
        // 2: USDC.e
        // 3: USDT.e
        // 4: USDC
        addExpectedToken(NUSD, "nUSD");
        addExpectedToken(DAI_E, "DAI.e");
        addExpectedToken(USDC_E, "USDC.e");
        addExpectedToken(USDT_E, "USDT.e");
        addExpectedToken(USDC, "USDC");
    }

    function addPools() public override {
        addPool({poolName: "nUSD/DAI.e/USDC.e/USDT.e", nodeIndex: 0, pool: NUSD_POOL});
        addPool({poolName: "GMX", nodeIndex: 2, pool: GMX_V1_VAULT, poolModule: address(gmxV1Module)});
    }
}
