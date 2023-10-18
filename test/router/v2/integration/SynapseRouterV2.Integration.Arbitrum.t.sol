// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Action, ActionLib, BridgeToken, DefaultParams, DestRequest, LimitedToken, SwapQuery} from "../../../../contracts/router/libs/Structs.sol";
import {UniversalTokenLib} from "../../../../contracts/router/libs/UniversalToken.sol";
import {IBridgeModule} from "../../../../contracts/router/interfaces/IBridgeModule.sol";

import {SynapseRouterV2IntegrationTest} from "./SynapseRouterV2.Integration.t.sol";
import {SynapseRouterV2BridgeUtils} from "./SynapseRouterV2.BridgeUtils.t.sol";
import {SynapseRouterV2CCTPUtils} from "./SynapseRouterV2.CCTPUtils.t.sol";

import {console} from "forge-std/Test.sol";

contract SynapseRouterV2ArbitrumIntegrationTestFork is
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
    address private constant H2O = 0xD1c6f989e9552DB523aBAE2378227fBb059a3976;
    address private constant L2DAO = 0x2CaB3abfC1670D1a452dF502e216a66883cDf079;
    address private constant AGEUR = 0x16BFc5fe024980124bEf51d1D792dC539d1B5Bf0;
    address private constant PLS = 0x51318B7D00db7ACc4026C88c3952B66278B6A67F;
    address private constant UNIDX = 0x5429706887FCb58a595677B73E9B0441C25d993D;
    address private constant PEPE = 0xA54B8e178A49F8e5405A4d44Bb31F496e5564A05;

    // supported tokens (for adapter swaps)
    address private constant NUSD_LP = 0xcFd72be67Ee69A0dd7cF0f846Fc0D98C33d60F16;
    address private constant USDC_E = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
    address private constant USDT = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
    address private constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

    address private constant NETH_LP = 0xD70A52248e546A3B260849386410C7170c7BD1E9;
    address private constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

    address private constant FRAX = 0x17FC002b466eEc40DaE837Fc4bE5c67993ddBd6F;
    address private constant DAI = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;

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
        originTokensBridge[1] = USDC_E;
        originTokensBridge[2] = USDT;
        originTokensBridge[3] = USDC;

        address[] memory destinationTokensBridge = new address[](3);
        destinationTokensBridge[0] = NUSD;
        destinationTokensBridge[1] = USDC_E;
        destinationTokensBridge[2] = USDT;

        addExpectedBridgeToken(BridgeToken({symbol: "nUSD", token: NUSD}), originTokensBridge, destinationTokensBridge);

        // add synapse cctp module bridge tokens
        address[] memory originTokensCCTP = new address[](4);
        originTokensCCTP[0] = USDC;
        originTokensCCTP[1] = NUSD;
        originTokensCCTP[2] = USDT;
        originTokensCCTP[3] = USDC_E;

        address[] memory destinationTokensCCTP = new address[](4);
        destinationTokensCCTP[0] = USDC;
        destinationTokensCCTP[1] = NUSD;
        destinationTokensCCTP[2] = USDT;
        destinationTokensCCTP[3] = USDC_E;

        addExpectedBridgeToken(
            BridgeToken({symbol: "CCTP.USDC", token: USDC}),
            originTokensCCTP,
            destinationTokensCCTP
        );
    }

    function testGetBridgeTokens() public {
        BridgeToken[] memory bridgeTokens = new BridgeToken[](17);
        bridgeTokens[0] = BridgeToken({token: NUSD, symbol: "nUSD"});
        bridgeTokens[1] = BridgeToken({token: SYN, symbol: "SYN"});
        bridgeTokens[2] = BridgeToken({token: NETH, symbol: "nETH"});
        bridgeTokens[3] = BridgeToken({token: WSOHM, symbol: "wsOHM"});
        bridgeTokens[4] = BridgeToken({token: GOHM, symbol: "gOHM"});
        bridgeTokens[5] = BridgeToken({token: GMX, symbol: "GMX"});
        bridgeTokens[6] = BridgeToken({token: USTC, symbol: "UST"});
        bridgeTokens[7] = BridgeToken({token: NEWO, symbol: "NEWO"});
        bridgeTokens[8] = BridgeToken({token: SDT, symbol: "SDT"});
        bridgeTokens[9] = BridgeToken({token: VSTA, symbol: "VSTA"});
        bridgeTokens[10] = BridgeToken({token: H2O, symbol: "H2O"});
        bridgeTokens[11] = BridgeToken({token: L2DAO, symbol: "L2DAO"});
        bridgeTokens[12] = BridgeToken({token: AGEUR, symbol: "agEUR"});
        bridgeTokens[13] = BridgeToken({token: PLS, symbol: "PLS"});
        bridgeTokens[14] = BridgeToken({token: UNIDX, symbol: "UNIDX"});
        bridgeTokens[15] = BridgeToken({token: PEPE, symbol: "PEPE"});
        bridgeTokens[16] = BridgeToken({token: USDC, symbol: "CCTP.USDC"});

        checkBridgeTokenArrays(router.getBridgeTokens(), bridgeTokens);
    }

    function testGetSupportedTokens() public {
        address[] memory supportedTokens = new address[](23);
        supportedTokens[0] = NUSD;
        supportedTokens[1] = USDC_E;
        supportedTokens[2] = USDT;
        supportedTokens[3] = NETH;
        supportedTokens[4] = WETH;
        supportedTokens[5] = USDC;
        supportedTokens[6] = FRAX;
        supportedTokens[7] = DAI;
        supportedTokens[8] = SYN;
        supportedTokens[9] = WSOHM;
        supportedTokens[10] = GOHM;
        supportedTokens[11] = GMX;
        supportedTokens[12] = USTC;
        supportedTokens[13] = NEWO;
        supportedTokens[14] = SDT;
        supportedTokens[15] = VSTA;
        supportedTokens[16] = H2O;
        supportedTokens[17] = L2DAO;
        supportedTokens[18] = AGEUR;
        supportedTokens[19] = PLS;
        supportedTokens[20] = UNIDX;
        supportedTokens[21] = PEPE;
        supportedTokens[22] = UniversalTokenLib.ETH_ADDRESS;
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
        string[] memory tokenSymbols = new string[](1);
        tokenSymbols[0] = "nUSD";
        uint256 amountIn = getTestAmount(USDC_E);

        address pool = 0x9Dd329F5411466d9e0C488fF72519CA9fEf0cb40;
        uint8 indexFrom = 1;
        uint8 indexTo = 0;
        uint256 amountOut = calculateSwap(pool, indexFrom, indexTo, amountIn);

        SwapQuery[] memory queries = router.getOriginAmountOut(tokenIn, tokenSymbols, amountIn);
        assertEq(queries.length, 1);

        SwapQuery memory query = queries[0];
        assertEq(query.routerAdapter, address(router));
        assertEq(query.tokenOut, NUSD);
        assertEq(query.minAmountOut, amountOut);
        assertEq(query.deadline, type(uint256).max);
        assertEq(query.rawParams, getSwapParams(pool, indexFrom, indexTo));
    }

    function testGetOriginAmountOut_inNUSD_outNUSD() public {
        address tokenIn = NUSD;
        string[] memory tokenSymbols = new string[](1);
        tokenSymbols[0] = "nUSD";
        uint256 amountIn = getTestAmount(NUSD);

        uint256 amountOut = amountIn;
        SwapQuery[] memory queries = router.getOriginAmountOut(tokenIn, tokenSymbols, amountIn);
        assertEq(queries.length, 1);

        SwapQuery memory query = queries[0];
        assertEq(query.routerAdapter, address(0));
        assertEq(query.tokenOut, NUSD);
        assertEq(query.minAmountOut, amountOut);
        assertEq(query.deadline, type(uint256).max);
        assertEq(query.rawParams, bytes(""));
    }

    /// @dev UNI not supported so amount out should produce zero
    function testGetOriginAmountOut_inUSDCe_outUNI() public {
        address tokenIn = USDC_E;
        string[] memory tokenSymbols = new string[](1);
        tokenSymbols[0] = "UNI";
        uint256 amountIn = getTestAmount(USDC_E);

        SwapQuery[] memory queries = router.getOriginAmountOut(tokenIn, tokenSymbols, amountIn);
        assertEq(queries.length, 1);

        SwapQuery memory query = queries[0];
        assertEq(query.routerAdapter, address(0));
        assertEq(query.tokenOut, address(0));
        assertEq(query.minAmountOut, 0);
        assertEq(query.deadline, 0);
        assertEq(query.rawParams, bytes(""));
    }

    function testGetOriginAmountOut_inUSDCe_outUSDC() public {
        address tokenIn = USDC_E;
        string[] memory tokenSymbols = new string[](1);
        tokenSymbols[0] = "CCTP.USDC";
        uint256 amountIn = 990000000000; // 990K USDC

        address pool = 0xC40BF702aBebB494842e2a1751bCf6D8C5be2Fa9;
        uint8 indexFrom = 1;
        uint8 indexTo = 0;
        uint256 amountOut = calculateSwap(pool, indexFrom, indexTo, amountIn);

        SwapQuery[] memory queries = router.getOriginAmountOut(tokenIn, tokenSymbols, amountIn);
        assertEq(queries.length, 1);

        SwapQuery memory query = queries[0];
        assertEq(query.routerAdapter, address(router));
        assertEq(query.tokenOut, USDC);
        assertEq(query.minAmountOut, amountOut);
        assertEq(query.deadline, type(uint256).max);
        assertEq(query.rawParams, getSwapParams(pool, indexFrom, indexTo));
    }

    /// @dev CCTP has max bridged amount out of 1M USDC
    function testGetOriginAmountOut_inUSDCe_outUSDC_overMaxBridgedAmount() public {
        address tokenIn = USDC_E;
        string[] memory tokenSymbols = new string[](1);
        tokenSymbols[0] = "CCTP.USDC";
        uint256 amountIn = 1100000000000;

        SwapQuery[] memory queries = router.getOriginAmountOut(tokenIn, tokenSymbols, amountIn);
        assertEq(queries.length, 1);

        SwapQuery memory query = queries[0];
        assertEq(query.routerAdapter, address(0));
        assertEq(query.tokenOut, address(0));
        assertEq(query.minAmountOut, 0);
        assertEq(query.deadline, 0);
        assertEq(query.rawParams, bytes(""));
    }

    function testGetOriginAmountOut_inETH_outNETH() public {
        address tokenIn = UniversalTokenLib.ETH_ADDRESS;
        string[] memory tokenSymbols = new string[](1);
        tokenSymbols[0] = "nETH";
        uint256 amountIn = 10e18;

        address pool = 0xa067668661C84476aFcDc6fA5D758C4c01C34352;
        uint8 indexFrom = 1;
        uint8 indexTo = 0;
        uint256 amountOut = calculateSwap(pool, indexFrom, indexTo, amountIn);

        SwapQuery[] memory queries = router.getOriginAmountOut(tokenIn, tokenSymbols, amountIn);
        assertEq(queries.length, 1);

        SwapQuery memory query = queries[0];
        assertEq(query.routerAdapter, address(router));
        assertEq(query.tokenOut, NETH);
        assertEq(query.minAmountOut, amountOut);
        assertEq(query.deadline, type(uint256).max);
        assertEq(query.rawParams, getSwapParams(pool, indexFrom, indexTo));
    }

    function testGetOriginAmountOut_inWETH_outNETH() public {
        address tokenIn = WETH;
        string[] memory tokenSymbols = new string[](1);
        tokenSymbols[0] = "nETH";
        uint256 amountIn = 10e18;

        address pool = 0xa067668661C84476aFcDc6fA5D758C4c01C34352;
        uint8 indexFrom = 1;
        uint8 indexTo = 0;
        uint256 amountOut = calculateSwap(pool, indexFrom, indexTo, amountIn);

        SwapQuery[] memory queries = router.getOriginAmountOut(tokenIn, tokenSymbols, amountIn);
        assertEq(queries.length, 1);

        SwapQuery memory query = queries[0];
        assertEq(query.routerAdapter, address(router));
        assertEq(query.tokenOut, NETH);
        assertEq(query.minAmountOut, amountOut);
        assertEq(query.deadline, type(uint256).max);
        assertEq(query.rawParams, getSwapParams(pool, indexFrom, indexTo));
    }

    function testGetDestinationAmountOut_inNUSD_outUSDCe() public {
        uint256 amountIn = 10000 * 1e18; // @dev need larger amount to be larger than fee amount
        DestRequest memory request = DestRequest({symbol: "nUSD", amountIn: amountIn});

        address tokenOut = USDC_E;
        address pool = 0x9Dd329F5411466d9e0C488fF72519CA9fEf0cb40;
        uint8 indexFrom = 0;
        uint8 indexTo = 1;

        uint256 fee = (amountIn * 0.0004e10) / 10**10;
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

    function testGetDestinationAmountOut_inNETH_outWETH() public {
        uint256 amountIn = 10000 * 1e18; // @dev need larger amount to be larger than fee amount
        DestRequest memory request = DestRequest({symbol: "nETH", amountIn: amountIn});

        address tokenOut = WETH;
        uint256 fee = (amountIn * 0.0004e10) / 10**10;

        address pool = 0xa067668661C84476aFcDc6fA5D758C4c01C34352;
        uint8 indexTo = 1;
        uint8 indexFrom = 0;
        uint256 amountInLessBridgeFees = amountIn - fee;
        uint256 amountOut = calculateSwap(pool, indexFrom, indexTo, amountInLessBridgeFees);

        SwapQuery memory query = router.getDestinationAmountOut(request, tokenOut);
        assertEq(query.routerAdapter, address(router));
        assertEq(query.tokenOut, tokenOut);
        assertEq(query.minAmountOut, amountOut);
        assertEq(query.deadline, type(uint256).max);
        assertEq(query.rawParams, getSwapParams(pool, indexFrom, indexTo));
    }

    function testGetDestinationAmountOut_inNETH_outETH() public {
        uint256 amountIn = 10000 * 1e18; // @dev need larger amount to be larger than fee amount
        DestRequest memory request = DestRequest({symbol: "nETH", amountIn: amountIn});

        address tokenOut = UniversalTokenLib.ETH_ADDRESS;
        uint256 fee = (amountIn * 0.0004e10) / 10**10;

        address pool = 0xa067668661C84476aFcDc6fA5D758C4c01C34352;
        uint8 indexTo = 1;
        uint8 indexFrom = 0;
        uint256 amountInLessBridgeFees = amountIn - fee;
        uint256 amountOut = calculateSwap(pool, indexFrom, indexTo, amountInLessBridgeFees);

        SwapQuery memory query = router.getDestinationAmountOut(request, tokenOut);
        assertEq(query.routerAdapter, address(router));
        assertEq(query.tokenOut, tokenOut);
        assertEq(query.minAmountOut, amountOut);
        assertEq(query.deadline, type(uint256).max);
        assertEq(query.rawParams, getSwapParams(pool, indexFrom, indexTo));
    }

    /// @dev UNI not supported so amount out should produce zero
    function testGetDestinationAmountOut_inUNI_outNUSD() public {
        uint256 amountIn = 10000 * 1e18; // @dev need larger amount to be larger than fee amount
        DestRequest memory request = DestRequest({symbol: "UNI", amountIn: amountIn});

        address tokenOut = NUSD;
        SwapQuery memory query = router.getDestinationAmountOut(request, tokenOut);
        assertEq(query.routerAdapter, address(0));
        assertEq(query.tokenOut, address(0));
        assertEq(query.minAmountOut, 0);
        assertEq(query.deadline, 0);
        assertEq(query.rawParams, bytes(""));
    }

    /// @dev Not supported as of test block height
    function testGetDestinationAmountOut_inNUSD_outUSDC() public {
        uint256 amountIn = 10000 * 1e18; // @dev need larger amount to be larger than fee amount
        DestRequest memory request = DestRequest({symbol: "nUSD", amountIn: amountIn});

        address tokenOut = USDC;
        SwapQuery memory query = router.getDestinationAmountOut(request, tokenOut);
        assertEq(query.routerAdapter, address(0));
        assertEq(query.tokenOut, tokenOut);
        assertEq(query.minAmountOut, 0);
        assertEq(query.deadline, 0);
        assertEq(query.rawParams, bytes(""));
    }

    function testGetDestinationAmountOut_inNUSD_outUSDCe_amountInLessThanFee() public {
        uint256 amountIn = getTestAmount(NUSD);
        DestRequest memory request = DestRequest({symbol: "nUSD", amountIn: amountIn});

        address tokenOut = USDC_E;
        uint256 fee = (amountIn * 0.0004e10) / 10**10;
        if (fee < 2e18) fee = 2e18; // @dev nUSD has min of 2 nUSD
        assertTrue(fee >= amountIn);

        SwapQuery memory query = router.getDestinationAmountOut(request, tokenOut);
        assertEq(query.routerAdapter, address(0));
        assertEq(query.tokenOut, address(0));
        assertEq(query.minAmountOut, 0);
        assertEq(query.deadline, 0);
        assertEq(query.rawParams, bytes(""));
    }

    function testSynapseBridge_arbitrumToEthereum_inNUSD_outNUSD() public {
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

    function testSynapseBridge_arbitrumToEthereum_inUSDCe_outNUSD() public {
        address module = expectedModules[0];

        address pool = 0x9Dd329F5411466d9e0C488fF72519CA9fEf0cb40;
        DefaultParams memory params = DefaultParams({
            action: Action.Swap,
            pool: pool, // stableswap pool on arbitrum
            tokenIndexFrom: 1,
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

        uint256 amount = calculateSwap(pool, 1, 0, getTestAmount(USDC_E));
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

    function testSynapseBridge_arbitrumToEthereum_inETH_outNETH() public {
        address module = expectedModules[0]; // Synapse bridge module

        address pool = 0xa067668661C84476aFcDc6fA5D758C4c01C34352;
        DefaultParams memory params = DefaultParams({
            action: Action.Swap,
            pool: pool, // stableswap pool on arbitrum
            tokenIndexFrom: 1,
            tokenIndexTo: 0
        });
        SwapQuery memory originQuery = SwapQuery({
            routerAdapter: address(router),
            tokenOut: NETH,
            minAmountOut: 0,
            deadline: type(uint256).max,
            rawParams: abi.encode(params)
        });
        SwapQuery memory destQuery;

        uint256 amount = getTestAmount(UniversalTokenLib.ETH_ADDRESS);
        uint256 amountOut = calculateSwap(pool, 1, 0, amount);
        redeemEvent = RedeemEvent({to: recipient, chainId: 1, token: NETH, amount: amountOut});
        initiateBridge(
            expectRedeemEvent,
            1, // mainnet
            module,
            UniversalTokenLib.ETH_ADDRESS,
            originQuery,
            destQuery
        );
    }

    function testSynapseBridge_arbitrumToEthereum_inWETH_outNETH() public {
        address module = expectedModules[0]; // Synapse bridge module

        address pool = 0xa067668661C84476aFcDc6fA5D758C4c01C34352;
        DefaultParams memory params = DefaultParams({
            action: Action.Swap,
            pool: pool, // stableswap pool on arbitrum
            tokenIndexFrom: 1,
            tokenIndexTo: 0
        });
        SwapQuery memory originQuery = SwapQuery({
            routerAdapter: address(router),
            tokenOut: NETH,
            minAmountOut: 0,
            deadline: type(uint256).max,
            rawParams: abi.encode(params)
        });
        SwapQuery memory destQuery;

        uint256 amount = getTestAmount(WETH);
        uint256 amountOut = calculateSwap(pool, 1, 0, amount);
        redeemEvent = RedeemEvent({to: recipient, chainId: 1, token: NETH, amount: amountOut});
        initiateBridge(
            expectRedeemEvent,
            1, // mainnet
            module,
            WETH,
            originQuery,
            destQuery
        );
    }

    function testSynapseBridge_arbitrumToOptimism_inNUSD_outUSDCe() public {
        address module = expectedModules[0]; // Synapse bridge module

        SwapQuery memory originQuery;

        DefaultParams memory params = DefaultParams({
            action: Action.Swap,
            pool: 0xF44938b0125A6662f9536281aD2CD6c499F22004, // stableswap pool on optimism
            tokenIndexFrom: 0,
            tokenIndexTo: 1
        });
        SwapQuery memory destQuery = SwapQuery({
            routerAdapter: 0xF44938b0125A6662f9536281aD2CD6c499F22004,
            tokenOut: 0x7F5c764cBc14f9669B88837ca1490cCa17c31607, // USDC.e on optimism
            minAmountOut: 0,
            deadline: type(uint256).max,
            rawParams: abi.encode(params)
        });

        redeemAndSwapEvent = RedeemAndSwapEvent({
            to: recipient,
            chainId: 10,
            token: NUSD,
            amount: getTestAmount(NUSD),
            tokenIndexFrom: 0,
            tokenIndexTo: 1,
            minDy: 0,
            deadline: type(uint256).max
        });
        initiateBridge(
            expectRedeemAndSwapEvent,
            10, // optimism
            module,
            NUSD,
            originQuery,
            destQuery
        );
    }

    function testSynapseBridge_arbitrumToOptimism_inUSDCe_outUSDCe() public {
        address module = expectedModules[0]; // Synapse bridge module

        DefaultParams memory originParams = DefaultParams({
            action: Action.Swap,
            pool: 0x9Dd329F5411466d9e0C488fF72519CA9fEf0cb40,
            tokenIndexFrom: 1,
            tokenIndexTo: 0
        });
        SwapQuery memory originQuery = SwapQuery({
            routerAdapter: address(router),
            tokenOut: NUSD,
            minAmountOut: calculateSwap(0x9Dd329F5411466d9e0C488fF72519CA9fEf0cb40, 1, 0, getTestAmount(USDC_E)),
            deadline: type(uint256).max,
            rawParams: abi.encode(originParams)
        });

        DefaultParams memory destParams = DefaultParams({
            action: Action.Swap,
            pool: 0xF44938b0125A6662f9536281aD2CD6c499F22004, // stableswap pool on optimism
            tokenIndexFrom: 0,
            tokenIndexTo: 1
        });
        SwapQuery memory destQuery = SwapQuery({
            routerAdapter: 0xF44938b0125A6662f9536281aD2CD6c499F22004,
            tokenOut: 0x7F5c764cBc14f9669B88837ca1490cCa17c31607, // USDC.e on optimism
            minAmountOut: 0,
            deadline: type(uint256).max,
            rawParams: abi.encode(destParams)
        });

        redeemAndSwapEvent = RedeemAndSwapEvent({
            to: recipient,
            chainId: 10,
            token: NUSD,
            amount: originQuery.minAmountOut,
            tokenIndexFrom: 0,
            tokenIndexTo: 1,
            minDy: 0,
            deadline: type(uint256).max
        });
        initiateBridge(
            expectRedeemAndSwapEvent,
            10, // optimism
            module,
            USDC_E,
            originQuery,
            destQuery
        );
    }

    function testSynapseBridge_arbitrumToOptimism_inETH_outWETH() public {
        address module = expectedModules[0]; // Synapse bridge module

        DefaultParams memory originParams = DefaultParams({
            action: Action.Swap,
            pool: 0xa067668661C84476aFcDc6fA5D758C4c01C34352,
            tokenIndexFrom: 1,
            tokenIndexTo: 0
        });
        SwapQuery memory originQuery = SwapQuery({
            routerAdapter: address(router),
            tokenOut: NETH,
            minAmountOut: calculateSwap(
                0xa067668661C84476aFcDc6fA5D758C4c01C34352,
                1,
                0,
                getTestAmount(UniversalTokenLib.ETH_ADDRESS)
            ),
            deadline: type(uint256).max,
            rawParams: abi.encode(originParams)
        });

        DefaultParams memory destParams = DefaultParams({
            action: Action.Swap,
            pool: 0xE27BFf97CE92C3e1Ff7AA9f86781FDd6D48F5eE9, // stableswap pool on optimism
            tokenIndexFrom: 0,
            tokenIndexTo: 1
        });
        SwapQuery memory destQuery = SwapQuery({
            routerAdapter: 0xE27BFf97CE92C3e1Ff7AA9f86781FDd6D48F5eE9,
            tokenOut: 0x121ab82b49B2BC4c7901CA46B8277962b4350204, // WETH on optimism
            minAmountOut: 0,
            deadline: type(uint256).max,
            rawParams: abi.encode(destParams)
        });

        redeemAndSwapEvent = RedeemAndSwapEvent({
            to: recipient,
            chainId: 10,
            token: NETH,
            amount: originQuery.minAmountOut,
            tokenIndexFrom: 0,
            tokenIndexTo: 1,
            minDy: 0,
            deadline: type(uint256).max
        });
        initiateBridge(
            expectRedeemAndSwapEvent,
            10, // optimism
            module,
            UniversalTokenLib.ETH_ADDRESS,
            originQuery,
            destQuery
        );
    }

    function testSynapseBridge_arbitrumToEthereum_inNUSD_outUSDC() public {
        address module = expectedModules[0]; // Synapse bridge module

        SwapQuery memory originQuery;

        DefaultParams memory params = DefaultParams({
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
            rawParams: abi.encode(params)
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

    function testSynapseBridge_arbitrumToEthereum_inUSDCe_outUSDC() public {
        address module = expectedModules[0]; // Synapse bridge module

        DefaultParams memory originParams = DefaultParams({
            action: Action.Swap,
            pool: 0x9Dd329F5411466d9e0C488fF72519CA9fEf0cb40,
            tokenIndexFrom: 1,
            tokenIndexTo: 0
        });
        SwapQuery memory originQuery = SwapQuery({
            routerAdapter: address(router),
            tokenOut: NUSD,
            minAmountOut: calculateSwap(0x9Dd329F5411466d9e0C488fF72519CA9fEf0cb40, 1, 0, getTestAmount(USDC_E)),
            deadline: type(uint256).max,
            rawParams: abi.encode(originParams)
        });

        DefaultParams memory params = DefaultParams({
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
            rawParams: abi.encode(params)
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

    function testSynapseBridge_arbitrumToEthereum_inGMX_outGMX() public {
        address module = expectedModules[0]; // Synapse bridge module

        SwapQuery memory originQuery;
        SwapQuery memory destQuery;

        depositEvent = DepositEvent({
            to: recipient,
            chainId: 1, // mainnet
            token: GMX,
            amount: getTestAmount(GMX)
        });
        initiateBridge(
            expectDepositEvent,
            1, // mainnet
            module,
            GMX,
            originQuery,
            destQuery
        );
    }

    function testSynapseCCTP_arbitrumToEthereum_inUSDC_outUSDC() public {
        address module = expectedModules[1]; // Synapse CCTP module

        SwapQuery memory originQuery;
        SwapQuery memory destQuery;

        uint32 requestVersion = getRequestVersion(true);
        bytes memory swapParams = bytes("");

        uint32 originDomain = 3;
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

    function testSynapseCCTP_arbitrumToEthereum_inUSDCe_outUSDC() public {
        address module = expectedModules[1]; // Synapse CCTP module

        address pool = 0xC40BF702aBebB494842e2a1751bCf6D8C5be2Fa9;
        DefaultParams memory params = DefaultParams({
            action: Action.Swap,
            pool: pool, // stableswap pool on arbitrum
            tokenIndexFrom: 1,
            tokenIndexTo: 0
        });
        SwapQuery memory originQuery = SwapQuery({
            routerAdapter: address(router),
            tokenOut: USDC,
            minAmountOut: 0,
            deadline: type(uint256).max,
            rawParams: abi.encode(params)
        });
        SwapQuery memory destQuery;

        uint32 requestVersion = getRequestVersion(true);
        bytes memory swapParams = bytes("");

        uint32 originDomain = 3;
        uint32 destDomain = 0;
        uint64 nonce = getNextAvailableNonce();
        uint256 amount = calculateSwap(pool, 1, 0, getTestAmount(USDC_E));

        bytes memory formattedRequest = formatRequest(
            requestVersion,
            originDomain,
            nonce,
            USDC,
            amount,
            recipient,
            swapParams
        );
        bytes32 expectedRequestID = getExpectedRequestID(formattedRequest, destDomain, requestVersion);

        requestSentEvent = CircleRequestSentEvent({
            chainId: 1,
            sender: msg.sender,
            nonce: nonce,
            token: USDC,
            amount: amount,
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

    function testSynapseCCTP_arbitrumToOptimism_inUSDC_outUSDCe() public {
        address module = expectedModules[1]; // Synapse CCTP module

        SwapQuery memory originQuery;

        DefaultParams memory params = DefaultParams({
            action: Action.Swap,
            pool: 0x2E2D190AD4e0d7BE9569BAeBD4d33298379b0502, // uni v3 pool on optimism
            tokenIndexFrom: 0,
            tokenIndexTo: 1
        });
        SwapQuery memory destQuery = SwapQuery({
            routerAdapter: 0xE23c791718081D720E1E48408C110055f7aa86db,
            tokenOut: 0x7F5c764cBc14f9669B88837ca1490cCa17c31607, // USDC.e on optimism
            minAmountOut: 0,
            deadline: type(uint256).max,
            rawParams: abi.encode(params)
        });

        uint32 requestVersion = getRequestVersion(false);
        bytes memory swapParams = formatSwapParams({
            tokenIndexFrom: 0,
            tokenIndexTo: 1,
            deadline: type(uint256).max,
            minAmountOut: 0
        });

        uint32 originDomain = 3;
        uint32 destDomain = 2;
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
            chainId: 10,
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
            10, // optimism
            module,
            USDC,
            originQuery,
            destQuery
        );
    }

    function testSynapseCCTP_arbitrumToOptimism_inUSDCe_outUSDCe() public {
        address module = expectedModules[1]; // Synapse CCTP module

        address pool = 0xC40BF702aBebB494842e2a1751bCf6D8C5be2Fa9;
        DefaultParams memory originParams = DefaultParams({
            action: Action.Swap,
            pool: pool, // stableswap pool on arbitrum
            tokenIndexFrom: 1,
            tokenIndexTo: 0
        });
        SwapQuery memory originQuery = SwapQuery({
            routerAdapter: address(router),
            tokenOut: USDC,
            minAmountOut: 0,
            deadline: type(uint256).max,
            rawParams: abi.encode(originParams)
        });

        DefaultParams memory destParams = DefaultParams({
            action: Action.Swap,
            pool: 0x2E2D190AD4e0d7BE9569BAeBD4d33298379b0502, // uni v3 pool on optimism
            tokenIndexFrom: 0,
            tokenIndexTo: 1
        });
        SwapQuery memory destQuery = SwapQuery({
            routerAdapter: 0xE23c791718081D720E1E48408C110055f7aa86db,
            tokenOut: 0x7F5c764cBc14f9669B88837ca1490cCa17c31607, // USDC.e on optimism
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

        {
            uint32 originDomain = 3;
            uint32 destDomain = 2;
            uint64 nonce = getNextAvailableNonce();

            uint256 amount = calculateSwap(pool, 1, 0, getTestAmount(USDC_E));
            bytes memory formattedRequest = formatRequest(
                requestVersion,
                originDomain,
                nonce,
                USDC,
                amount,
                recipient,
                swapParams
            );
            bytes32 expectedRequestID = getExpectedRequestID(formattedRequest, destDomain, requestVersion);
            requestSentEvent = CircleRequestSentEvent({
                chainId: 10,
                sender: msg.sender,
                nonce: nonce,
                token: USDC,
                amount: amount,
                requestVersion: requestVersion,
                formattedRequest: formattedRequest,
                requestID: expectedRequestID
            });
        }

        initiateBridge(
            expectCircleRequestSentEvent,
            10, // optimism
            module,
            USDC_E,
            originQuery,
            destQuery
        );
    }

    function testSwap_arbitrum_inUSDCe_outUSDC() public {
        address pool = 0xC40BF702aBebB494842e2a1751bCf6D8C5be2Fa9;
        DefaultParams memory params = DefaultParams({
            action: Action.Swap,
            pool: pool, // stableswap pool on arbitrum
            tokenIndexFrom: 1,
            tokenIndexTo: 0
        });
        SwapQuery memory query = SwapQuery({
            routerAdapter: address(router),
            tokenOut: USDC,
            minAmountOut: calculateSwap(pool, 1, 0, getTestAmount(USDC_E)),
            deadline: type(uint256).max,
            rawParams: abi.encode(params)
        });
        initiateSwap(recipient, USDC_E, getTestAmount(USDC_E), query);
    }

    function testSwap_arbitrum_inETH_outNETH() public {
        address pool = 0xa067668661C84476aFcDc6fA5D758C4c01C34352;
        DefaultParams memory params = DefaultParams({
            action: Action.Swap,
            pool: pool, // stableswap pool on arbitrum
            tokenIndexFrom: 1,
            tokenIndexTo: 0
        });
        SwapQuery memory query = SwapQuery({
            routerAdapter: address(router),
            tokenOut: NETH,
            minAmountOut: calculateSwap(pool, 1, 0, getTestAmount(UniversalTokenLib.ETH_ADDRESS)),
            deadline: type(uint256).max,
            rawParams: abi.encode(params)
        });
        initiateSwap(recipient, UniversalTokenLib.ETH_ADDRESS, getTestAmount(UniversalTokenLib.ETH_ADDRESS), query);
    }

    function testSwap_arbitrum_inWETH_outNETH() public {
        address pool = 0xa067668661C84476aFcDc6fA5D758C4c01C34352;
        DefaultParams memory params = DefaultParams({
            action: Action.Swap,
            pool: pool, // stableswap pool on arbitrum
            tokenIndexFrom: 1,
            tokenIndexTo: 0
        });
        SwapQuery memory query = SwapQuery({
            routerAdapter: address(router),
            tokenOut: NETH,
            minAmountOut: calculateSwap(pool, 1, 0, getTestAmount(WETH)),
            deadline: type(uint256).max,
            rawParams: abi.encode(params)
        });
        initiateSwap(recipient, WETH, getTestAmount(WETH), query);
    }
}
