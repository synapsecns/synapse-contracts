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
        address gohm;
        address high;
    }

    TestTokens internal testTokens =
        TestTokens({
            dai: 0x6B175474E89094C44Da98b954EedeAC495271d0F,
            usdc: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48,
            usdt: 0xdAC17F958D2ee523a2206206994597C13D831ec7,
            wbtc: 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599,
            frax: 0x853d955aCEf822Db058eb8505911ED77F175b99e,
            gohm: 0x0ab87046fBb341D058F17CBC4c1133F25a20a52f,
            high: 0x71Ab77b7dbB4fa7e017BC15090b2163221420282
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
        _deployAdapters();
    }

    function _setupTokens() internal override {
        // _addSimpleBridgeToken(token, name, minAmount, maxAmount, isMintBurn,
        //                              feeBP, minBridgeFee, minGasDropFee, minSwapFee, chainIdNonEVM, isRouteToken)

        // minAmount reflects token decimals, while maxAmount doesn't.
        // It doesn't make sense right until it does.

        // Always add WGAS as first token
        // mintBurn = false, routeToken = true
        _addSimpleBridgeToken(basicTokens.weth, "weth", 10**16, 10**3, false, 10, 2 * 10**15, 0, 6 * 10**15, 0, true);

        // mintBurn = false, routeToken = false
        _addSimpleBridgeToken(basicTokens.nusd, "nusd", 10**18, 10**6, false, 10, 2 * 10**17, 0, 6 * 10**17, 0, false);

        // mintBurn = true, routeToken = false
        _addSimpleBridgeToken(basicTokens.syn, "syn", 10**18, 10**6, true, 10, 2 * 10**17, 0, 6 * 10**17, 0, false);

        // mintBurn = false, routeToken = true
        _addSimpleBridgeToken(testTokens.frax, "frax", 10**18, 10**6, false, 10, 2 * 10**17, 0, 6 * 10**17, 0, true);
        // Sorry Sam, gotta casually mint 1B FRAX for testing
        _addTokenTo(testTokens.frax, address(vault), 10**27);

        // mintBurn = false, routeToken = false
        _addSimpleBridgeToken(testTokens.gohm, "gohm", 10**16, 10**3, false, 10, 2 * 10**15, 0, 6 * 10**15, 0, false);

        // mintBurn = false, routeToken = false
        _addSimpleBridgeToken(testTokens.high, "high", 10**18, 10**6, false, 10, 2 * 10**17, 0, 6 * 10**17, 0, false);
        _addTokenTo(testTokens.high, address(vault), 10**27);

        // routeToken = true
        _addToken(testTokens.dai, "dai", 10**18, 10**6, true);
        _addToken(testTokens.usdc, "usdc", 10**6, 10**6, true);
        _addToken(testTokens.usdt, "usdt", 10**6, 10**6, true);

        // routeToken = false
        _addToken(testTokens.wbtc, "wbtc", 10**2, 10**2, false);
    }
}
