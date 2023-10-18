// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {LinkedPoolIntegrationTest} from "./LinkedPoolIntegration.sol";

import {VelodromeV2Module} from "../../../../contracts/router/modules/pool/velodrome/VelodromeV2Module.sol";

contract LinkedPoolVelodromeV2ModuleArbUSDCTestFork is LinkedPoolIntegrationTest {
    string private constant OPT_ENV_RPC = "OPTIMISM_API";
    // 2023-07-11
    uint256 public constant OPT_BLOCK_NUMBER = 106753037;

    // Velodrome V2 USDC/USDT pool on Optimism
    address public constant VEL_V2_USDCUSDT_POOL = 0x2B47C794c3789f499D8A54Ec12f949EeCCE8bA16;

    // Velodrome V2 Router on Optimism
    address public constant VEL_V2_ROUTER = 0xa062aE8A9c5e11aaA026fc2670B0D65cCc8B2858;

    // nUSD/USDC DefaultPool on Optimism
    address public constant NUSD_POOL = 0xF44938b0125A6662f9536281aD2CD6c499F22004;

    // Native USDC on Optimism
    address public constant USDC = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607;
    // nUSD on Optimism
    address public constant NUSD = 0x67C10C397dD0Ba417329543c1a40eb48AAa7cd00;
    // Native USDT on Optimism
    address public constant USDT = 0x94b008aA00579c1307B0EF2c499aD98a8ce58e58;

    VelodromeV2Module public velodromeV2Module;

    constructor() LinkedPoolIntegrationTest(OPT_ENV_RPC, OPT_BLOCK_NUMBER) {}

    function afterBlockchainForked() public override {
        velodromeV2Module = new VelodromeV2Module(VEL_V2_ROUTER);
    }

    function addExpectedTokens() public override {
        // Expected order of tokens:
        // 0: nUSD
        // 1: USDC
        // 2: USDT
        addExpectedToken(NUSD, "nUSD");
        addExpectedToken(USDC, "USDC");
        addExpectedToken(USDT, "USDT");
    }

    function addPools() public override {
        addPool({poolName: "nUSD/USDC", nodeIndex: 0, pool: NUSD_POOL});
        addPool({
            poolName: "USDC/USDT",
            nodeIndex: 1,
            pool: VEL_V2_USDCUSDT_POOL,
            poolModule: address(velodromeV2Module)
        });
    }
}
