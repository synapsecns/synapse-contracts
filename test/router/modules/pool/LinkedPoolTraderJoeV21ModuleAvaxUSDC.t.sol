// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {LinkedPoolIntegrationTest} from "./LinkedPoolIntegration.sol";

import {TraderJoeV21Module} from "../../../../contracts/router/modules/pool/traderjoe/TraderJoeV21Module.sol";

contract LinkedPoolTraderJoeV21ModuleAvaxUSDCTestFork is LinkedPoolIntegrationTest {
    string private constant AVAX_ENV_RPC = "AVALANCHE_API";
    // 2023-09-05
    uint256 public constant AVAX_BLOCK_NUMBER = 34807165;

    // Trader Joe V2.1 Router on Avalanche
    address public constant LB_ROUTER = 0xb4315e873dBcf96Ffd0acd8EA43f689D8c20fB30;

    // Trader Joe V2.1 USDC.e/USDC Pool on Avalanche
    address public constant LB_POOL = 0x7c13D4C3E9DFa683E7a5792a9FF20CB5FD22B0c0;

    // nUSD/DAI.e/USDC.e/USDT.e DefaultPool on Avalanche
    address public constant NUSD_POOL = 0xED2a7edd7413021d440b09D654f3b87712abAB66;

    // nUSD on Avalanche
    address public constant NUSD = 0xCFc37A6AB183dd4aED08C204D1c2773c0b1BDf46;
    // Bridged DAI on Avalanche
    address public constant DAI_E = 0xd586E7F844cEa2F87f50152665BCbc2C279D8d70;
    // Bridged USDC on Avalance
    address public constant USDC_E = 0xA7D7079b0FEaD91F3e65f86E8915Cb59c1a4C664;
    // Bridged USDT on Avalanche
    address public constant USDT_E = 0xc7198437980c041c805A1EDcbA50c1Ce5db95118;
    // Native USDC on Avalanche
    address public constant USDC = 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E;

    TraderJoeV21Module public traderJoeModule;

    constructor() LinkedPoolIntegrationTest(AVAX_ENV_RPC, AVAX_BLOCK_NUMBER) {}

    function afterBlockchainForked() public override {
        traderJoeModule = new TraderJoeV21Module(LB_ROUTER);
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
        addPool({poolName: "Joe USDC.e/USDC", nodeIndex: 2, pool: LB_POOL, poolModule: address(traderJoeModule)});
    }
}
