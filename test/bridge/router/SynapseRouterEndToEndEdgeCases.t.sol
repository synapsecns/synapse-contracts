// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "./SynapseRouterSuite.t.sol";

// solhint-disable func-name-mixedcase
contract SynapseRouterEndToEndEdgeCasesTest is SynapseRouterSuite {
    uint256 internal constant KLAY_CHAINID = 8217;

    function setUp() public override {
        super.setUp();
        chains[KLAY_CHAINID] = deployTestKlaytn();
    }

    function deployTestKlaytn() public virtual returns (ChainSetup memory chain) {
        deployChainBasics({chain: chain, name: "KLAY", gasName: "KLAY", chainId: KLAY_CHAINID});
        deployChainBridge(chain);
        deployChainRouter(chain);
        chain.dai = deploySynapseERC20(chain, "DAI", 18);
        chain.usdc = deploySynapseERC20(chain, "USDC", 6);
        chain.usdt = deploySynapseERC20(chain, "USDT", 6);
        // Deploy nETH pool: nETH + WETH
        chain.nEthPool = deployPool(chain, castToArray(chain.neth, chain.weth), 100);
        // Deploy nUSD pool: nUSD + USDC
        chain.nUsdPool = deployPool(chain, castToArray(chain.nusd, chain.usdc), 10_000);
        // Set up Swap Quoter
        chain.quoter.addPool(chain.nEthPool);
        chain.quoter.addPool(chain.nUsdPool);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                       ETH -> KLAYTN, OUT: DAI                        ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function test_ethereumToKlaytn_inDAI_outDAI() public {
        ethereumToKlaytn_outDAI_fullTest(chains[ETH_CHAINID].dai);
    }

    function test_ethereumToKlaytn_inNUSD_outDAI() public {
        ethereumToKlaytn_outDAI_fullTest(chains[ETH_CHAINID].nusd);
    }

    function test_ethereumToKlaytn_inUSDC_outDAI() public {
        ethereumToKlaytn_outDAI_fullTest(chains[ETH_CHAINID].usdc);
    }

    function test_ethereumToKlaytn_inUSDT_outDAI() public {
        ethereumToKlaytn_outDAI_fullTest(chains[ETH_CHAINID].usdt);
    }

    function ethereumToKlaytn_outDAI_fullTest(IERC20 tokenIn) public {
        ChainSetup memory origin = chains[ETH_CHAINID];

        // Step 1: only DAI is available as option
        ethereumToKlaytn_outDAI(tokenIn);

        // Step 2: remove nUSD pool on origin. This will cause next test to fail unless tokenIn is DAI
        origin.quoter.removePool(origin.nUsdPool);
        if (tokenIn != origin.dai) vm.expectRevert("No path found on origin");
        // Doing an external call to catch the revert from the test suite
        this.ethereumToKlaytn_outDAI(tokenIn);

        // Step 3: add back the pool, remove DAI from bridge tokens on origin. Next test is going to fail
        origin.quoter.addPool(origin.nUsdPool);
        origin.router.removeToken(address(origin.dai));
        vm.expectRevert("No path found on origin");
        // Doing an external call to catch the revert from the test suite
        this.ethereumToKlaytn_outDAI(tokenIn);
    }

    function ethereumToKlaytn_outDAI(IERC20 tokenIn) public {
        // Prepare test parameters: Ethereum tokenIn -> Klaytn DAI
        ChainSetup memory origin = chains[ETH_CHAINID];
        ChainSetup memory destination = chains[KLAY_CHAINID];
        IERC20 tokenOut = destination.dai;
        uint256 amountIn = 10**uint256(ERC20(address(tokenIn)).decimals());
        (SwapQuery memory originQuery, SwapQuery memory destQuery) = performQuoteCalls(
            origin,
            destination,
            tokenIn,
            tokenOut,
            amountIn
        );
        // Only DAI could be used on origin chain
        address bridgeTokenOrigin = address(origin.dai);
        address bridgeTokenDest = address(destination.dai);
        vm.expectEmit(true, true, true, true);
        emit TokenDeposit(TO, KLAY_CHAINID, bridgeTokenOrigin, originQuery.minAmountOut);
        // User interacts with the SynapseRouter on origin chain
        initiateBridgeTx(origin, destination, tokenIn, tokenOut, amountIn);
        // Validator completes the transaction on destination chain
        checkCompletedBridgeTx(destination, bridgeTokenDest, originQuery, destQuery);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                       ETH -> KLAYTN, OUT: USDC                       ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function test_ethereumToKlaytn_inDAI_outUSDC() public {
        ethereumToKlaytn_outUSDC_fullTest(chains[ETH_CHAINID].dai);
    }

    function test_ethereumToKlaytn_inNUSD_outUSDC() public {
        ethereumToKlaytn_outUSDC_fullTest(chains[ETH_CHAINID].nusd);
    }

    function test_ethereumToKlaytn_inUSDC_outUSDC() public {
        ethereumToKlaytn_outUSDC_fullTest(chains[ETH_CHAINID].usdc);
    }

    function test_ethereumToKlaytn_inUSDT_outUSDC() public {
        ethereumToKlaytn_outUSDC_fullTest(chains[ETH_CHAINID].usdt);
    }

    function ethereumToKlaytn_outUSDC_fullTest(IERC20 tokenIn) public {
        ChainSetup memory origin = chains[ETH_CHAINID];
        ChainSetup memory destination = chains[KLAY_CHAINID];

        // Step 1: both nUSD and USDC are available as intermediate token
        ethereumToKlaytn_outUSDC({tokenIn: tokenIn, checkUSDC: false, checkNUSD: false});

        // Step 2: only USDC are available as intermediate token
        // Remove nUSD pool on Klaytn, this will make the transaction go through USDC
        destination.quoter.removePool(destination.nUsdPool);
        ethereumToKlaytn_outUSDC({tokenIn: tokenIn, checkUSDC: true, checkNUSD: false});

        // Step 3: no options are available for bridging
        // Remove USDC from list of valid origin tokens
        origin.router.removeToken(address(origin.usdc));
        vm.expectRevert("No path found on origin");
        // Doing an external call to catch the revert from the test suite
        this.ethereumToKlaytn_outUSDC({tokenIn: tokenIn, checkUSDC: false, checkNUSD: false});

        // Step 4: only nUSD are available as intermediate token
        // Add back nUSD pool on Klaytn, this will route tx through nUSD
        destination.quoter.addPool(destination.nUsdPool);
        ethereumToKlaytn_outUSDC({tokenIn: tokenIn, checkUSDC: false, checkNUSD: true});
    }

    function ethereumToKlaytn_outUSDC(
        IERC20 tokenIn,
        bool checkUSDC,
        bool checkNUSD
    ) public {
        // Prepare test parameters: Ethereum tokenIn -> Klaytn USDC
        ChainSetup memory origin = chains[ETH_CHAINID];
        ChainSetup memory destination = chains[KLAY_CHAINID];
        IERC20 tokenOut = destination.usdc;
        uint256 amountIn = 10**uint256(ERC20(address(tokenIn)).decimals());
        (SwapQuery memory originQuery, SwapQuery memory destQuery) = performQuoteCalls(
            origin,
            destination,
            tokenIn,
            tokenOut,
            amountIn
        );
        // Could use either nUSD or USDC as the bridge token on Ethereum
        address bridgeTokenOrigin = originQuery.tokenOut;
        if (checkUSDC) require(bridgeTokenOrigin == address(origin.usdc), "!USDC");
        if (checkNUSD) require(bridgeTokenOrigin == address(origin.nusd), "!NUSD");
        address bridgeTokenDest;
        if (bridgeTokenOrigin == address(origin.usdc)) {
            // Ethereum: tokenIn -> USDC; Klaytn: USDC -> USDC
            // Expect Bridge event to be emitted
            vm.expectEmit(true, true, true, true);
            emit TokenDeposit(TO, KLAY_CHAINID, bridgeTokenOrigin, originQuery.minAmountOut);
            bridgeTokenDest = address(destination.usdc);
        } else {
            // Ethereum: tokenIn -> nUSD; Klaytn: nUSD -> USDC
            vm.expectEmit(true, true, true, true);
            emit TokenDepositAndSwap({
                to: TO,
                chainId: KLAY_CHAINID,
                token: bridgeTokenOrigin,
                amount: originQuery.minAmountOut,
                tokenIndexFrom: 0,
                tokenIndexTo: 1,
                minDy: destQuery.minAmountOut,
                deadline: destQuery.deadline
            });
            bridgeTokenDest = address(destination.nusd);
        }
        // User interacts with the SynapseRouter on origin chain
        initiateBridgeTx(origin, destination, tokenIn, tokenOut, amountIn);
        // Validator completes the transaction on destination chain
        checkCompletedBridgeTx(destination, bridgeTokenDest, originQuery, destQuery);
    }
}
