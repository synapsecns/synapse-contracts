// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Action, ActionLib, BridgeToken, DefaultParams, DestRequest, LimitedToken, SwapQuery} from "../../../../contracts/router/libs/Structs.sol";
import {UniversalTokenLib} from "../../../../contracts/router/libs/UniversalToken.sol";
import {IBridgeModule} from "../../../../contracts/router/interfaces/IBridgeModule.sol";

import {SynapseRouterV2IntegrationTest} from "./SynapseRouterV2.Integration.sol";
import {SynapseRouterV2BridgeUtils} from "./SynapseRouterV2.BridgeUtils.sol";
import {SynapseRouterV2CCTPUtils} from "./SynapseRouterV2.CCTPUtils.sol";

import {console} from "forge-std/Test.sol";

contract SynapseRouterV2AvalancheIntegrationTestFork is
    SynapseRouterV2IntegrationTest,
    SynapseRouterV2BridgeUtils,
    SynapseRouterV2CCTPUtils
{
    uint256 public constant AVAX_BLOCK_NUMBER = 36998332; // 10-27-2023

    address private constant AVAX_SWAP_QUOTER = 0x40d9dDE17D776bF057083E156578d2443685851C;
    address private constant AVAX_SYN_ROUTER_V1 = 0x7E7A0e201FD38d3ADAA9523Da6C109a07118C96a;
    address private constant AVAX_SYN_BRIDGE = 0xC05e61d0E7a63D27546389B7aD62FdFf5A91aACE;
    address private constant AVAX_SYN_CCTP = 0xfB2Bfc368a7edfD51aa2cbEC513ad50edEa74E84;
    address private constant AVAX_STABLE_POOL = 0xED2a7edd7413021d440b09D654f3b87712abAB66;

    // bridge tokens
    address private constant NUSD = 0xCFc37A6AB183dd4aED08C204D1c2773c0b1BDf46;
    address private constant SYN = 0x1f1E7c893855525b303f99bDF5c3c05Be09ca251;
    address private constant NETH = 0x19E1ae0eE35c0404f835521146206595d37981ae;
    address private constant WSOHM = 0x240E332Cd26AaE10622B24160D23425A17256F5d;
    address private constant NFD = 0xf1293574EE43950E7a8c9F1005Ff097A9A713959;
    address private constant GOHM = 0x321E7092a180BB43555132ec53AaA65a5bF84251;
    address private constant WAVAX = 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7;
    address private constant GMX = 0x62edc0692BD897D2295872a9FFCac5425011c661;
    address private constant UST = 0xE97097dE8d6A17Be3c39d53AE63347706dCf8f43;
    address private constant NEWO = 0x4Bfc90322dD638F81F034517359BD447f8E0235a;
    address private constant BTC_B = 0x152b9d0FdC40C096757F570A51E494bd4b943E50;
    address private constant SDT = 0xCCBf7c451F81752F7d2237F2c18C371E6e089E69;
    address private constant JEWEL = 0x997Ddaa07d716995DE90577C123Db411584E5E46;
    address private constant SFI = 0xc2Bf0A1f7D8Da50D608bc96CF701110d4A438312;
    address private constant H2O = 0xC6b11a4Fd833d1117E9D312c02865647cd961107;

    // supported tokens (for adapter swaps)
    address private constant USDC_E = 0xA7D7079b0FEaD91F3e65f86E8915Cb59c1a4C664;
    address private constant DAI_E = 0xd586E7F844cEa2F87f50152665BCbc2C279D8d70;
    address private constant USDT_E = 0xc7198437980c041c805A1EDcbA50c1Ce5db95118;
    address private constant AVWETH = 0x53f7c5869a859F0AeC3D334ee8B4Cf01E3492f21;

    constructor() SynapseRouterV2IntegrationTest("avalanche", AVAX_BLOCK_NUMBER, AVAX_SWAP_QUOTER) {}

    function afterBlockchainForked() public virtual override {
        synapseLocalBridgeConfig = AVAX_SYN_ROUTER_V1;
        synapseBridge = AVAX_SYN_BRIDGE;
        synapseCCTP = AVAX_SYN_CCTP;
    }

    function addExpectedTokens() public virtual override {
        addExpectedToken(NUSD, "nUSD");
        addExpectedToken(USDC_E, "USDC.e");
        addExpectedToken(DAI_E, "DAI.e");
        addExpectedToken(USDT_E, "USDT.e");
        addExpectedToken(NETH, "nETH");
        addExpectedToken(AVWETH, "avWETH");
    }

    // testing CCTP, synapse bridge
    function addExpectedModules() public virtual override {
        // bridgeModules[0] = SynapseBridgeModule
        deploySynapseBridgeModule();
        addExpectedModule(synapseBridgeModule, "SynapseBridgeModule");

        // bridgeModules[1] = SynapseCCTPModule
        deploySynapseCCTPModule();
        addExpectedModule(synapseCCTPModule, "SynapseCCTPModule");
    }

    function addExpectedBridgeTokens() public virtual override {}
}
