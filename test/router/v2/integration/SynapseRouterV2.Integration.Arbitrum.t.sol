// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {BridgeToken, SwapQuery} from "../../../../contracts/router/libs/Structs.sol";

import {SynapseRouterV2IntegrationTest} from "./SynapseRouterV2.Integration.t.sol";
import {SynapseRouterV2BridgeUtils} from "./SynapseRouterV2.BridgeUtils.t.sol";
import {SynapseRouterV2CCTPUtils} from "./SynapseRouterV2.CCTPUtils.t.sol";

contract SynapseRouterV2ArbitrumIntegrationTest is
    SynapseRouterV2IntegrationTest,
    SynapseRouterV2BridgeUtils,
    SynapseRouterV2CCTPUtils
{
    string private constant ARB_ENV_RPC = "ARBITRUM_API";
    uint256 public constant ARB_BLOCK_NUMBER = 136866865; // 2023-10-02

    address private constant ARB_SWAP_QUOTER = 0xE402cC7826dD835FCe5E3cFb61D56703fEbc2642;
    address private constant ARB_SYN_ROUTER_V1 = 0x7E7A0e201FD38d3ADAA9523Da6C109a07118C96a;
    address private constant ARB_SYN_BRIDGE = 0x6F4e8eBa4D337f874Ab57478AcC2Cb5BACdc19c9;
    address private constant ARB_SYN_CCTP = 0xfB2Bfc368a7edfD51aa2cbEC513ad50edEa74E84;

    // bridge tokens
    address private constant NUSD = 0x2913E812Cf0dcCA30FB28E6Cac3d2DCFF4497688;
    address private constant SYN = 0x080F6AEd32Fc474DD5717105Dba5ea57268F46eb;
    address private constant NETH = 0x3ea9B0ab55F34Fb188824Ee288CeaEfC63cf908e;
    address private constant WSOHM = 0x30bD4e574a15994B35EF9C7a5bc29002F1224821;
    address private constant GOHM = 0x8D9bA570D6cb60C7e3e0F31343Efe75AB8E65FB1;
    address private constant GMX = 0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a;
    address private constant USTC = 0x13780E6d5696DD91454F6d3BbC2616687fEa43d0;
    address private constant NEWO = 0x0877154a755B24D499B8e2bD7ecD54d3c92BA433;
    address private constant SDT = 0x087d18A77465c34CDFd3a081a2504b7E86CE4EF8;
    address private constant VSTA = 0xa684cd057951541187f288294a1e1C2646aA2d24;
    address private constant H20 = 0xD1c6f989e9552DB523aBAE2378227fBb059a3976;
    address private constant L2DAO = 0x2CaB3abfC1670D1a452dF502e216a66883cDf079;
    address private constant AGEUR = 0x16BFc5fe024980124bEf51d1D792dC539d1B5Bf0;
    address private constant PLS = 0x51318B7D00db7ACc4026C88c3952B66278B6A67F;
    address private constant UNIDX = 0x5429706887FCb58a595677B73E9B0441C25d993D;
    address private constant PEPE = 0xA54B8e178A49F8e5405A4d44Bb31F496e5564A05;

    // supported tokens (for adapter swaps)
    address private constant USDC_E = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
    address private constant USDT = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
    address private constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

    constructor() SynapseRouterV2IntegrationTest(ARB_ENV_RPC, ARB_BLOCK_NUMBER, ARB_SWAP_QUOTER) {}

    function afterBlockchainForked() public virtual override {
        synapseLocalBridgeConfig = ARB_SYN_ROUTER_V1;
        synapseBridge = ARB_SYN_BRIDGE;
        synapseCCTP = ARB_SYN_CCTP;
    }

    function addExpectedTokens() public virtual override {
        addExpectedToken(NUSD, "NUSD");
        addExpectedToken(USDC_E, "USDC.e");
        addExpectedToken(USDT, "USDT");
        addExpectedToken(USDC, "USDC");
    }

    // testing CCTP, synapse bridge
    function addExpectedModules() public virtual override {
        deploySynapseBridgeModule();
        addExpectedModule(synapseBridgeModule, "SynapseBridgeModule");

        deploySynapseCCTPModule();
        addExpectedModule(synapseCCTPModule, "SynapseCCTPModule");
    }

    function addExpectedBridgeTokens() public virtual override {
        // add synapse bridge module bridge tokens
        address[] memory originTokensBridge = new address[](2);
        originTokensBridge[0] = USDC_E;
        originTokensBridge[1] = USDT;

        address[] memory destinationTokensBridge = new address[](2);
        destinationTokensBridge[0] = USDC_E;
        destinationTokensBridge[1] = USDT;

        addExpectedBridgeToken(BridgeToken({symbol: "NUSD", token: NUSD}), originTokensBridge, destinationTokensBridge);

        // add synapse cctp module bridge tokens
        address[] memory originTokensCCTP = new address[](1);
        originTokensCCTP[0] = USDC;

        address[] memory destinationTokensCCTP = new address[](1);
        destinationTokensCCTP[0] = USDC;

        addExpectedBridgeToken(
            BridgeToken({symbol: "CCTP.USDC", token: USDC}),
            originTokensCCTP,
            destinationTokensCCTP
        );
    }

    /// TODO: Tests that must be implemented
    function testGetBridgeTokens() public virtual override {}

    function testGetSupportedTokens() public virtual override {}

    function testGetOriginBridgeTokens() public virtual override {}

    function testGetDestinationBridgeTokens() public virtual override {}

    function testGetOriginAmountOut() public virtual override {}

    function testGetDestinationAmountOut() public virtual override {}

    function testBridges() public virtual override {}

    function testSwaps() public virtual override {}
}
