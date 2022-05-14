// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "../../utils/DefaultVaultForkedTest.t.sol";

contract VaultTestEth is DefaultVaultForkedTest {
    BasicTokens internal basicTokens =
        BasicTokens({
            wgas: payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2),
            weth: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
            neth: address(0),
            nusd: 0x1B84765dE8B7566e4cEAF4D0fD3c5aF52D3DdE4F,
            syn: 0x0f2D719407FdBeFF09D87557AbB7232601FD9F29
        });

    struct TestTokens {
        address dai;
        address usdc;
        address usdt;
        address wbtc;
        address frax;
    }

    TestTokens internal testTokens =
        TestTokens({
            dai: 0x6B175474E89094C44Da98b954EedeAC495271d0F,
            usdc: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48,
            usdt: 0xdAC17F958D2ee523a2206206994597C13D831ec7,
            wbtc: 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599,
            frax: 0x853d955aCEf822Db058eb8505911ED77F175b99e
        });

    TestSetup internal ethConfig =
        TestSetup({
            needsUpgrade: true,
            tokens: [basicTokens.weth, basicTokens.nusd],
            oldBridgeAddress: 0x2796317b0fF8538F253012862c06787Adfb8cEb6,
            bridgeMaxSwaps: 2,
            maxSwaps: 4,
            maxGasForSwap: 10**6,
            wgas: basicTokens.wgas
        });

    string public constant SYNAPSE_NUSD = "Synapse nUSD";

    string public constant UNISWAP = "Uniswap";
    string public constant SUSHISWAP = "Sushiswap";

    string public constant CURVE_3POOL = "Curve 3pool";
    string public constant CURVE_AAVE = "Curve Aave 3pool";
    string public constant CURVE_FRAX = "Curve FRAX";
    string public constant CURVE_TRICRYPTO = "Curve TriCrypto";

    constructor() DefaultVaultForkedTest(ethConfig) {
        kappas = new bytes32[](4);
        kappas[0] = 0x58b29a4cf220b60a7e46b76b9831686c0bfbdbfea19721ef8f2192ba28514485;
        kappas[1] = 0x3745754e018ed57dce0feda8b027f04b7e1369e7f74f1a247f5f7352d519021c;
        kappas[2] = 0xea5bc18a60d2f1b9ba5e5f8bfef3cd112c3b1a1ef74a0de8e5989441b1722524;
        kappas[3] = 0x1d4f3f6ed7690f1e5c1ff733d2040daa12fa484b3acbf37122ff334b46cf8b6d;

        dstChainIdsEVM = new uint256[](2);
        dstChainIdsEVM[0] = 56;
        dstChainIdsEVM[1] = 250;

        tokenFixedTotalSupply = basicTokens.nusd;
    }

    function _setupAdapters() internal override {
        // Mark Synapse nUSD Adapter as potentially "underquoting",
        // until Quoter is fixed to avoid using it twice in path
        _deployAdapter(
            "SynapseBaseMainnetAdapter",
            SYNAPSE_NUSD,
            abi.encode(SYNAPSE_NUSD, 0, 0x1116898DdA4015eD8dDefb84b6e8Bc24528Af2d8),
            abi.encode(32, 4, testTokens.dai, testTokens.usdc, testTokens.usdt, basicTokens.nusd),
            true
        );

        _deployAdapter(
            "UniswapV2Adapter",
            UNISWAP,
            abi.encode(
                UNISWAP,
                0,
                0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f,
                0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f,
                30
            ),
            abi.encode(
                32,
                6,
                basicTokens.weth,
                testTokens.dai,
                testTokens.usdc,
                testTokens.usdt,
                testTokens.wbtc,
                testTokens.frax
            )
        );

        _deployAdapter(
            "UniswapV2Adapter",
            SUSHISWAP,
            abi.encode(
                SUSHISWAP,
                0,
                0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac,
                0xe18a34eb0e04b04f7a0ac29a6e80748dca96319b42c54d679cb821dca90c6303,
                30
            ),
            abi.encode(
                32,
                7,
                basicTokens.weth,
                basicTokens.syn,
                testTokens.dai,
                testTokens.usdc,
                testTokens.usdt,
                testTokens.wbtc,
                testTokens.frax
            )
        );

        // Curve Adapter can underquote by 1 wei sometimes
        _deployAdapter(
            "CurveBaseAdapter",
            CURVE_3POOL,
            abi.encode(CURVE_3POOL, 0, 0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7, false),
            abi.encode(32, 3, testTokens.dai, testTokens.usdc, testTokens.usdt),
            true
        );

        _deployAdapter(
            "CurveLendingAdapter",
            CURVE_AAVE,
            abi.encode(CURVE_AAVE, 0, 0xDeBF20617708857ebe4F679508E7b7863a8A8EeE, false),
            abi.encode(32, 3, testTokens.dai, testTokens.usdc, testTokens.usdt),
            true
        );

        _deployAdapter(
            "CurveMetaAdapter",
            CURVE_FRAX,
            abi.encode(
                CURVE_FRAX,
                0,
                0xd632f22692FaC7611d2AA1C0D552930D43CAEd3B,
                true,
                0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7
            ),
            abi.encode(32, 4, testTokens.dai, testTokens.usdc, testTokens.usdt, testTokens.frax),
            true
        );

        _deployAdapter(
            "CurveTriCryptoAdapter",
            CURVE_TRICRYPTO,
            abi.encode(CURVE_TRICRYPTO, 0, 0xD51a44d3FaE010294C616388b506AcdA1bfAAE46, false),
            abi.encode(32, 3, basicTokens.weth, testTokens.wbtc, testTokens.usdt),
            true
        );
    }

    function _setupTokens() internal override {
        // _addSimpleBridgeToken(token, name, minAmount, maxAmount, isMintBurn,
        //                              feeBP, minBridgeFee, minGasDropFee, minSwapFee, chainIdNonEVM, isRouteToken)

        // minAmount reflects token decimals, while maxAmount doesn't.
        // It doesn't make sense right until it does.

        // Always add WGAS as first token
        // mintBurn = false, routeToken = true
        _addSimpleBridgeToken(basicTokens.weth, "wETH", 10**16, 10**3, false, 10, 2 * 10**15, 0, 6 * 10**15, 0, true);

        // mintBurn = false, routeToken = false
        _addSimpleBridgeToken(basicTokens.nusd, "nUSD", 10**18, 10**6, false, 10, 2 * 10**17, 0, 6 * 10**17, 0, false);

        // mintBurn = true, routeToken = false
        _addSimpleBridgeToken(basicTokens.syn, "SYN", 10**18, 10**6, true, 10, 2 * 10**17, 0, 6 * 10**17, 0, false);

        // mintBurn = false, routeToken = true
        _addSimpleBridgeToken(testTokens.frax, "FRAX", 10**18, 10**6, false, 10, 2 * 10**17, 0, 6 * 10**17, 0, true);
        // Sorry Sam, gotta casually mint 1B FRAX for testing
        _addTokenTo(testTokens.frax, address(vault), 10**27);

        // routeToken = true
        _addToken(testTokens.dai, "DAI", 10**18, 10**6, true);
        _addToken(testTokens.usdc, "USDC", 10**6, 10**6, true);
        _addToken(testTokens.usdt, "USDT", 10**6, 10**6, true);

        // routeToken = false
        _addToken(testTokens.wbtc, "wBTC", 10**2, 10**2, false);
    }
}
