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
    address private constant USDC = 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E;

    // supported tokens (for adapter swaps)
    address private constant USDC_E = 0xA7D7079b0FEaD91F3e65f86E8915Cb59c1a4C664;
    address private constant DAI_E = 0xd586E7F844cEa2F87f50152665BCbc2C279D8d70;
    address private constant USDT_E = 0xc7198437980c041c805A1EDcbA50c1Ce5db95118;
    address private constant WETH_E = 0x49D5c2BdFfac6CE2BFdB6640F4F80f226bc10bAB;
    address private constant USDT = 0x9702230A8Ea53601f5cD2dc00fDBc13d4dF4A8c7;
    address private constant GMX_WRAPPER = 0x20A9DC684B4d0407EF8C9A302BEAaA18ee15F656;

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
        addExpectedToken(USDC, "CCTP.USDC");
        addExpectedToken(USDT, "USDT");
        addExpectedToken(NETH, "nETH");
        addExpectedToken(WETH_E, "WETH.e");
        addExpectedToken(WAVAX, "WAVAX");
        addExpectedToken(GMX, "GMX");
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
        address[] memory originTokensBridgeStables = new address[](6);
        originTokensBridgeStables[0] = NUSD;
        originTokensBridgeStables[1] = DAI_E;
        originTokensBridgeStables[2] = USDC_E;
        originTokensBridgeStables[3] = USDT_E;
        originTokensBridgeStables[4] = USDC;
        originTokensBridgeStables[5] = USDT;

        address[] memory destinationTokensBridgeStables = new address[](4);
        destinationTokensBridgeStables[0] = NUSD;
        destinationTokensBridgeStables[1] = DAI_E;
        destinationTokensBridgeStables[2] = USDC_E;
        destinationTokensBridgeStables[3] = USDT_E;

        addExpectedBridgeToken(
            BridgeToken({symbol: "nUSD", token: NUSD}),
            originTokensBridgeStables,
            destinationTokensBridgeStables
        );

        // add synapse bridge module bridge tokens for ETH
        address[] memory originTokensBridgeETH = new address[](2);
        originTokensBridgeETH[0] = NETH;
        originTokensBridgeETH[1] = WETH_E;

        address[] memory destinationTokensBridgeETH = new address[](2);
        destinationTokensBridgeETH[0] = NETH;
        destinationTokensBridgeETH[1] = WETH_E;

        addExpectedBridgeToken(
            BridgeToken({symbol: "nETH", token: NETH}),
            originTokensBridgeETH,
            destinationTokensBridgeETH
        );

        // add synapse bridge module bridge tokens for WAVAX
        address[] memory originTokensBridgeWAVAX = new address[](2);
        originTokensBridgeWAVAX[0] = WAVAX;
        originTokensBridgeWAVAX[1] = UniversalTokenLib.ETH_ADDRESS;

        address[] memory destinationTokensBridgeWAVAX = new address[](2);
        destinationTokensBridgeWAVAX[0] = WAVAX;
        destinationTokensBridgeWAVAX[1] = UniversalTokenLib.ETH_ADDRESS;

        addExpectedBridgeToken(
            BridgeToken({symbol: "AVAX", token: WAVAX}),
            originTokensBridgeWAVAX,
            destinationTokensBridgeWAVAX
        );

        // add synapse bridge module bridge tokens for GMX
        address[] memory originTokensBridgeGMX = new address[](1);
        originTokensBridgeGMX[0] = GMX;

        address[] memory destinationTokensBridgeGMX = new address[](1);
        destinationTokensBridgeGMX[0] = GMX;

        addExpectedBridgeToken(
            BridgeToken({symbol: "GMX", token: GMX}),
            originTokensBridgeGMX,
            destinationTokensBridgeGMX
        );

        // add synapse cctp module bridge tokens
        address[] memory originTokensCCTP = new address[](6);
        originTokensCCTP[0] = USDC;
        originTokensCCTP[1] = NUSD;
        originTokensCCTP[2] = USDC_E;
        originTokensCCTP[3] = DAI_E;
        originTokensCCTP[4] = USDT_E;
        originTokensCCTP[5] = USDT;

        address[] memory destinationTokensCCTP = new address[](6);
        destinationTokensCCTP[0] = USDC;
        destinationTokensCCTP[1] = NUSD;
        destinationTokensCCTP[2] = USDC_E;
        destinationTokensCCTP[3] = DAI_E;
        destinationTokensCCTP[4] = USDT_E;
        destinationTokensCCTP[5] = USDT;

        addExpectedBridgeToken(
            BridgeToken({symbol: "CCTP.USDC", token: USDC}),
            originTokensCCTP,
            destinationTokensCCTP
        );
    }

    function testGetBridgeTokens() public {
        BridgeToken[] memory bridgeTokens = new BridgeToken[](16);
        bridgeTokens[0] = BridgeToken({token: NUSD, symbol: "nUSD"});
        bridgeTokens[1] = BridgeToken({token: SYN, symbol: "SYN"});
        bridgeTokens[2] = BridgeToken({token: NETH, symbol: "nETH"});
        bridgeTokens[3] = BridgeToken({token: WSOHM, symbol: "wsOHM"});
        bridgeTokens[4] = BridgeToken({token: NFD, symbol: "NFD"});
        bridgeTokens[5] = BridgeToken({token: GOHM, symbol: "gOHM"});
        bridgeTokens[6] = BridgeToken({token: WAVAX, symbol: "AVAX"});
        bridgeTokens[7] = BridgeToken({token: GMX, symbol: "GMX"});
        bridgeTokens[8] = BridgeToken({token: UST, symbol: "UST"});
        bridgeTokens[9] = BridgeToken({token: NEWO, symbol: "NEWO"});
        bridgeTokens[10] = BridgeToken({token: BTC_B, symbol: "BTCB"});
        bridgeTokens[11] = BridgeToken({token: SDT, symbol: "SDT"});
        bridgeTokens[12] = BridgeToken({token: JEWEL, symbol: "JEWEL"});
        bridgeTokens[13] = BridgeToken({token: SFI, symbol: "SFI"});
        bridgeTokens[14] = BridgeToken({token: H2O, symbol: "H2O"});
        bridgeTokens[15] = BridgeToken({token: USDC, symbol: "CCTP.USDC"});
        checkBridgeTokenArrays(router.getBridgeTokens(), bridgeTokens);
    }

    function testGetSupportedTokens() public {
        address[] memory supportedTokens = new address[](22);
        supportedTokens[0] = NUSD;
        supportedTokens[1] = DAI_E;
        supportedTokens[2] = USDC_E;
        supportedTokens[3] = USDT_E;
        supportedTokens[4] = NETH;
        supportedTokens[5] = WETH_E;
        supportedTokens[6] = USDC;
        supportedTokens[7] = USDT;
        supportedTokens[8] = SYN;
        supportedTokens[9] = WSOHM;
        supportedTokens[10] = NFD;
        supportedTokens[11] = GOHM;
        supportedTokens[12] = WAVAX;
        supportedTokens[13] = GMX;
        supportedTokens[14] = UST;
        supportedTokens[15] = NEWO;
        supportedTokens[16] = BTC_B;
        supportedTokens[17] = SDT;
        supportedTokens[18] = JEWEL;
        supportedTokens[19] = SFI;
        supportedTokens[20] = H2O;
        supportedTokens[21] = UniversalTokenLib.ETH_ADDRESS; // AVAX
        checkAddressArrays(router.getSupportedTokens(), supportedTokens);
    }

    function testGetOriginBridgeTokens() public {
        for (uint256 i = 0; i < expectedTokens.length; i++) {
            console.log("tokenIn %s: %s [%s]", i, expectedTokens[i], tokenNames[expectedTokens[i]]);
            checkBridgeTokenArrays(
                router.getOriginBridgeTokens(expectedTokens[i]),
                expectedOriginBridgeTokens[expectedTokens[i]]
            );
        }
    }

    function testGetDestinationBridgeTokens() public {
        for (uint256 i = 0; i < expectedTokens.length; i++) {
            console.log("tokenOut %s: %s [%s]", i, expectedTokens[i], tokenNames[expectedTokens[i]]);
            checkBridgeTokenArrays(
                router.getDestinationBridgeTokens(expectedTokens[i]),
                expectedDestinationBridgeTokens[expectedTokens[i]]
            );
        }
    }

    function testGetOriginAmountOut_inUSDCe_outNUSD() public {
        address tokenIn = USDC_E;
        string memory tokenSymbol = "nUSD";
        uint256 amountIn = getTestAmount(USDC_E);

        address pool = AVAX_STABLE_POOL;
        uint8 indexFrom = 2;
        uint8 indexTo = 0;
        uint256 amountOut = calculateSwap(pool, indexFrom, indexTo, amountIn);

        SwapQuery memory query = router.getOriginAmountOut(tokenIn, tokenSymbol, amountIn);
        assertEq(query.routerAdapter, address(router));
        assertEq(query.tokenOut, NUSD);
        assertEq(query.minAmountOut, amountOut);
        assertEq(query.deadline, type(uint256).max);
        assertEq(query.rawParams, getSwapParams(pool, indexFrom, indexTo));
    }

    function testGetOriginAmountOut_inNUSD_outNUSD() public {
        address tokenIn = NUSD;
        string memory tokenSymbol = "nUSD";
        uint256 amountIn = getTestAmount(NUSD);

        uint256 amountOut = amountIn;
        SwapQuery memory query = router.getOriginAmountOut(tokenIn, tokenSymbol, amountIn);
        assertEq(query.routerAdapter, address(0));
        assertEq(query.tokenOut, NUSD);
        assertEq(query.minAmountOut, amountOut);
        assertEq(query.deadline, type(uint256).max);
        assertEq(query.rawParams, bytes(""));
    }

    /// @dev UNI not supported so amount out should produce zero
    function testGetOriginAmountOut_inUSDCe_outUNI() public {
        address tokenIn = USDC_E;
        string memory tokenSymbol = "UNI";
        uint256 amountIn = getTestAmount(USDC_E);

        SwapQuery memory query = router.getOriginAmountOut(tokenIn, tokenSymbol, amountIn);
        assertEq(query.routerAdapter, address(0));
        assertEq(query.tokenOut, address(0));
        assertEq(query.minAmountOut, 0);
        assertEq(query.deadline, 0);
        assertEq(query.rawParams, bytes(""));
    }

    function testGetOriginAmountOut_inUSDCe_outUSDC() public {
        address tokenIn = USDC_E;
        string memory tokenSymbol = "CCTP.USDC";
        uint256 amountIn = 990000000000; // 990K USDC

        address pool = 0x9A2Dea7B81cfe3e0011D44D41c5c5142b8d9abdF; // LinkedPool
        uint8 indexFrom = 4;
        uint8 indexTo = 0;
        uint256 amountOut = calculateSwap(pool, indexFrom, indexTo, amountIn);

        SwapQuery memory query = router.getOriginAmountOut(tokenIn, tokenSymbol, amountIn);
        assertEq(query.routerAdapter, address(router));
        assertEq(query.tokenOut, USDC);
        assertEq(query.minAmountOut, amountOut);
        assertEq(query.deadline, type(uint256).max);
        assertEq(query.rawParams, getSwapParams(pool, indexFrom, indexTo));
    }

    /// @dev not enough liquidity to test CCTP max bridged amount out
    function testGetOriginAmountOut_inUSDC_outUSDC_overMaxBridgedAmount() public {
        address tokenIn = USDC;
        string memory tokenSymbol = "CCTP.USDC";
        uint256 amountIn = 10**12 + 1;

        SwapQuery memory query = router.getOriginAmountOut(tokenIn, tokenSymbol, amountIn);
        assertEq(query.routerAdapter, address(0));
        assertEq(query.tokenOut, address(0));
        assertEq(query.minAmountOut, 0);
        assertEq(query.deadline, 0);
        assertEq(query.rawParams, bytes(""));
    }

    function testGetOriginAmountOut_inWETHe_outNETH() public {
        address tokenIn = WETH_E;
        string memory tokenSymbol = "nETH";
        uint256 amountIn = 10e18;

        address pool = 0xdd60483Ace9B215a7c019A44Be2F22Aa9982652E; // Aave swap wrapper
        uint8 indexFrom = 1;
        uint8 indexTo = 0;
        uint256 amountOut = calculateSwap(pool, indexFrom, indexTo, amountIn);

        SwapQuery memory query = router.getOriginAmountOut(tokenIn, tokenSymbol, amountIn);
        assertEq(query.routerAdapter, address(router));
        assertEq(query.tokenOut, NETH);
        assertEq(query.minAmountOut, amountOut);
        assertEq(query.deadline, type(uint256).max);
        assertEq(query.rawParams, getSwapParams(pool, indexFrom, indexTo));
    }

    function testGetOriginAmountOut_inWAVAX_outWAVAX() public {
        address tokenIn = WAVAX;
        string memory tokenSymbol = "AVAX";
        uint256 amountIn = getTestAmount(WAVAX);

        uint256 amountOut = amountIn;
        SwapQuery memory query = router.getOriginAmountOut(tokenIn, tokenSymbol, amountIn);
        assertEq(query.routerAdapter, address(0));
        assertEq(query.tokenOut, WAVAX);
        assertEq(query.minAmountOut, amountOut);
        assertEq(query.deadline, type(uint256).max);
        assertEq(query.rawParams, bytes(""));
    }

    function testGetOriginAmountOut_inAVAX_outWAVAX() public {
        address tokenIn = UniversalTokenLib.ETH_ADDRESS;
        string memory tokenSymbol = "AVAX";
        uint256 amountIn = getTestAmount(WAVAX);

        DefaultParams memory params = DefaultParams({
            action: Action.HandleEth,
            pool: address(0),
            tokenIndexFrom: type(uint8).max,
            tokenIndexTo: type(uint8).max
        });

        uint256 amountOut = amountIn;
        SwapQuery memory query = router.getOriginAmountOut(tokenIn, tokenSymbol, amountIn);
        assertEq(query.routerAdapter, address(router));
        assertEq(query.tokenOut, WAVAX);
        assertEq(query.minAmountOut, amountOut);
        assertEq(query.deadline, type(uint256).max);
        assertEq(query.rawParams, abi.encode(params));
    }

    function testGetOriginAmountOut_inGMX_outGMX() public {
        address tokenIn = GMX;
        string memory tokenSymbol = "GMX";
        uint256 amountIn = getTestAmount(GMX);

        uint256 amountOut = amountIn;
        SwapQuery memory query = router.getOriginAmountOut(tokenIn, tokenSymbol, amountIn);
        assertEq(query.routerAdapter, address(0));
        assertEq(query.tokenOut, GMX);
        assertEq(query.minAmountOut, amountOut);
        assertEq(query.deadline, type(uint256).max);
        assertEq(query.rawParams, bytes(""));
    }

    function testGetDestinationAmountOut_inNUSD_outUSDCe() public {
        uint256 amountIn = 10000 * 1e18; // @dev need larger amount to be larger than fee amount
        DestRequest memory request = DestRequest({symbol: "nUSD", amountIn: amountIn});

        address tokenOut = USDC_E;
        address pool = AVAX_STABLE_POOL;
        uint8 indexFrom = 0;
        uint8 indexTo = 2;

        uint256 fee = (amountIn * 0.0008e10) / 10**10;
        uint256 amountInLessBridgeFees = amountIn - fee;
        uint256 amountOut = calculateSwap(pool, indexFrom, indexTo, amountInLessBridgeFees);

        SwapQuery memory query = router.getDestinationAmountOut(request, tokenOut);
        assertEq(query.routerAdapter, address(router));
        assertEq(query.tokenOut, tokenOut);
        assertEq(query.minAmountOut, amountOut);
        assertEq(query.deadline, type(uint256).max);
        assertEq(query.rawParams, getSwapParams(pool, indexFrom, indexTo));
    }

    function testGetDestinationAmountOut_inNUSD_outNUSD() public {
        uint256 amountIn = 10000 * 1e18; // @dev need larger amount to be larger than fee amount
        DestRequest memory request = DestRequest({symbol: "nUSD", amountIn: amountIn});

        address tokenOut = NUSD;
        uint256 fee = (amountIn * 0.0008e10) / 10**10;
        uint256 amountInLessBridgeFees = amountIn - fee;
        uint256 amountOut = amountInLessBridgeFees;

        SwapQuery memory query = router.getDestinationAmountOut(request, tokenOut);
        assertEq(query.routerAdapter, address(0));
        assertEq(query.tokenOut, tokenOut);
        assertEq(query.minAmountOut, amountOut);
        assertEq(query.deadline, type(uint256).max);
        assertEq(query.rawParams, bytes(""));
    }

    function testGetDestinationAmountOut_inNETH_outWETHe() public {
        uint256 amountIn = 10000 * 1e18; // @dev need larger amount to be larger than fee amount
        DestRequest memory request = DestRequest({symbol: "nETH", amountIn: amountIn});

        address tokenOut = WETH_E;
        uint256 fee = (amountIn * 0.0006e10) / 10**10;

        address pool = 0xdd60483Ace9B215a7c019A44Be2F22Aa9982652E; // Aave swap wrapper
        uint8 indexFrom = 0;
        uint8 indexTo = 1;
        uint256 amountInLessBridgeFees = amountIn - fee;
        uint256 amountOut = calculateSwap(pool, indexFrom, indexTo, amountInLessBridgeFees);

        SwapQuery memory query = router.getDestinationAmountOut(request, tokenOut);
        assertEq(query.routerAdapter, address(router));
        assertEq(query.tokenOut, tokenOut);
        assertEq(query.minAmountOut, amountOut);
        assertEq(query.deadline, type(uint256).max);
        assertEq(query.rawParams, getSwapParams(pool, indexFrom, indexTo));
    }

    function testGetDestinationAmountOut_inWAVAX_outWAVAX() public {
        uint256 amountIn = 1000 * 1e18; // @dev need larger amount to be larger than fee amount
        DestRequest memory request = DestRequest({symbol: "AVAX", amountIn: amountIn});

        address tokenOut = WAVAX;
        uint256 fee = (amountIn * 0.0004e10) / 10**10;
        uint256 amountInLessBridgeFees = amountIn - fee;
        uint256 amountOut = amountInLessBridgeFees;

        SwapQuery memory query = router.getDestinationAmountOut(request, tokenOut);
        assertEq(query.routerAdapter, address(0));
        assertEq(query.tokenOut, tokenOut);
        assertEq(query.minAmountOut, amountOut);
        assertEq(query.deadline, type(uint256).max);
        assertEq(query.rawParams, bytes(""));
    }

    function testGetDestinationAmountOut_inWAVAX_outAVAX() public {
        uint256 amountIn = 1000 * 1e18; // @dev need larger amount to be larger than fee amount
        DestRequest memory request = DestRequest({symbol: "AVAX", amountIn: amountIn});

        address tokenOut = UniversalTokenLib.ETH_ADDRESS;
        uint256 fee = (amountIn * 0.0004e10) / 10**10;
        uint256 amountInLessBridgeFees = amountIn - fee;
        uint256 amountOut = amountInLessBridgeFees;

        DefaultParams memory params = DefaultParams({
            action: Action.HandleEth,
            pool: address(0),
            tokenIndexFrom: type(uint8).max,
            tokenIndexTo: type(uint8).max
        });

        SwapQuery memory query = router.getDestinationAmountOut(request, tokenOut);
        assertEq(query.routerAdapter, address(router));
        assertEq(query.tokenOut, tokenOut);
        assertEq(query.minAmountOut, amountOut);
        assertEq(query.deadline, type(uint256).max);
        assertEq(query.rawParams, abi.encode(params));
    }

    function testGetDestinationAmountOut_inGMX_outGMX() public {
        uint256 amountIn = 1000 * 1e18; // @dev need larger amount to be larger than fee amount
        DestRequest memory request = DestRequest({symbol: "GMX", amountIn: amountIn});

        address tokenOut = GMX;
        uint256 fee = (amountIn * 0.0005e10) / 10**10;
        uint256 amountInLessBridgeFees = amountIn - fee;
        uint256 amountOut = amountInLessBridgeFees;

        SwapQuery memory query = router.getDestinationAmountOut(request, tokenOut);
        assertEq(query.routerAdapter, address(0));
        assertEq(query.tokenOut, tokenOut);
        assertEq(query.minAmountOut, amountOut);
        assertEq(query.deadline, type(uint256).max);
        assertEq(query.rawParams, bytes(""));
    }

    function testSynapseBridge_avalancheToEthereum_inNUSD_outNUSD() public {
        address module = expectedModules[0]; // Synapse bridge module

        SwapQuery memory originQuery;
        SwapQuery memory destQuery;

        redeemEvent = RedeemEvent({to: recipient, chainId: 1, token: NUSD, amount: getTestAmount(NUSD)});
        initiateBridge(
            expectRedeemEvent,
            1, // mainnet
            module,
            NUSD,
            originQuery,
            destQuery
        );
    }

    function testSynapseBridge_avalancheToEthereum_inUSDCe_outNUSD() public {
        address module = expectedModules[0];

        address pool = AVAX_STABLE_POOL;
        DefaultParams memory params = DefaultParams({
            action: Action.Swap,
            pool: pool, // stableswap pool on arbitrum
            tokenIndexFrom: 2,
            tokenIndexTo: 0
        });
        SwapQuery memory originQuery = SwapQuery({
            routerAdapter: address(router),
            tokenOut: NUSD,
            minAmountOut: 0,
            deadline: type(uint256).max,
            rawParams: abi.encode(params)
        });
        SwapQuery memory destQuery;

        uint256 amount = calculateSwap(pool, 2, 0, getTestAmount(USDC_E));
        redeemEvent = RedeemEvent({to: recipient, chainId: 1, token: NUSD, amount: amount});
        initiateBridge(
            expectRedeemEvent,
            1, // mainnet
            module,
            USDC_E,
            originQuery,
            destQuery
        );
    }

    function testSynapseBridge_avalancheToEthereum_inNUSD_outUSDC() public {
        address module = expectedModules[0];

        SwapQuery memory originQuery;
        DefaultParams memory destParams = DefaultParams({
            action: Action.RemoveLiquidity,
            pool: 0x1116898DdA4015eD8dDefb84b6e8Bc24528Af2d8, // stableswap pool on mainnet
            tokenIndexFrom: 0,
            tokenIndexTo: 1
        });
        SwapQuery memory destQuery = SwapQuery({
            routerAdapter: 0x1116898DdA4015eD8dDefb84b6e8Bc24528Af2d8, // irrelevant for test
            tokenOut: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, // USDC on mainnet
            minAmountOut: 0,
            deadline: type(uint256).max,
            rawParams: abi.encode(destParams)
        });

        redeemAndRemoveEvent = RedeemAndRemoveEvent({
            to: recipient,
            chainId: 1,
            token: NUSD,
            amount: getTestAmount(NUSD),
            swapTokenIndex: 1,
            swapMinAmount: 0,
            swapDeadline: type(uint256).max
        });
        initiateBridge(
            expectRedeemAndRemoveEvent,
            1, // mainnet
            module,
            NUSD,
            originQuery,
            destQuery
        );
    }

    function testSynapseBridge_avalancheToEthereum_inUSDCe_outUSDC() public {
        address module = expectedModules[0];

        address pool = AVAX_STABLE_POOL;
        uint256 amount = calculateSwap(pool, 2, 0, getTestAmount(USDC_E));

        DefaultParams memory originParams = DefaultParams({
            action: Action.Swap,
            pool: pool, // stableswap pool on arbitrum
            tokenIndexFrom: 2,
            tokenIndexTo: 0
        });
        SwapQuery memory originQuery = SwapQuery({
            routerAdapter: address(router),
            tokenOut: NUSD,
            minAmountOut: amount,
            deadline: type(uint256).max,
            rawParams: abi.encode(originParams)
        });

        DefaultParams memory destParams = DefaultParams({
            action: Action.RemoveLiquidity,
            pool: 0x1116898DdA4015eD8dDefb84b6e8Bc24528Af2d8, // stableswap pool on mainnet
            tokenIndexFrom: 0,
            tokenIndexTo: 1
        });
        SwapQuery memory destQuery = SwapQuery({
            routerAdapter: 0x1116898DdA4015eD8dDefb84b6e8Bc24528Af2d8, // irrelevant for test
            tokenOut: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, // USDC on mainnet
            minAmountOut: 0,
            deadline: type(uint256).max,
            rawParams: abi.encode(destParams)
        });

        redeemAndRemoveEvent = RedeemAndRemoveEvent({
            to: recipient,
            chainId: 1,
            token: NUSD,
            amount: originQuery.minAmountOut,
            swapTokenIndex: 1,
            swapMinAmount: 0,
            swapDeadline: type(uint256).max
        });
        initiateBridge(
            expectRedeemAndRemoveEvent,
            1, // mainnet
            module,
            USDC_E,
            originQuery,
            destQuery
        );
    }

    function testSynapseBridge_avalancheToEthereum_inGMX_outGMX() public {
        address module = expectedModules[0]; // Synapse bridge module

        SwapQuery memory originQuery;
        SwapQuery memory destQuery;

        redeemEvent = RedeemEvent({to: recipient, chainId: 1, token: GMX_WRAPPER, amount: getTestAmount(GMX)});
        initiateBridge(
            expectRedeemEvent,
            1, // mainnet
            module,
            GMX,
            originQuery,
            destQuery
        );
    }

    function testSynapseBridge_avalancheToEthereum_inWAVAX_outWAVAX() public {
        address module = expectedModules[0]; // Synapse bridge module

        SwapQuery memory originQuery;
        SwapQuery memory destQuery;

        depositEvent = DepositEvent({
            to: recipient,
            chainId: 1, // mainnet
            token: WAVAX,
            amount: getTestAmount(WAVAX)
        });
        initiateBridge(
            expectDepositEvent,
            1, // mainnet
            module,
            WAVAX,
            originQuery,
            destQuery
        );
    }

    function testSynapseBridge_avalancheToEthereum_inAVAX_outWAVAX() public {
        address module = expectedModules[0]; // Synapse bridge module

        DefaultParams memory originParams = DefaultParams({
            action: Action.HandleEth,
            pool: address(0),
            tokenIndexFrom: type(uint8).max,
            tokenIndexTo: type(uint8).max
        });
        SwapQuery memory originQuery = SwapQuery({
            routerAdapter: address(router),
            tokenOut: WAVAX,
            minAmountOut: 0,
            deadline: type(uint256).max,
            rawParams: abi.encode(originParams)
        });
        SwapQuery memory destQuery;

        depositEvent = DepositEvent({
            to: recipient,
            chainId: 1, // mainnet
            token: WAVAX,
            amount: getTestAmount(WAVAX)
        });
        initiateBridge(
            expectDepositEvent,
            1, // mainnet
            module,
            UniversalTokenLib.ETH_ADDRESS,
            originQuery,
            destQuery
        );
    }

    function testSynapseCCTP_avalancheToEthereum_inUSDC_outUSDC() public {
        address module = expectedModules[1]; // Synapse CCTP module

        SwapQuery memory originQuery;
        SwapQuery memory destQuery;

        uint32 requestVersion = getRequestVersion(true);
        bytes memory swapParams = bytes("");

        uint32 originDomain = 1;
        uint32 destDomain = 0;
        uint64 nonce = getNextAvailableNonce();

        bytes memory formattedRequest = formatRequest(
            requestVersion,
            originDomain,
            nonce,
            USDC,
            getTestAmount(USDC),
            recipient,
            swapParams
        );
        bytes32 expectedRequestID = getExpectedRequestID(formattedRequest, destDomain, requestVersion);

        requestSentEvent = CircleRequestSentEvent({
            chainId: 1,
            sender: msg.sender,
            nonce: nonce,
            token: USDC,
            amount: getTestAmount(USDC),
            requestVersion: requestVersion,
            formattedRequest: formattedRequest,
            requestID: expectedRequestID
        });
        initiateBridge(
            expectCircleRequestSentEvent,
            1, // mainnet
            module,
            USDC,
            originQuery,
            destQuery
        );
    }

    function testSynapseCCTP_avalancheToEthereum_inUSDCe_outUSDC() public {
        address module = expectedModules[1]; // Synapse CCTP module

        address pool = 0x9A2Dea7B81cfe3e0011D44D41c5c5142b8d9abdF; // LinkedPool
        DefaultParams memory originParams = DefaultParams({
            action: Action.Swap,
            pool: pool,
            tokenIndexFrom: 4,
            tokenIndexTo: 0
        });
        SwapQuery memory originQuery = SwapQuery({
            routerAdapter: address(router),
            tokenOut: USDC,
            minAmountOut: 0,
            deadline: type(uint256).max,
            rawParams: abi.encode(originParams)
        });
        uint256 amountIn = calculateSwap(pool, 4, 0, getTestAmount(USDC_E));

        SwapQuery memory destQuery;

        uint32 requestVersion = getRequestVersion(true);
        bytes memory swapParams = bytes("");

        uint32 originDomain = 1;
        uint32 destDomain = 0;
        uint64 nonce = getNextAvailableNonce();

        bytes memory formattedRequest = formatRequest(
            requestVersion,
            originDomain,
            nonce,
            USDC,
            amountIn,
            recipient,
            swapParams
        );
        bytes32 expectedRequestID = getExpectedRequestID(formattedRequest, destDomain, requestVersion);

        requestSentEvent = CircleRequestSentEvent({
            chainId: 1,
            sender: msg.sender,
            nonce: nonce,
            token: USDC,
            amount: amountIn,
            requestVersion: requestVersion,
            formattedRequest: formattedRequest,
            requestID: expectedRequestID
        });
        initiateBridge(
            expectCircleRequestSentEvent,
            1, // mainnet
            module,
            USDC_E,
            originQuery,
            destQuery
        );
    }

    function testSynapseCCTP_avalancheToArbitrum_inUSDC_outUSDCe() public {
        address module = expectedModules[1]; // Synapse CCTP module

        SwapQuery memory originQuery;

        DefaultParams memory destParams = DefaultParams({
            action: Action.Swap,
            pool: 0xC40BF702aBebB494842e2a1751bCf6D8C5be2Fa9, // stableswap pool on arbitrum
            tokenIndexFrom: 0,
            tokenIndexTo: 1
        });
        SwapQuery memory destQuery = SwapQuery({
            routerAdapter: 0xC40BF702aBebB494842e2a1751bCf6D8C5be2Fa9,
            tokenOut: 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8, // USDCe on arbitrum
            minAmountOut: 0,
            deadline: type(uint256).max,
            rawParams: abi.encode(destParams)
        });

        uint32 requestVersion = getRequestVersion(false);
        bytes memory swapParams = formatSwapParams({
            tokenIndexFrom: 0,
            tokenIndexTo: 1,
            deadline: type(uint256).max,
            minAmountOut: 0
        });

        uint32 originDomain = 1;
        uint32 destDomain = 3;
        uint64 nonce = getNextAvailableNonce();

        bytes memory formattedRequest = formatRequest(
            requestVersion,
            originDomain,
            nonce,
            USDC,
            getTestAmount(USDC),
            recipient,
            swapParams
        );
        bytes32 expectedRequestID = getExpectedRequestID(formattedRequest, destDomain, requestVersion);

        requestSentEvent = CircleRequestSentEvent({
            chainId: 42161,
            sender: msg.sender,
            nonce: nonce,
            token: USDC,
            amount: getTestAmount(USDC),
            requestVersion: requestVersion,
            formattedRequest: formattedRequest,
            requestID: expectedRequestID
        });
        initiateBridge(
            expectCircleRequestSentEvent,
            42161, // arbitrum
            module,
            USDC,
            originQuery,
            destQuery
        );
    }

    function testSynapseCCTP_avalancheToArbitrum_inUSDCe_outUSDCe() public {
        address module = expectedModules[1]; // Synapse CCTP module

        address pool = 0x9A2Dea7B81cfe3e0011D44D41c5c5142b8d9abdF; // LinkedPool

        uint256 amountIn = calculateSwap(pool, 4, 0, getTestAmount(USDC_E));

        SwapQuery memory originQuery;
        SwapQuery memory destQuery;
        {
            DefaultParams memory originParams = DefaultParams({
                action: Action.Swap,
                pool: pool,
                tokenIndexFrom: 4,
                tokenIndexTo: 0
            });
            originQuery = SwapQuery({
                routerAdapter: address(router),
                tokenOut: USDC,
                minAmountOut: 0,
                deadline: type(uint256).max,
                rawParams: abi.encode(originParams)
            });

            DefaultParams memory destParams = DefaultParams({
                action: Action.Swap,
                pool: 0xC40BF702aBebB494842e2a1751bCf6D8C5be2Fa9, // stableswap pool on arbitrum
                tokenIndexFrom: 0,
                tokenIndexTo: 1
            });
            destQuery = SwapQuery({
                routerAdapter: 0xC40BF702aBebB494842e2a1751bCf6D8C5be2Fa9,
                tokenOut: 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8, // USDCe on arbitrum
                minAmountOut: 0,
                deadline: type(uint256).max,
                rawParams: abi.encode(destParams)
            });
        }

        uint32 requestVersion = getRequestVersion(false);
        bytes memory swapParams = formatSwapParams({
            tokenIndexFrom: 0,
            tokenIndexTo: 1,
            deadline: type(uint256).max,
            minAmountOut: 0
        });

        uint32 originDomain = 1;
        uint32 destDomain = 3;
        uint64 nonce = getNextAvailableNonce();

        bytes memory formattedRequest = formatRequest(
            requestVersion,
            originDomain,
            nonce,
            USDC,
            amountIn,
            recipient,
            swapParams
        );
        bytes32 expectedRequestID = getExpectedRequestID(formattedRequest, destDomain, requestVersion);

        requestSentEvent = CircleRequestSentEvent({
            chainId: 42161,
            sender: msg.sender,
            nonce: nonce,
            token: USDC,
            amount: amountIn,
            requestVersion: requestVersion,
            formattedRequest: formattedRequest,
            requestID: expectedRequestID
        });
        initiateBridge(
            expectCircleRequestSentEvent,
            42161, // arbitrum
            module,
            USDC_E,
            originQuery,
            destQuery
        );
    }

    function testSwap_avalanche_inUSDCe_outUSDTe() public {
        address pool = AVAX_STABLE_POOL;
        DefaultParams memory params = DefaultParams({
            action: Action.Swap,
            pool: pool, // stableswap pool on arbitrum
            tokenIndexFrom: 2,
            tokenIndexTo: 3
        });
        SwapQuery memory query = SwapQuery({
            routerAdapter: address(router),
            tokenOut: USDT_E,
            minAmountOut: calculateSwap(pool, 2, 3, getTestAmount(USDC_E)),
            deadline: type(uint256).max,
            rawParams: abi.encode(params)
        });
        initiateSwap(recipient, USDC_E, getTestAmount(USDC_E), query);
    }

    function testSwap_avalanche_inWETHe_outNETH() public {
        address pool = 0xdd60483Ace9B215a7c019A44Be2F22Aa9982652E; // Aave swap wrapper
        DefaultParams memory params = DefaultParams({
            action: Action.Swap,
            pool: pool, // stableswap pool on arbitrum
            tokenIndexFrom: 1,
            tokenIndexTo: 0
        });
        SwapQuery memory query = SwapQuery({
            routerAdapter: address(router),
            tokenOut: NETH,
            minAmountOut: calculateSwap(pool, 1, 0, getTestAmount(WETH_E)),
            deadline: type(uint256).max,
            rawParams: abi.encode(params)
        });
        initiateSwap(recipient, WETH_E, getTestAmount(WETH_E), query);
    }
}
