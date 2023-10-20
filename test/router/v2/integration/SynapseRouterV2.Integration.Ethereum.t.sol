// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Action, ActionLib, BridgeToken, DefaultParams, DestRequest, LimitedToken, SwapQuery} from "../../../../contracts/router/libs/Structs.sol";
import {UniversalTokenLib} from "../../../../contracts/router/libs/UniversalToken.sol";
import {IBridgeModule} from "../../../../contracts/router/interfaces/IBridgeModule.sol";

import {SynapseRouterV2IntegrationTest} from "./SynapseRouterV2.Integration.sol";
import {SynapseRouterV2BridgeUtils} from "./SynapseRouterV2.BridgeUtils.sol";
import {SynapseRouterV2CCTPUtils} from "./SynapseRouterV2.CCTPUtils.sol";

import {console} from "forge-std/Test.sol";

contract SynapseRouterV2EthereumIntegrationTestFork is
    SynapseRouterV2IntegrationTest,
    SynapseRouterV2BridgeUtils,
    SynapseRouterV2CCTPUtils
{
    uint256 public constant ETH_BLOCK_NUMBER = 18392588; // 2023-10-20

    address private constant ETH_SWAP_QUOTER = 0x5682dC851C33adb48F6958a963A5d3Aa31F6f184;
    address private constant ETH_SYN_ROUTER_V1 = 0x7E7A0e201FD38d3ADAA9523Da6C109a07118C96a;
    address private constant ETH_SYN_BRIDGE = 0x2796317b0fF8538F253012862c06787Adfb8cEb6;
    address private constant ETH_SYN_CCTP = 0xfB2Bfc368a7edfD51aa2cbEC513ad50edEa74E84;

    // bridge tokens
    address private constant NUSD = 0x1B84765dE8B7566e4cEAF4D0fD3c5aF52D3DdE4F;
    address private constant SYN = 0x0f2D719407FdBeFF09D87557AbB7232601FD9F29;
    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address private constant HIGH = 0x71Ab77b7dbB4fa7e017BC15090b2163221420282;
    address private constant WSOHM = 0xCa76543Cf381ebBB277bE79574059e32108e3E65;
    address private constant DOG = 0xBAac2B4491727D78D2b78815144570b9f2Fe8899;
    address private constant FRAX = 0x853d955aCEf822Db058eb8505911ED77F175b99e;
    address private constant GOHM = 0x0ab87046fBb341D058F17CBC4c1133F25a20a52f;
    address private constant UST = 0x0261018Aa50E28133C1aE7a29ebdf9Bd21b878Cb;
    address private constant NEWO = 0x98585dFc8d9e7D48F0b1aE47ce33332CF4237D96;
    address private constant PEPE = 0x6982508145454Ce325dDbE47a25d4ec3d2311933;
    address private constant SDT = 0x73968b9a57c6E53d41345FD57a6E6ae27d6CDB2F;
    address private constant VSTA = 0xA8d7F5e7C78ed0Fa097Cc5Ec66C1DC3104c9bbeb;
    address private constant SFI = 0xb753428af26E81097e7fD17f40c88aaA3E04902c;
    address private constant H2O = 0x0642026E7f0B6cCaC5925b4E7Fa61384250e1701;
    address private constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address private constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address private constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address private constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address private constant AGEUR = 0x1a7e4e63778B4f12a199C062f3eFdD288afCBce8;
    address private constant LINK = 0x514910771AF9Ca656af840dff83E8264EcF986CA;
    address private constant UNIDX = 0xf0655DcEE37E5C0b70Fffd70D85f88F8eDf0AfF6;

    constructor() SynapseRouterV2IntegrationTest("mainnet", ETH_BLOCK_NUMBER, ETH_SWAP_QUOTER) {}

    function afterBlockchainForked() public virtual override {
        synapseLocalBridgeConfig = ETH_SYN_ROUTER_V1;
        synapseBridge = ETH_SYN_BRIDGE;
        synapseCCTP = ETH_SYN_CCTP;
    }

    function addExpectedTokens() public virtual override {
        addExpectedToken(NUSD, "NUSD");
        addExpectedToken(DAI, "DAI");
        addExpectedToken(USDC, "USDC");
        addExpectedToken(USDT, "USDT");
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

    function addExpectedBridgeTokens() public virtual override {
        // add synapse bridge module bridge tokens
        address[] memory originTokensBridge = new address[](4);
        originTokensBridge[0] = NUSD;
        originTokensBridge[1] = DAI;
        originTokensBridge[2] = USDC;
        originTokensBridge[3] = USDT;

        address[] memory destinationTokensBridge = new address[](4);
        destinationTokensBridge[0] = NUSD;
        destinationTokensBridge[1] = DAI;
        destinationTokensBridge[2] = USDC;
        destinationTokensBridge[3] = USDT;

        addExpectedBridgeToken(BridgeToken({symbol: "nUSD", token: NUSD}), originTokensBridge, destinationTokensBridge);

        // add synapse cctp module bridge tokens
        address[] memory originTokensCCTP = new address[](4);
        originTokensCCTP[0] = USDC;
        originTokensCCTP[1] = NUSD;
        originTokensCCTP[2] = DAI;
        originTokensCCTP[3] = USDT;

        address[] memory destinationTokensCCTP = new address[](4);
        destinationTokensCCTP[0] = USDC;
        destinationTokensCCTP[1] = NUSD;
        destinationTokensCCTP[2] = DAI;
        destinationTokensCCTP[3] = USDT;

        addExpectedBridgeToken(BridgeToken({symbol: "USDC", token: USDC}), originTokensCCTP, destinationTokensCCTP);
    }

    function testGetBridgeTokens() public {
        BridgeToken[] memory bridgeTokens = new BridgeToken[](23);
        bridgeTokens[0] = BridgeToken({token: NUSD, symbol: "nUSD"});
        bridgeTokens[1] = BridgeToken({token: SYN, symbol: "SYN"});
        bridgeTokens[2] = BridgeToken({token: WETH, symbol: "nETH"});
        bridgeTokens[3] = BridgeToken({token: HIGH, symbol: "HIGH"});
        bridgeTokens[4] = BridgeToken({token: WSOHM, symbol: "wsOHM"});
        bridgeTokens[5] = BridgeToken({token: DOG, symbol: "DOG"});
        bridgeTokens[6] = BridgeToken({token: FRAX, symbol: "synFRAX"});
        bridgeTokens[7] = BridgeToken({token: GOHM, symbol: "gOHM"});
        bridgeTokens[8] = BridgeToken({token: UST, symbol: "UST"});
        bridgeTokens[9] = BridgeToken({token: NEWO, symbol: "NEWO"});
        bridgeTokens[10] = BridgeToken({token: PEPE, symbol: "PEPE"});
        bridgeTokens[11] = BridgeToken({token: SDT, symbol: "SDT"});
        bridgeTokens[12] = BridgeToken({token: VSTA, symbol: "VSTA"});
        bridgeTokens[13] = BridgeToken({token: SFI, symbol: "SFI"});
        bridgeTokens[14] = BridgeToken({token: H2O, symbol: "H2O"});
        bridgeTokens[15] = BridgeToken({token: WBTC, symbol: "WBTC"});
        bridgeTokens[16] = BridgeToken({token: USDC, symbol: "USDC"});
        bridgeTokens[17] = BridgeToken({token: USDT, symbol: "USDT"});
        bridgeTokens[18] = BridgeToken({token: DAI, symbol: "DAI"});
        bridgeTokens[19] = BridgeToken({token: AGEUR, symbol: "agEUR"});
        bridgeTokens[20] = BridgeToken({token: LINK, symbol: "LINK"});
        bridgeTokens[21] = BridgeToken({token: UNIDX, symbol: "UNIDX"});
        bridgeTokens[22] = BridgeToken({token: USDC, symbol: "CCTP.USDC"});
        checkBridgeTokenArrays(router.getBridgeTokens(), bridgeTokens);
    }

    function testGetSupportedTokens() public {
        address[] memory supportedTokens = new address[](23);
        supportedTokens[0] = DAI;
        supportedTokens[1] = USDC;
        supportedTokens[2] = USDT;
        supportedTokens[3] = NUSD;
        supportedTokens[4] = SYN;
        supportedTokens[5] = WETH;
        supportedTokens[6] = HIGH;
        supportedTokens[7] = WSOHM;
        supportedTokens[8] = DOG;
        supportedTokens[9] = FRAX;
        supportedTokens[10] = GOHM;
        supportedTokens[11] = UST;
        supportedTokens[12] = NEWO;
        supportedTokens[13] = PEPE;
        supportedTokens[14] = SDT;
        supportedTokens[15] = VSTA;
        supportedTokens[16] = SFI;
        supportedTokens[17] = H2O;
        supportedTokens[18] = WBTC;
        supportedTokens[19] = AGEUR;
        supportedTokens[20] = LINK;
        supportedTokens[21] = UNIDX;
        supportedTokens[22] = UniversalTokenLib.ETH_ADDRESS;
        checkAddressArrays(router.getSupportedTokens(), supportedTokens);
    }
}
