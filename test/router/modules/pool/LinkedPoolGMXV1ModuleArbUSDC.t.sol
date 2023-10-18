// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {LinkedPoolIntegrationTest} from "./LinkedPoolIntegration.sol";

import {GMXV1StableArbitrumModule} from "../../../../contracts/router/modules/pool/gmx/GMXV1StableArbitrumModule.sol";

contract LinkedPoolGMXV1ModuleArbUSDCTestFork is LinkedPoolIntegrationTest {
    string private constant ARB_ENV_RPC = "ARBITRUM_API";
    // 2023-07-28
    uint256 public constant ARB_BLOCK_NUMBER = 115816525;

    // GMX V1 vault pool on Arbitrum
    address public constant GMX_V1_VAULT = 0x489ee077994B6658eAfA855C308275EAd8097C4A;

    // GMX V1 router on Arbitrum
    address public constant GMX_V1_ROUTER = 0xaBBc5F99639c9B6bCb58544ddf04EFA6802F4064;

    // GMX V1 reader on Arbitrum
    address public constant GMX_V1_READER = 0x22199a49A999c351eF7927602CFB187ec3cae489;

    // nUSD/USDC.e/USDT DefaultPool on Arbitrum
    address public constant NUSD_POOL = 0x9Dd329F5411466d9e0C488fF72519CA9fEf0cb40;

    // nUSD on Arbitrum
    address public constant NUSD = 0x2913E812Cf0dcCA30FB28E6Cac3d2DCFF4497688;

    // Native WBTC on Arbitrum
    address public constant WBTC = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;
    // Native WETH on Arbitrum
    address public constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    // Bridged USDC (USDC.e) on Arbitrum
    address public constant USDC_E = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
    // LINK on Arbitrum
    address public constant LINK = 0xf97f4df75117a78c1A5a0DBb814Af92458539FB4;
    // UNI on Arbitrum
    address public constant UNI = 0xFa7F8980b0f1E64A2062791cc3b0871572f1F7f0;
    // Native USDT on Arbitrum
    address public constant USDT = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
    // MIM on Arbitrum
    address public constant MIM = 0xFEa7a6a0B346362BF88A9e4A88416B77a57D6c2A;
    // FRAX on Arbitrum
    address public constant FRAX = 0x17FC002b466eEc40DaE837Fc4bE5c67993ddBd6F;
    // DAI on Arbitrum
    address public constant DAI = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;
    // Native USDC on Arbitrum
    address public constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

    GMXV1StableArbitrumModule public gmxV1Module;

    constructor() LinkedPoolIntegrationTest(ARB_ENV_RPC, ARB_BLOCK_NUMBER) {}

    function afterBlockchainForked() public override {
        gmxV1Module = new GMXV1StableArbitrumModule(GMX_V1_ROUTER, GMX_V1_READER);
    }

    function addExpectedTokens() public override {
        // Expected order of tokens:
        // 0: nUSD
        // 1: USD.e
        // 2: USDT
        // 3: USDT
        // 4: FRAX
        // 5: DAI
        // 6: USDC
        addExpectedToken(NUSD, "nUSD");
        addExpectedToken(USDC_E, "USDC.e");
        addExpectedToken(USDT, "USDT");
        addExpectedToken(USDT, "USDT");
        addExpectedToken(FRAX, "FRAX");
        addExpectedToken(DAI, "DAI");
        addExpectedToken(USDC, "USDC");
    }

    function addPools() public override {
        addPool({poolName: "nUSD/USDC.e/USDT", nodeIndex: 0, pool: NUSD_POOL});
        addPool({poolName: "GMX", nodeIndex: 1, pool: GMX_V1_VAULT, poolModule: address(gmxV1Module)});
    }
}
