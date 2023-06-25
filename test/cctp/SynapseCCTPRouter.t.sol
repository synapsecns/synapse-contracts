// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// prettier-ignore
import {
    Action,
    BridgeToken,
    DefaultParams,
    DestRequest,
    SwapQuery,
    SynapseCCTPRouter
} from "../../contracts/cctp/SynapseCCTPRouter.sol";
import {BaseCCTPTest, RequestLib} from "./BaseCCTP.t.sol";

contract SynapseCCTPRouterTest is BaseCCTPTest {
    // 1M USDC
    uint256 public constant MAX_BURN_AMOUNT = 10**6 * 10**6;
    string public constant SYMBOL_USDC = "CCTP.MockC";

    mapping(uint32 => SynapseCCTPRouter) public cctpRouters;

    function setUp() public virtual override {
        super.setUp();
        deployCCTPRouter(DOMAIN_ETH);
        deployCCTPRouter(DOMAIN_AVAX);
        setBurnLimitPerMessage(DOMAIN_ETH);
        setBurnLimitPerMessage(DOMAIN_AVAX);
    }

    function setBurnLimitPerMessage(uint32 domain) public {
        cctpSetups[domain].tokenMinter.setBurnLimitPerMessage(
            address(cctpSetups[domain].mintBurnToken),
            MAX_BURN_AMOUNT
        );
    }

    function deployCCTPRouter(uint32 domain) internal {
        cctpRouters[domain] = new SynapseCCTPRouter(address(synapseCCTPs[domain]));
    }

    // ════════════════════════════════════════ TESTS: GET CONNECTED TOKENS ════════════════════════════════════════════

    function testGetConnectedBridgeTokensForUSDC() public {
        address usdc = address(cctpSetups[DOMAIN_ETH].mintBurnToken);
        BridgeToken[] memory tokens = cctpRouters[DOMAIN_ETH].getConnectedBridgeTokens(usdc);
        assertEq(tokens.length, 1);
        assertEq(tokens[0].token, usdc);
        assertEq(tokens[0].symbol, SYMBOL_USDC);
    }

    function testGetConnectedBridgeTokensForPoolStable() public {
        address usdc = address(cctpSetups[DOMAIN_ETH].mintBurnToken);
        address usdt = address(poolSetups[DOMAIN_ETH].token);
        BridgeToken[] memory tokens = cctpRouters[DOMAIN_ETH].getConnectedBridgeTokens(usdt);
        assertEq(tokens.length, 1);
        assertEq(tokens[0].token, usdc);
        assertEq(tokens[0].symbol, SYMBOL_USDC);
    }

    // ═══════════════════════════════════════ TESTS: GET ORIGIN AMOUNT OUT ════════════════════════════════════════════

    function testGetOriginAmountOutForUSDC() public {
        address usdc = address(cctpSetups[DOMAIN_ETH].mintBurnToken);
        uint256 amountIn = 10**6;
        string[] memory symbols = new string[](1);
        symbols[0] = SYMBOL_USDC;
        SwapQuery[] memory queries = cctpRouters[DOMAIN_ETH].getOriginAmountOut(usdc, symbols, amountIn);
        assertEq(queries.length, 1);
        checkSameTokenQuery(queries[0], usdc, amountIn);
    }

    function testGetOriginAmountOutForUSDCWhenExactlyBurnLimit() public {
        address usdc = address(cctpSetups[DOMAIN_ETH].mintBurnToken);
        uint256 amountIn = MAX_BURN_AMOUNT;
        string[] memory symbols = new string[](1);
        symbols[0] = SYMBOL_USDC;
        SwapQuery[] memory queries = cctpRouters[DOMAIN_ETH].getOriginAmountOut(usdc, symbols, amountIn);
        assertEq(queries.length, 1);
        checkSameTokenQuery(queries[0], usdc, amountIn);
    }

    function testGetOriginAmountOutForUSDCWhenOverBurnLimit() public {
        address usdc = address(cctpSetups[DOMAIN_ETH].mintBurnToken);
        uint256 amountIn = MAX_BURN_AMOUNT + 1;
        string[] memory symbols = new string[](1);
        symbols[0] = SYMBOL_USDC;
        SwapQuery[] memory queries = cctpRouters[DOMAIN_ETH].getOriginAmountOut(usdc, symbols, amountIn);
        assertEq(queries.length, 1);
        checkNoPathQuery(queries[0], usdc);
    }

    function testGetOriginAmountOutForPoolStable() public {
        address usdc = address(cctpSetups[DOMAIN_ETH].mintBurnToken);
        address usdt = address(poolSetups[DOMAIN_ETH].token);
        uint8 tokenIndexFrom = 1;
        uint8 tokenIndexTo = 0;
        uint256 amountIn = 10**6;
        uint256 expectedAmountOut = poolSetups[DOMAIN_ETH].pool.calculateSwap(tokenIndexFrom, tokenIndexTo, amountIn);
        string[] memory symbols = new string[](1);
        symbols[0] = SYMBOL_USDC;
        SwapQuery[] memory queries = cctpRouters[DOMAIN_ETH].getOriginAmountOut(usdt, symbols, amountIn);
        assertEq(queries.length, 1);
        checkSwapQuery(
            queries[0],
            DOMAIN_ETH,
            usdc,
            expectedAmountOut,
            DefaultParams({
                action: Action.Swap,
                pool: address(poolSetups[DOMAIN_ETH].pool),
                tokenIndexFrom: tokenIndexFrom,
                tokenIndexTo: tokenIndexTo
            })
        );
    }

    function testGetOriginAmountOutForPoolStableWhenExactlyBurnLimit() public {
        address pool = address(poolSetups[DOMAIN_ETH].pool);
        // Make sure pool has more than enough tokens to swap
        cctpSetups[DOMAIN_ETH].mintBurnToken.mintPublic(pool, 1000 * MAX_BURN_AMOUNT);
        poolSetups[DOMAIN_ETH].token.mint(pool, 1000 * MAX_BURN_AMOUNT);
        // Find out how much tokens result in MAX_BURN_AMOUNT + 1 USDC using binary search
        uint256 amountL = 0;
        uint256 amountR = 10 * MAX_BURN_AMOUNT;
        while (amountR - amountL > 1) {
            uint256 amountM = (amountL + amountR) / 2;
            // USDT (1) -> USDC (0) swap
            uint256 amountOut = poolSetups[DOMAIN_ETH].pool.calculateSwap(1, 0, amountM);
            if (amountOut >= MAX_BURN_AMOUNT + 1) {
                amountR = amountM;
            } else {
                amountL = amountM;
            }
        }
        // Sanity check the result
        require(poolSetups[DOMAIN_ETH].pool.calculateSwap(1, 0, amountR) > MAX_BURN_AMOUNT, "amountR");
        require(poolSetups[DOMAIN_ETH].pool.calculateSwap(1, 0, amountL) == MAX_BURN_AMOUNT, "amountL");
        // Check swap that results in MAX_BURN_AMOUNT USDC
        address usdc = address(cctpSetups[DOMAIN_ETH].mintBurnToken);
        address usdt = address(poolSetups[DOMAIN_ETH].token);
        string[] memory symbols = new string[](1);
        symbols[0] = SYMBOL_USDC;
        SwapQuery[] memory queries = cctpRouters[DOMAIN_ETH].getOriginAmountOut(usdt, symbols, amountL);
        assertEq(queries.length, 1);
        checkSwapQuery(
            queries[0],
            DOMAIN_ETH,
            usdc,
            MAX_BURN_AMOUNT,
            DefaultParams({
                action: Action.Swap,
                pool: address(poolSetups[DOMAIN_ETH].pool),
                tokenIndexFrom: 1,
                tokenIndexTo: 0
            })
        );
    }

    function testGetOriginAmountOutForPoolStableWhenOverBurnLimit() public {
        address pool = address(poolSetups[DOMAIN_ETH].pool);
        // Make sure pool has more than enough tokens to swap
        cctpSetups[DOMAIN_ETH].mintBurnToken.mintPublic(pool, 1000 * MAX_BURN_AMOUNT);
        poolSetups[DOMAIN_ETH].token.mint(pool, 1000 * MAX_BURN_AMOUNT);
        // Find out how much tokens result in MAX_BURN_AMOUNT + 1 USDC using binary search
        uint256 amountL = 0;
        uint256 amountR = 10 * MAX_BURN_AMOUNT;
        while (amountR - amountL > 1) {
            uint256 amountM = (amountL + amountR) / 2;
            // USDT (1) -> USDC (0) swap
            uint256 amountOut = poolSetups[DOMAIN_ETH].pool.calculateSwap(1, 0, amountM);
            if (amountOut >= MAX_BURN_AMOUNT + 1) {
                amountR = amountM;
            } else {
                amountL = amountM;
            }
        }
        // Sanity check the result
        require(poolSetups[DOMAIN_ETH].pool.calculateSwap(1, 0, amountR) > MAX_BURN_AMOUNT, "amountR");
        require(poolSetups[DOMAIN_ETH].pool.calculateSwap(1, 0, amountL) <= MAX_BURN_AMOUNT, "amountL");
        // Now we know that amountR is the smallest amount of USDT that results in MAX_BURN_AMOUNT + 1 USDC
        address usdc = address(cctpSetups[DOMAIN_ETH].mintBurnToken);
        address usdt = address(poolSetups[DOMAIN_ETH].token);
        string[] memory symbols = new string[](1);
        symbols[0] = SYMBOL_USDC;
        SwapQuery[] memory queries = cctpRouters[DOMAIN_ETH].getOriginAmountOut(usdt, symbols, amountR);
        assertEq(queries.length, 1);
        checkNoPathQuery(queries[0], usdc);
    }

    function testGetOriginAmountOutForUnknownToken() public {
        address unknownToken = makeAddr("Unknown");
        address usdc = address(cctpSetups[DOMAIN_ETH].mintBurnToken);
        uint256 amountIn = 10**6;
        string[] memory symbols = new string[](1);
        symbols[0] = SYMBOL_USDC;
        SwapQuery[] memory queries = cctpRouters[DOMAIN_ETH].getOriginAmountOut(unknownToken, symbols, amountIn);
        assertEq(queries.length, 1);
        checkNoPathQuery(queries[0], usdc);
    }

    function testGetOriginAmountOutForUnknownSymbol() public {
        address usdc = address(cctpSetups[DOMAIN_ETH].mintBurnToken);
        uint256 amountIn = 10**6;
        string[] memory symbols = new string[](1);
        // Real symbol is "CCTP.MockC"
        symbols[0] = "MockC";
        SwapQuery[] memory queries = cctpRouters[DOMAIN_ETH].getOriginAmountOut(usdc, symbols, amountIn);
        assertEq(queries.length, 1);
        checkNoPathQuery(queries[0], address(0));
    }

    // ═════════════════════════════════════ TESTS: GET DESTINATION AMOUNT OUT ═════════════════════════════════════════

    function testGetDestinationAmountOutForUSDC() public {
        uint256 amountIn = 10**7;
        address usdc = address(cctpSetups[DOMAIN_ETH].mintBurnToken);
        DestRequest[] memory requests = new DestRequest[](1);
        requests[0].symbol = SYMBOL_USDC;
        requests[0].amountIn = amountIn;
        uint256 expectedFees = synapseCCTPs[DOMAIN_ETH].calculateFeeAmount({
            token: usdc,
            amount: amountIn,
            isSwap: false
        });
        uint256 expectedAmountOut = amountIn - expectedFees;
        SwapQuery[] memory queries = cctpRouters[DOMAIN_ETH].getDestinationAmountOut(requests, usdc);
        assertEq(queries.length, 1);
        checkSameTokenQuery(queries[0], usdc, expectedAmountOut);
    }

    function testGetDestinationAmountOutForUSDCWhenUnderBaseFee() public {
        address usdc = address(cctpSetups[DOMAIN_ETH].mintBurnToken);
        // (relayerFee, baseFee, swapFee, minFee)
        (, uint256 amountIn, , ) = synapseCCTPs[DOMAIN_ETH].feeStructures(usdc);
        DestRequest[] memory requests = new DestRequest[](1);
        requests[0].symbol = SYMBOL_USDC;
        requests[0].amountIn = amountIn;
        SwapQuery[] memory queries = cctpRouters[DOMAIN_ETH].getDestinationAmountOut(requests, usdc);
        assertEq(queries.length, 1);
        checkNoPathQuery(queries[0], usdc);
    }

    function testGetDestinationAmountOutForPoolStable() public {
        uint256 amountIn = 10**7;
        address usdc = address(cctpSetups[DOMAIN_ETH].mintBurnToken);
        address usdt = address(poolSetups[DOMAIN_ETH].token);
        DestRequest[] memory requests = new DestRequest[](1);
        requests[0].symbol = SYMBOL_USDC;
        requests[0].amountIn = amountIn;
        uint256 expectedFees = synapseCCTPs[DOMAIN_ETH].calculateFeeAmount({
            token: usdc,
            amount: amountIn,
            isSwap: true
        });
        uint8 tokenIndexFrom = 0;
        uint8 tokenIndexTo = 1;
        uint256 expectedAmountOut = poolSetups[DOMAIN_ETH].pool.calculateSwap(
            tokenIndexFrom,
            tokenIndexTo,
            amountIn - expectedFees
        );
        SwapQuery[] memory queries = cctpRouters[DOMAIN_ETH].getDestinationAmountOut(requests, usdt);
        assertEq(queries.length, 1);
        checkSwapQuery(
            queries[0],
            DOMAIN_ETH,
            usdt,
            expectedAmountOut,
            DefaultParams({
                action: Action.Swap,
                pool: address(poolSetups[DOMAIN_ETH].pool),
                tokenIndexFrom: tokenIndexFrom,
                tokenIndexTo: tokenIndexTo
            })
        );
    }

    function testGetDestinationAmountOutForPoolStableWhenUnderSwapFee() public {
        address usdc = address(cctpSetups[DOMAIN_ETH].mintBurnToken);
        address usdt = address(poolSetups[DOMAIN_ETH].token);
        // (relayerFee, baseFee, swapFee, minFee)
        (, , uint256 amountIn, ) = synapseCCTPs[DOMAIN_ETH].feeStructures(usdc);
        DestRequest[] memory requests = new DestRequest[](1);
        requests[0].symbol = SYMBOL_USDC;
        requests[0].amountIn = amountIn;
        SwapQuery[] memory queries = cctpRouters[DOMAIN_ETH].getDestinationAmountOut(requests, usdt);
        assertEq(queries.length, 1);
        checkNoPathQuery(queries[0], usdt);
    }

    function testGetDestinationAmountOutForUnknownToken() public {
        address unknownToken = makeAddr("Unknown");
        DestRequest[] memory requests = new DestRequest[](1);
        requests[0].symbol = SYMBOL_USDC;
        requests[0].amountIn = 10 * 7;
        SwapQuery[] memory queries = cctpRouters[DOMAIN_ETH].getDestinationAmountOut(requests, unknownToken);
        assertEq(queries.length, 1);
        checkNoPathQuery(queries[0], unknownToken);
    }

    function testGetDestinationAmountOutForUnknownSymbol() public {
        address usdc = address(cctpSetups[DOMAIN_ETH].mintBurnToken);
        DestRequest[] memory requests = new DestRequest[](1);
        // Real symbol is "CCTP.MockC"
        requests[0].symbol = "MockC";
        requests[0].amountIn = 10 * 7;
        SwapQuery[] memory queries = cctpRouters[DOMAIN_ETH].getDestinationAmountOut(requests, usdc);
        assertEq(queries.length, 1);
        checkNoPathQuery(queries[0], usdc);
    }

    // ══════════════════════════════════════════════════ HELPERS ══════════════════════════════════════════════════════

    function checkSwapQuery(
        SwapQuery memory query,
        uint32 domain,
        address expectedTokenOut,
        uint256 expectedAmountOut,
        DefaultParams memory expectedParams
    ) public {
        assertEq(query.routerAdapter, address(cctpRouters[domain]));
        assertEq(query.tokenOut, expectedTokenOut);
        assertEq(query.minAmountOut, expectedAmountOut);
        assertEq(query.deadline, type(uint256).max);
        assertEq(query.rawParams, abi.encode(expectedParams));
    }

    function checkSameTokenQuery(
        SwapQuery memory query,
        address expectedTokenOut,
        uint256 expectedAmountOut
    ) public {
        assertEq(query.routerAdapter, address(0));
        assertEq(query.tokenOut, expectedTokenOut);
        assertEq(query.minAmountOut, expectedAmountOut);
        assertEq(query.deadline, type(uint256).max);
        assertEq(query.rawParams, "");
    }

    function checkNoPathQuery(SwapQuery memory query, address expectedTokenOut) public {
        assertEq(query.routerAdapter, address(0));
        assertEq(query.tokenOut, expectedTokenOut);
        assertEq(query.minAmountOut, 0);
        assertEq(query.deadline, 0);
        assertEq(query.rawParams, "");
    }
}
