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
    uint256 public constant ETH_BLOCK_NUMBER = 18413747; // 2023-10-23

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
        addExpectedToken(WETH, "WETH");
        addExpectedToken(UniversalTokenLib.ETH_ADDRESS, "ETH");
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
        // add synapse bridge module bridge tokens for stables
        address[] memory originTokensBridgeStables = new address[](4);
        originTokensBridgeStables[0] = NUSD;
        originTokensBridgeStables[1] = DAI;
        originTokensBridgeStables[2] = USDC;
        originTokensBridgeStables[3] = USDT;

        address[] memory destinationTokensBridgeNUSD = new address[](4);
        destinationTokensBridgeNUSD[0] = NUSD;
        destinationTokensBridgeNUSD[1] = DAI;
        destinationTokensBridgeNUSD[2] = USDC;
        destinationTokensBridgeNUSD[3] = USDT;

        address[] memory destinationTokensBridgeUSDC = new address[](1);
        destinationTokensBridgeUSDC[0] = USDC;

        address[] memory destinationTokensBridgeUSDT = new address[](1);
        destinationTokensBridgeUSDT[0] = USDT;

        address[] memory destinationTokensBridgeDAI = new address[](1);
        destinationTokensBridgeDAI[0] = DAI;

        addExpectedBridgeToken(
            BridgeToken({symbol: "nUSD", token: NUSD}),
            originTokensBridgeStables,
            destinationTokensBridgeNUSD
        );
        addExpectedBridgeToken(
            BridgeToken({symbol: "USDC", token: USDC}),
            originTokensBridgeStables,
            destinationTokensBridgeUSDC
        );
        addExpectedBridgeToken(
            BridgeToken({symbol: "USDT", token: USDT}),
            originTokensBridgeStables,
            destinationTokensBridgeUSDT
        );
        addExpectedBridgeToken(
            BridgeToken({symbol: "DAI", token: DAI}),
            originTokensBridgeStables,
            destinationTokensBridgeDAI
        );

        // add synapse bridge module bridge tokens for ETH
        address[] memory originTokensBridgeETH = new address[](2);
        originTokensBridgeETH[0] = WETH;
        originTokensBridgeETH[1] = UniversalTokenLib.ETH_ADDRESS;

        address[] memory destinationTokensBridgeETH = new address[](2);
        destinationTokensBridgeETH[0] = WETH;
        destinationTokensBridgeETH[1] = UniversalTokenLib.ETH_ADDRESS;

        addExpectedBridgeToken(
            BridgeToken({symbol: "nETH", token: WETH}),
            originTokensBridgeETH,
            destinationTokensBridgeETH
        );

        // add synapse cctp module bridge tokens
        address[] memory originTokensCCTP = new address[](4);
        originTokensCCTP[0] = USDC;
        originTokensCCTP[1] = NUSD;
        originTokensCCTP[2] = DAI;
        originTokensCCTP[3] = USDT;

        address[] memory destinationTokensCCTP = new address[](3);
        destinationTokensCCTP[0] = USDC;
        destinationTokensCCTP[1] = DAI;
        destinationTokensCCTP[2] = USDT;

        addExpectedBridgeToken(
            BridgeToken({symbol: "CCTP.USDC", token: USDC}),
            originTokensCCTP,
            destinationTokensCCTP
        );
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

    function testGetOriginAmountOut_inUSDC_outNUSD() public {
        address tokenIn = USDC;
        string memory tokenSymbol = "nUSD";
        uint256 amountIn = getTestAmount(USDC);

        address pool = 0x1116898DdA4015eD8dDefb84b6e8Bc24528Af2d8;
        uint8 indexFrom = 1;
        uint8 indexTo = type(uint8).max;

        uint256[] memory amountsIn = new uint256[](3);
        amountsIn[1] = amountIn;
        uint256 amountOut = _quoter.calculateAddLiquidity(pool, amountsIn);

        DefaultParams memory params = DefaultParams({
            action: Action.AddLiquidity,
            pool: pool,
            tokenIndexFrom: indexFrom,
            tokenIndexTo: indexTo
        });

        SwapQuery memory query = router.getOriginAmountOut(tokenIn, tokenSymbol, amountIn);
        assertEq(query.routerAdapter, address(router));
        assertEq(query.tokenOut, NUSD);
        assertEq(query.minAmountOut, amountOut);
        assertEq(query.deadline, type(uint256).max);
        assertEq(query.rawParams, abi.encode(params));
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
    function testGetOriginAmountOut_inUSDC_outUNI() public {
        address tokenIn = USDC;
        string memory tokenSymbol = "UNI";
        uint256 amountIn = getTestAmount(USDC);

        SwapQuery memory query = router.getOriginAmountOut(tokenIn, tokenSymbol, amountIn);
        assertEq(query.routerAdapter, address(0));
        assertEq(query.tokenOut, address(0));
        assertEq(query.minAmountOut, 0);
        assertEq(query.deadline, 0);
        assertEq(query.rawParams, bytes(""));
    }

    function testGetOriginAmountOut_inUSDC_outUSDC() public {
        address tokenIn = USDC;
        string memory tokenSymbol = "CCTP.USDC";
        uint256 amountIn = getTestAmount(USDC);

        uint256 amountOut = amountIn;
        SwapQuery memory query = router.getOriginAmountOut(tokenIn, tokenSymbol, amountIn);
        assertEq(query.routerAdapter, address(0));
        assertEq(query.tokenOut, USDC);
        assertEq(query.minAmountOut, amountOut);
        assertEq(query.deadline, type(uint256).max);
        assertEq(query.rawParams, bytes(""));
    }

    function testGetOriginAmountOut_inDAI_outUSDC() public {
        address tokenIn = DAI;
        string memory tokenSymbol = "CCTP.USDC";
        uint256 amountIn = getTestAmount(DAI);

        address pool = 0x1116898DdA4015eD8dDefb84b6e8Bc24528Af2d8;
        uint8 indexFrom = 0;
        uint8 indexTo = 1;
        uint256 amountOut = calculateSwap(pool, indexFrom, indexTo, amountIn);

        DefaultParams memory params = DefaultParams({
            action: Action.Swap,
            pool: pool,
            tokenIndexFrom: indexFrom,
            tokenIndexTo: indexTo
        });

        SwapQuery memory query = router.getOriginAmountOut(tokenIn, tokenSymbol, amountIn);
        assertEq(query.routerAdapter, address(router));
        assertEq(query.tokenOut, USDC);
        assertEq(query.minAmountOut, amountOut);
        assertEq(query.deadline, type(uint256).max);
        assertEq(query.rawParams, abi.encode(params));
    }

    function testGetOriginAmountOut_inUSDC_outUSDC_overMaxBridgedAmount() public {
        address tokenIn = USDC;
        string memory tokenSymbol = "CCTP.USDC";
        uint256 amountIn = 1100000000000;

        SwapQuery memory query = router.getOriginAmountOut(tokenIn, tokenSymbol, amountIn);
        assertEq(query.routerAdapter, address(0));
        assertEq(query.tokenOut, address(0));
        assertEq(query.minAmountOut, 0);
        assertEq(query.deadline, 0);
        assertEq(query.rawParams, bytes(""));
    }

    function testGetOriginAmountOut_inETH_outNETH() public {
        address tokenIn = UniversalTokenLib.ETH_ADDRESS;
        string memory tokenSymbol = "nETH";
        uint256 amountIn = 10e18;
        uint256 amountOut = amountIn;

        DefaultParams memory params = DefaultParams({
            action: Action.HandleEth,
            pool: address(0),
            tokenIndexFrom: type(uint8).max,
            tokenIndexTo: type(uint8).max
        });

        SwapQuery memory query = router.getOriginAmountOut(tokenIn, tokenSymbol, amountIn);
        assertEq(query.routerAdapter, address(router));
        assertEq(query.tokenOut, WETH);
        assertEq(query.minAmountOut, amountOut);
        assertEq(query.deadline, type(uint256).max);
        assertEq(query.rawParams, abi.encode(params));
    }

    function testGetOriginAmountOut_inWETH_outNETH() public {
        address tokenIn = WETH;
        string memory tokenSymbol = "nETH";
        uint256 amountIn = 10e18;
        uint256 amountOut = amountIn;

        SwapQuery memory query = router.getOriginAmountOut(tokenIn, tokenSymbol, amountIn);
        assertEq(query.routerAdapter, address(0));
        assertEq(query.tokenOut, WETH);
        assertEq(query.minAmountOut, amountOut);
        assertEq(query.deadline, type(uint256).max);
        assertEq(query.rawParams, bytes(""));
    }

    function testGetDestinationAmountOut_inNUSD_outNUSD() public {
        uint256 amountIn = 100000 * 1e18; // @dev need larger amount to be larger than fee amount
        DestRequest memory request = DestRequest({symbol: "nUSD", amountIn: amountIn});

        address tokenOut = NUSD;
        uint256 fee = (amountIn * 0.0012e10) / 10**10;
        uint256 amountInLessBridgeFees = amountIn - fee;
        uint256 amountOut = amountInLessBridgeFees;

        SwapQuery memory query = router.getDestinationAmountOut(request, tokenOut);
        assertEq(query.routerAdapter, address(0));
        assertEq(query.tokenOut, tokenOut);
        assertEq(query.minAmountOut, amountOut);
        assertEq(query.deadline, type(uint256).max);
        assertEq(query.rawParams, bytes(""));
    }

    function testGetDestinationAmountOut_inNUSD_outUSDC() public {
        uint256 amountIn = 100000 * 1e18; // @dev need larger amount to be larger than fee amount
        DestRequest memory request = DestRequest({symbol: "nUSD", amountIn: amountIn});

        address tokenOut = USDC;
        uint256 fee = (amountIn * 0.0012e10) / 10**10;
        uint256 amountInLessBridgeFees = amountIn - fee;

        address pool = 0x1116898DdA4015eD8dDefb84b6e8Bc24528Af2d8;
        uint8 indexFrom = type(uint8).max;
        uint8 indexTo = 1;

        uint256 amountOut = _quoter.calculateWithdrawOneToken(pool, amountInLessBridgeFees, 1);
        DefaultParams memory params = DefaultParams({
            action: Action.RemoveLiquidity,
            pool: pool,
            tokenIndexFrom: indexFrom,
            tokenIndexTo: indexTo
        });

        SwapQuery memory query = router.getDestinationAmountOut(request, tokenOut);
        assertEq(query.routerAdapter, address(router));
        assertEq(query.tokenOut, tokenOut);
        assertEq(query.minAmountOut, amountOut);
        assertEq(query.deadline, type(uint256).max);
        assertEq(query.rawParams, abi.encode(params));
    }

    function testGetDestinationAmountOut_inNETH_outWETH() public {
        uint256 amountIn = 10000 * 1e18; // @dev need larger amount to be larger than fee amount
        DestRequest memory request = DestRequest({symbol: "nETH", amountIn: amountIn});

        address tokenOut = WETH;
        uint256 fee = (amountIn * 0.001e10) / 10**10;
        uint256 amountInLessBridgeFees = amountIn - fee;
        uint256 amountOut = amountInLessBridgeFees;

        SwapQuery memory query = router.getDestinationAmountOut(request, tokenOut);
        assertEq(query.routerAdapter, address(0));
        assertEq(query.tokenOut, tokenOut);
        assertEq(query.minAmountOut, amountOut);
        assertEq(query.deadline, type(uint256).max);
        assertEq(query.rawParams, bytes(""));
    }

    function testGetDestinationAmountOut_inNETH_outETH() public {
        uint256 amountIn = 10000 * 1e18; // @dev need larger amount to be larger than fee amount
        DestRequest memory request = DestRequest({symbol: "nETH", amountIn: amountIn});

        address tokenOut = UniversalTokenLib.ETH_ADDRESS;
        uint256 fee = (amountIn * 0.001e10) / 10**10;
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

    /// @dev UNI not supported so amount out should produce zero
    function testGetDestinationAmountOut_inNUSD_outUNI() public {
        uint256 amountIn = 10000 * 1e18; // @dev need larger amount to be larger than fee amount
        DestRequest memory request = DestRequest({symbol: "nUSD", amountIn: amountIn});

        address tokenOut = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;
        SwapQuery memory query = router.getDestinationAmountOut(request, tokenOut);
        assertEq(query.routerAdapter, address(0));
        assertEq(query.tokenOut, tokenOut);
        assertEq(query.minAmountOut, 0);
        assertEq(query.deadline, 0);
        assertEq(query.rawParams, bytes(""));
    }

    function testGetDestinationAmountOut_inNUSD_outUSDC_amountInLessThanFee() public {
        uint256 amountIn = getTestAmount(NUSD);
        DestRequest memory request = DestRequest({symbol: "nUSD", amountIn: amountIn});

        address tokenOut = USDC;
        uint256 fee = (amountIn * 0.001e10) / 10**10;
        if (fee < 30e18) fee = 30e18; // @dev nUSD has min of 30 nUSD
        assertTrue(fee >= amountIn);

        SwapQuery memory query = router.getDestinationAmountOut(request, tokenOut);
        assertEq(query.routerAdapter, address(0));
        assertEq(query.tokenOut, address(0));
        assertEq(query.minAmountOut, 0);
        assertEq(query.deadline, 0);
        assertEq(query.rawParams, bytes(""));
    }

    function testSynapseBridge_ethereumToArbitrum_inUSDC_outNUSD() public {
        address module = expectedModules[0];

        uint256 amountIn = getTestAmount(USDC);
        address pool = 0x1116898DdA4015eD8dDefb84b6e8Bc24528Af2d8;

        DefaultParams memory params = DefaultParams({
            action: Action.AddLiquidity,
            pool: pool, // stableswap pool on arbitrum
            tokenIndexFrom: 1,
            tokenIndexTo: type(uint8).max
        });
        SwapQuery memory originQuery = SwapQuery({
            routerAdapter: address(router),
            tokenOut: NUSD,
            minAmountOut: 0,
            deadline: type(uint256).max,
            rawParams: abi.encode(params)
        });
        SwapQuery memory destQuery;

        uint256[] memory amountsIn = new uint256[](3);
        amountsIn[1] = amountIn;
        uint256 amount = _quoter.calculateAddLiquidity(pool, amountsIn);

        depositEvent = DepositEvent({to: recipient, chainId: 42161, token: NUSD, amount: amount});
        initiateBridge(
            expectDepositEvent,
            42161, // arbitrum
            module,
            USDC,
            originQuery,
            destQuery
        );
    }

    function testSynapseBridge_ethereumToArbitrum_inUSDC_outUSDCe() public {
        address module = expectedModules[0];

        uint256 amountIn = getTestAmount(USDC);
        address pool = 0x1116898DdA4015eD8dDefb84b6e8Bc24528Af2d8;

        DefaultParams memory originParams = DefaultParams({
            action: Action.AddLiquidity,
            pool: pool, // stableswap pool on arbitrum
            tokenIndexFrom: 1,
            tokenIndexTo: type(uint8).max
        });
        SwapQuery memory originQuery = SwapQuery({
            routerAdapter: address(router),
            tokenOut: NUSD,
            minAmountOut: 0,
            deadline: type(uint256).max,
            rawParams: abi.encode(originParams)
        });

        DefaultParams memory destParams = DefaultParams({
            action: Action.Swap,
            pool: 0x9Dd329F5411466d9e0C488fF72519CA9fEf0cb40,
            tokenIndexFrom: 0,
            tokenIndexTo: 1
        });
        SwapQuery memory destQuery = SwapQuery({
            routerAdapter: 0x9Dd329F5411466d9e0C488fF72519CA9fEf0cb40,
            tokenOut: 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8, // USDCe on arbitrum
            minAmountOut: 0,
            deadline: type(uint256).max,
            rawParams: abi.encode(destParams)
        });

        uint256[] memory amountsIn = new uint256[](3);
        amountsIn[1] = amountIn;
        uint256 amount = _quoter.calculateAddLiquidity(pool, amountsIn);

        depositAndSwapEvent = DepositAndSwapEvent({
            to: recipient,
            chainId: 42161,
            token: NUSD,
            amount: amount,
            tokenIndexFrom: 0,
            tokenIndexTo: 1,
            minDy: 0,
            deadline: type(uint256).max
        });
        initiateBridge(
            expectDepositAndSwapEvent,
            42161, // arbitrum
            module,
            USDC,
            originQuery,
            destQuery
        );
    }

    function testSynapseBridge_ethereumToArbitrum_inWETH_outNETH() public {
        address module = expectedModules[0];

        uint256 amountIn = getTestAmount(WETH);
        SwapQuery memory originQuery;
        SwapQuery memory destQuery;

        depositEvent = DepositEvent({to: recipient, chainId: 42161, token: WETH, amount: amountIn});
        initiateBridge(
            expectDepositEvent,
            42161, // arbitrum
            module,
            WETH,
            originQuery,
            destQuery
        );
    }

    function testSynapseBridge_ethereumToArbitrum_inWETH_outWETH() public {
        address module = expectedModules[0];

        uint256 amountIn = getTestAmount(WETH);
        SwapQuery memory originQuery;

        address pool = 0xa067668661C84476aFcDc6fA5D758C4c01C34352;
        DefaultParams memory params = DefaultParams({
            action: Action.Swap,
            pool: pool,
            tokenIndexFrom: 0,
            tokenIndexTo: 1
        });
        SwapQuery memory destQuery = SwapQuery({
            routerAdapter: pool, // placeholder
            tokenOut: 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1, // WETH on arbitrum
            minAmountOut: 0,
            deadline: type(uint256).max,
            rawParams: abi.encode(params)
        });

        depositAndSwapEvent = DepositAndSwapEvent({
            to: recipient,
            chainId: 42161,
            token: WETH,
            amount: amountIn,
            tokenIndexFrom: 0,
            tokenIndexTo: 1,
            minDy: 0,
            deadline: type(uint256).max
        });
        initiateBridge(
            expectDepositAndSwapEvent,
            42161, // arbitrum
            module,
            WETH,
            originQuery,
            destQuery
        );
    }

    function testSynapseBridge_ethereumToArbitrum_inETH_outNETH() public {
        address module = expectedModules[0];

        uint256 amountIn = getTestAmount(WETH);

        DefaultParams memory params = DefaultParams({
            action: Action.HandleEth,
            pool: address(0),
            tokenIndexFrom: type(uint8).max,
            tokenIndexTo: type(uint8).max
        });
        SwapQuery memory originQuery = SwapQuery({
            routerAdapter: address(router),
            tokenOut: WETH,
            minAmountOut: 0,
            deadline: type(uint256).max,
            rawParams: abi.encode(params)
        });
        SwapQuery memory destQuery;

        depositEvent = DepositEvent({to: recipient, chainId: 42161, token: WETH, amount: amountIn});
        initiateBridge(
            expectDepositEvent,
            42161, // arbitrum
            module,
            UniversalTokenLib.ETH_ADDRESS,
            originQuery,
            destQuery
        );
    }

    function testSynapseBridge_ethereumToArbitrum_inETH_outWETH() public {
        address module = expectedModules[0];
        uint256 amountIn = getTestAmount(WETH);

        DefaultParams memory originParams = DefaultParams({
            action: Action.HandleEth,
            pool: address(0),
            tokenIndexFrom: type(uint8).max,
            tokenIndexTo: type(uint8).max
        });
        SwapQuery memory originQuery = SwapQuery({
            routerAdapter: address(router),
            tokenOut: WETH,
            minAmountOut: 0,
            deadline: type(uint256).max,
            rawParams: abi.encode(originParams)
        });

        address destPool = 0xa067668661C84476aFcDc6fA5D758C4c01C34352;
        DefaultParams memory destParams = DefaultParams({
            action: Action.Swap,
            pool: destPool,
            tokenIndexFrom: 0,
            tokenIndexTo: 1
        });
        SwapQuery memory destQuery = SwapQuery({
            routerAdapter: destPool, // placeholder
            tokenOut: 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1, // WETH on arbitrum
            minAmountOut: 0,
            deadline: type(uint256).max,
            rawParams: abi.encode(destParams)
        });

        depositAndSwapEvent = DepositAndSwapEvent({
            to: recipient,
            chainId: 42161,
            token: WETH,
            amount: amountIn,
            tokenIndexFrom: 0,
            tokenIndexTo: 1,
            minDy: 0,
            deadline: type(uint256).max
        });
        initiateBridge(
            expectDepositAndSwapEvent,
            42161, // arbitrum
            module,
            UniversalTokenLib.ETH_ADDRESS,
            originQuery,
            destQuery
        );
    }

    function testSynapseCCTP_ethereumToArbitrum_inUSDC_outUSDC() public {
        address module = expectedModules[1]; // Synapse CCTP module

        SwapQuery memory originQuery;
        SwapQuery memory destQuery;

        uint32 requestVersion = getRequestVersion(true);
        bytes memory swapParams = bytes("");

        uint32 originDomain = 0;
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
            42161, // mainnet
            module,
            USDC,
            originQuery,
            destQuery
        );
    }

    function testSynapseCCTP_ethereumToArbitrum_inDAI_outUSDC() public {
        address module = expectedModules[1]; // Synapse CCTP module

        address pool = 0x1116898DdA4015eD8dDefb84b6e8Bc24528Af2d8;
        uint8 indexFrom = 0;
        uint8 indexTo = 1;

        SwapQuery memory originQuery;
        {
            DefaultParams memory originParams = DefaultParams({
                action: Action.Swap,
                pool: pool,
                tokenIndexFrom: indexFrom,
                tokenIndexTo: indexTo
            });
            originQuery = SwapQuery({
                routerAdapter: address(router),
                tokenOut: USDC,
                minAmountOut: 0,
                deadline: type(uint256).max,
                rawParams: abi.encode(originParams)
            });
        }
        uint256 amountIn = calculateSwap(pool, indexFrom, indexTo, getTestAmount(DAI));

        SwapQuery memory destQuery;

        uint32 requestVersion = getRequestVersion(true);
        uint32 originDomain = 0;
        uint32 destDomain = 3;
        uint64 nonce = getNextAvailableNonce();

        bytes memory formattedRequest = formatRequest(
            requestVersion,
            originDomain,
            nonce,
            USDC,
            amountIn,
            recipient,
            bytes("")
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
            42161, // mainnet
            module,
            DAI,
            originQuery,
            destQuery
        );
    }

    function testSynapseCCTP_ethereumToArbitrum_inUSDC_outUSDCe() public {
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

        uint32 originDomain = 0;
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

    function testSynapseCCTP_ethereumToArbitrum_inDAI_outUSDCe() public {
        address module = expectedModules[1]; // Synapse CCTP module
        address pool = 0x1116898DdA4015eD8dDefb84b6e8Bc24528Af2d8;

        SwapQuery memory originQuery;
        {
            uint8 indexFrom = 0;
            uint8 indexTo = 1;

            DefaultParams memory originParams = DefaultParams({
                action: Action.Swap,
                pool: pool,
                tokenIndexFrom: indexFrom,
                tokenIndexTo: indexTo
            });
            originQuery = SwapQuery({
                routerAdapter: address(router),
                tokenOut: USDC,
                minAmountOut: 0,
                deadline: type(uint256).max,
                rawParams: abi.encode(originParams)
            });
        }
        uint256 amountIn = calculateSwap(pool, 0, 1, getTestAmount(DAI));

        SwapQuery memory destQuery;
        {
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

        uint32 originDomain = 0;
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
            42161, // mainnet
            module,
            DAI,
            originQuery,
            destQuery
        );
    }
}
