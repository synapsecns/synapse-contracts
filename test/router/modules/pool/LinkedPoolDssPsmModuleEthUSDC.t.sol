// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {LinkedPoolIntegrationTest} from "./LinkedPoolIntegration.t.sol";

import {DssPsmModule} from "../../../../contracts/router/modules/pool/dss/DssPsmModule.sol";

contract LinkedPoolDssPsmModuleEthUSDCTestFork is LinkedPoolIntegrationTest {
    string private constant ETH_ENV_RPC = "ETHEREUM_API";
    // 2023-07-24
    uint256 public constant ETH_BLOCK_NUMBER = 17763746;

    // DSS PSM on Ethereum mainnet
    address public constant DSS_PSM = 0x89B78CfA322F6C5dE0aBcEecab66Aee45393cC5A;

    // USDC/DAI/USDT DefaultPool on Ethereum
    address public constant NUSD_POOL = 0x1116898DdA4015eD8dDefb84b6e8Bc24528Af2d8;

    // Native USDC on Ethereum mainnet
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    // Native DAI on Ethereum mainnet
    address public constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    // Native USDT on Ethereum mainnet
    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    DssPsmModule public dssPsmModule;

    constructor() LinkedPoolIntegrationTest(ETH_ENV_RPC, ETH_BLOCK_NUMBER) {}

    function afterBlockchainForked() public override {
        dssPsmModule = new DssPsmModule();
    }

    function addExpectedTokens() public override {
        // Expected order of tokens:
        // 0: DAI
        // 1: USDC
        addExpectedToken(DAI, "DAI");
        addExpectedToken(USDC, "USDC");
    }

    // TODO: add more pools?
    function addPools() public override {
        addPool({poolName: "DAI/USDC", nodeIndex: 0, pool: DSS_PSM, poolModule: address(dssPsmModule)});
    }
}
