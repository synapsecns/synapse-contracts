// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {LinkedPoolIntegrationTest} from "./LinkedPoolIntegration.t.sol";

import {BalancerV2Module} from "../../../../contracts/router/modules/pool/balancer/BalancerV2Module.sol";

contract LinkedPoolBalancerV2ModuleArbUSDCTestFork is LinkedPoolIntegrationTest {
    string private constant ARB_ENV_RPC = "ARBITRUM_API";
    // 2023-07-03
    uint256 public constant ARB_BLOCK_NUMBER = 107596120;

    // Balancer V2 Vault on Arbitrum
    address public constant BALANCER_V2_VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;

    // Balancer V2 DAI/USDT/USD.e pool on Arbitrum
    address public constant BALANCER_V2_USDC_POOL = 0x1533A3278f3F9141d5F820A184EA4B017fce2382;

    // nUSD/USDC.e/USDT DefaultPool on Arbitrum
    address public constant NUSD_POOL = 0x9Dd329F5411466d9e0C488fF72519CA9fEf0cb40;

    // Bridged USDC (USDC.e) on Arbitrum
    address public constant USDC_E = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
    // nUSD on Arbitrum
    address public constant NUSD = 0x2913E812Cf0dcCA30FB28E6Cac3d2DCFF4497688;
    // USDT on Arbitrum
    address public constant USDT = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
    // DAI on Arbitrum
    address public constant DAI = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;

    BalancerV2Module public balancerV2Module;

    constructor() LinkedPoolIntegrationTest(ARB_ENV_RPC, ARB_BLOCK_NUMBER) {}

    function afterBlockchainForked() public override {
        balancerV2Module = new BalancerV2Module(BALANCER_V2_VAULT);
    }

    function addExpectedTokens() public override {
        // Expected order of tokens:
        // 0: DAI
        // 1: USDT
        // 2: USDC.e
        // 3: nUSD
        // 4: USDT
        addExpectedToken(DAI, "DAI");
        addExpectedToken(USDT, "USDT");
        addExpectedToken(USDC_E, "USDC.e");
        addExpectedToken(NUSD, "nUSD");

        // Q: why do I have to add USDC_E again as a node?
        addExpectedToken(USDC_E, "USDC.e");
    }

    function addPools() public override {
        addPool({
            poolName: "DAI/USDT/USDC.e",
            nodeIndex: 0,
            pool: BALANCER_V2_USDC_POOL,
            poolModule: address(balancerV2Module)
        });
        addPool({poolName: "nUSD/USDC.e/USDT", nodeIndex: 1, pool: NUSD_POOL});
    }
}
