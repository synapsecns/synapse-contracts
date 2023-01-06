// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "../../utils/Utilities06.sol";

import "../../../contracts/bridge/router/SwapQuoter.sol";
import "../../../contracts/bridge/router/SynapseRouter.sol";
import "../../../contracts/bridge/SynapseBridge.sol";

contract ValidatorMock {
    uint256 internal constant BRIDGE_FEE = 10**7; // 10bps
    uint256 internal constant MIN_FEE = 10**15;
    uint256 internal constant MAX_FEE = 10**16;

    bytes32 internal mockKappa = "MOCK KAPPA";

    function completeBridgeTx(
        SynapseBridge bridge,
        address payable to,
        LocalBridgeConfig.TokenType tokenType,
        address token,
        uint256 amount,
        SwapQuery memory query
    ) external {
        uint256 fee = calculateBridgeFee(amount);
        bytes32 kappa = _rotateKappa();
        if (query.swapAdapter == address(0)) {
            if (tokenType == LocalBridgeConfig.TokenType.Deposit) {
                bridge.withdraw(to, IERC20(token), amount, fee, kappa);
            } else {
                bridge.mint(to, IERC20Mintable(token), amount, fee, kappa);
            }
        } else {
            SynapseParams memory params = abi.decode(query.rawParams, (SynapseParams));
            if (tokenType == LocalBridgeConfig.TokenType.Deposit) {
                if (params.action == Action.RemoveLiquidity) {
                    bridge.withdrawAndRemove({
                        to: to,
                        token: IERC20(token),
                        amount: amount,
                        fee: fee,
                        pool: ISwap(params.pool),
                        swapTokenIndex: params.tokenIndexTo,
                        swapMinAmount: query.minAmountOut,
                        swapDeadline: query.deadline,
                        kappa: kappa
                    });
                }
            } else {
                if (params.action == Action.Swap) {
                    bridge.mintAndSwap({
                        to: to,
                        token: IERC20Mintable(token),
                        amount: amount,
                        fee: fee,
                        pool: ISwap(params.pool),
                        tokenIndexFrom: params.tokenIndexFrom,
                        tokenIndexTo: params.tokenIndexTo,
                        minDy: query.minAmountOut,
                        deadline: query.deadline,
                        kappa: kappa
                    });
                }
            }
        }
    }

    function calculateBridgeFee(uint256 amount) public pure returns (uint256 fee) {
        fee = (amount * BRIDGE_FEE) / 10**10;
        if (fee < MIN_FEE) fee = MIN_FEE;
        if (fee > MAX_FEE) fee = MAX_FEE;
    }

    function _rotateKappa() internal returns (bytes32 oldKappa) {
        oldKappa = mockKappa;
        mockKappa = keccak256(abi.encode(oldKappa));
    }
}

// solhint-disable func-name-mixedcase
// solhint-disable not-rely-on-time
abstract contract SynapseRouterE2E is Utilities06 {
    address internal constant USER = address(4242);
    address internal constant TO = address(2424);

    uint256 internal constant ETH_CHAINID = 1;
    uint256 internal constant OPT_CHAINID = 10;
    uint256 internal constant ARB_CHAINID = 42161;

    uint256 internal constant DELAY = 1 minutes;

    uint256 internal constant BRIDGE_FEE = 10**7; // 10bps
    uint256 internal constant MIN_FEE = 10**15;
    uint256 internal constant MAX_FEE = 10**16;

    bytes32 internal constant SYMBOL_NUSD = "nUSD";
    bytes32 internal constant SYMBOL_NETH = "nETH";

    ValidatorMock internal validator;

    struct ChainSetup {
        uint256 chainId;
        SynapseBridge bridge;
        SynapseRouter router;
        SwapQuoter quoter;
        address nEthPool;
        IERC20 neth;
        IERC20 weth;
        address bridgeTokenEth;
        address nUsdPool;
        IERC20 nusd;
        IERC20 dai;
        IERC20 usdc;
        IERC20 usdt;
        address bridgeTokenUsd;
    }

    mapping(uint256 => ChainSetup) internal chains;

    function setUp() public override {
        super.setUp();
        validator = new ValidatorMock();
        chains[ETH_CHAINID] = deployTestEthereum();
        chains[ARB_CHAINID] = deployTestArbitrum();
        chains[OPT_CHAINID] = deployTestOptimism();
    }

    function deployChain() public returns (ChainSetup memory chain) {
        IWETH9 weth = deployWETH();
        chain.weth = IERC20(address(weth));
        deal(address(this), 10**24);
        weth.deposit{value: 10**24}();

        chain.bridge = deployBridge();
        chain.bridge.grantRole(chain.bridge.NODEGROUP_ROLE(), address(validator));
        chain.bridge.setWethAddress(payable(weth));

        chain.router = new SynapseRouter(address(weth), address(chain.bridge));
        chain.quoter = new SwapQuoter(address(chain.router));
        chain.router.setSwapQuoter(chain.quoter);
    }

    function deployTestEthereum() public returns (ChainSetup memory chain) {
        chain = deployChain();
        chain.chainId = ETH_CHAINID;
        // no ETH pool on Mainnet
        // Deploy USD tokens
        chain.dai = deployERC20("ETH DAI", 18);
        chain.usdc = deployERC20("ETH USDC", 6);
        chain.usdt = deployERC20("ETH USDT", 6);
        // Deploy nUSD pool and fetch nUSD address
        chain.nUsdPool = deployPool(chain, _castToArray(chain.dai, chain.usdc, chain.usdt), 1_000_000);
        // Set up Swap Quoter
        chain.quoter.addPool(chain.nUsdPool);
        (, address nexusLpToken) = chain.quoter.poolInfo(chain.nUsdPool);
        chain.nusd = IERC20(nexusLpToken);
        // Setup bridge tokens
        _addDepositToken(chain.router, address(chain.weth));
        _addDepositToken(chain.router, address(chain.nusd));
        chain.bridgeTokenEth = address(chain.weth);
        chain.bridgeTokenUsd = address(chain.nusd);
        // Setup initial WETH, nUSD Bridge deposits
        dealToken(chain, address(chain.bridge), chain.weth, 10**20);
        chain.nusd.transfer(address(chain.bridge), chain.nusd.balanceOf(address(this)));
    }

    function deployTestArbitrum() public returns (ChainSetup memory chain) {
        chain = deployChain();
        chain.chainId = ARB_CHAINID;
        // Deploy ETH tokens
        chain.neth = deploySynapseERC20(chain, "ARB nETH");
        // Deploy nETH pool
        chain.nEthPool = deployPool(chain, _castToArray(chain.neth, chain.weth), 1_000);
        // Deploy USD tokens
        chain.nusd = deploySynapseERC20(chain, "ARB nUSD");
        chain.usdc = deployERC20("ARB USDC", 6);
        chain.usdt = deployERC20("ARB USDT", 6);
        // Deploy nUSD pool
        chain.nUsdPool = deployPool(chain, _castToArray(chain.nusd, chain.usdc, chain.usdt), 100_000);
        // Set up Swap Quoter
        chain.quoter.addPool(chain.nEthPool);
        chain.quoter.addPool(chain.nUsdPool);
        // Setup bridge tokens
        _addRedeemToken(chain.router, address(chain.neth));
        _addRedeemToken(chain.router, address(chain.nusd));
        chain.bridgeTokenEth = address(chain.neth);
        chain.bridgeTokenUsd = address(chain.nusd);
    }

    function deployTestOptimism() public returns (ChainSetup memory chain) {
        chain = deployChain();
        chain.chainId = OPT_CHAINID;
        // Deploy ETH tokens
        chain.neth = deploySynapseERC20(chain, "OPT nETH");
        // Deploy nETH pool
        chain.nEthPool = deployPool(chain, _castToArray(chain.neth, chain.weth), 2_000);
        // Deploy USD tokens
        chain.nusd = deploySynapseERC20(chain, "OPT nUSD");
        chain.usdc = deployERC20("OPT USDC", 6);
        // Deploy nUSD pool
        chain.nUsdPool = deployPool(chain, _castToArray(chain.nusd, chain.usdc), 200_000);
        // Set up Swap Quoter
        chain.quoter.addPool(chain.nEthPool);
        chain.quoter.addPool(chain.nUsdPool);
        // Setup bridge tokens
        _addRedeemToken(chain.router, address(chain.neth));
        _addRedeemToken(chain.router, address(chain.nusd));
        chain.bridgeTokenEth = address(chain.neth);
        chain.bridgeTokenUsd = address(chain.nusd);
    }

    function deploySynapseERC20(ChainSetup memory chain, string memory name) public returns (IERC20 token) {
        SynapseERC20 _token = deploySynapseERC20(name);
        _token.grantRole(_token.MINTER_ROLE(), address(chain.bridge));
        token = IERC20(address(_token));
    }

    function deployPool(
        ChainSetup memory chain,
        IERC20[] memory tokens,
        uint256 seedAmount
    ) internal returns (address pool) {
        uint256[] memory amounts = new uint256[](tokens.length);
        pool = deployPool(tokens);
        for (uint256 i = 0; i < tokens.length; ++i) {
            uint256 decimals = ERC20(address(tokens[i])).decimals();
            // Make the initial pool slightly imbalanced
            amounts[i] = (seedAmount * 10**decimals * (1000 + i)) / 1000;
            dealToken(chain, address(this), tokens[i], amounts[i]);
            tokens[i].approve(pool, amounts[i]);
        }
        ISwap(pool).addLiquidity(amounts, 0, type(uint256).max);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                      BRIDGE/ROUTER INTERACTIONS                      ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function initiateBridgeTx(
        ChainSetup memory origin,
        ChainSetup memory destination,
        bool startFromETH,
        IERC20 tokenIn,
        IERC20 tokenOut,
        uint256 amountIn
    ) public {
        prepareBridgeTx(origin, startFromETH, tokenIn, amountIn);
        (SwapQuery memory originQuery, SwapQuery memory destQuery) = performQuoteCalls(
            origin,
            destination,
            tokenIn,
            tokenOut,
            amountIn
        );
        vm.prank(USER);
        origin.router.bridge{value: startFromETH ? amountIn : 0}({
            to: TO,
            chainId: destination.chainId,
            token: address(tokenIn),
            amount: amountIn,
            originQuery: originQuery,
            destQuery: destQuery
        });
    }

    function checkCompletedBridgeTx(
        ChainSetup memory destination,
        address bridgeTokenDest,
        SwapQuery memory originQuery,
        SwapQuery memory destQuery
    ) public {
        skip(DELAY);
        uint256 balanceBefore = getRecipientBalance(destination, destQuery.tokenOut);
        completeBridgeTx(destination, bridgeTokenDest, originQuery.minAmountOut, destQuery);
        uint256 balanceAfter = getRecipientBalance(destination, destQuery.tokenOut);
        assertTrue(balanceAfter != balanceBefore, "Failed to bridge anything");
        assertEq(balanceAfter - balanceBefore, destQuery.minAmountOut, "Failed to get accurate quote");
    }

    function completeBridgeTx(
        ChainSetup memory destination,
        address bridgeToken,
        uint256 amount,
        SwapQuery memory destQuery
    ) public {
        LocalBridgeConfig.TokenType tokenType;
        (tokenType, bridgeToken) = destination.router.config(bridgeToken);
        validator.completeBridgeTx(destination.bridge, payable(TO), tokenType, bridgeToken, amount, destQuery);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                             TEST HELPERS                             ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function prepareBridgeTx(
        ChainSetup memory origin,
        bool startFromETH,
        IERC20 tokenIn,
        uint256 amountIn
    ) public {
        if (startFromETH) {
            // Deal ETH to user
            deal(USER, amountIn);
        } else {
            dealToken(origin, USER, tokenIn, amountIn);
            // Approve token spending
            vm.prank(USER);
            tokenIn.approve(address(origin.router), amountIn);
        }
    }

    function dealToken(
        ChainSetup memory chain,
        address to,
        IERC20 token,
        uint256 amount
    ) public {
        if (token == chain.weth) {
            // Deal ETH to user and wrap it into WETH
            deal(to, amount);
            vm.prank(to);
            IWETH9(payable(address(token))).deposit{value: amount}();
        } else {
            // Deal token to user and update total supply
            deal(address(token), to, amount, true);
        }
    }

    function performQuoteCalls(
        ChainSetup memory origin,
        ChainSetup memory destination,
        IERC20 tokenIn,
        IERC20 tokenOut,
        uint256 amountIn
    ) public view returns (SwapQuery memory originQuery, SwapQuery memory destQuery) {
        // Find correlated bridge token on destination
        (bytes32 symbol, address bridgeTokenDest) = getCorrelatedBridgeToken(destination, tokenOut);
        // Find bridge token address on origin
        address bridgeTokenOrigin = getChainBridgeToken(origin, symbol);
        // Step 1: perform a call to origin SynapseRouter
        originQuery = origin.router.getOriginAmountOut(address(tokenIn), bridgeTokenOrigin, amountIn);
        // In practice deadline should be set based on the user settings. For testing we use current time.
        originQuery.deadline = block.timestamp;
        // In practice minAmountOut should be set based on user-defined slippage. For testing we use the exact quote.
        originQuery.minAmountOut;
        // Step 2: perform a call to destination SynapseRouter. Use quote from origin query as "amount in".
        destQuery = destination.router.getDestinationAmountOut(
            bridgeTokenDest,
            address(tokenOut),
            originQuery.minAmountOut
        );
        // In practice deadline should be set based on the user settings. For testing we use current time + delay.
        destQuery.deadline = block.timestamp + DELAY;
        // In practice minAmountOut should be set based on user-defined slippage. For testing we use the exact quote.
        destQuery.minAmountOut;
    }

    function getChainBridgeToken(ChainSetup memory chain, bytes32 symbol) public pure returns (address bridgeToken) {
        // In practice, one is expected to store the global bridge token addresses.
        // This method is just mocking the storage logic.
        if (symbol == SYMBOL_NETH) {
            bridgeToken = chain.bridgeTokenEth;
        } else if (symbol == SYMBOL_NUSD) {
            bridgeToken = chain.bridgeTokenUsd;
        }
    }

    function getCorrelatedBridgeToken(ChainSetup memory chain, IERC20 token)
        public
        pure
        returns (bytes32 symbol, address bridgeToken)
    {
        // In practice, one is expected to store the global bridge token addresses,
        // and a list of "correlated" tokens for every bridge token.
        // This method is just mocking the storage logic.
        if (token == chain.neth || token == chain.weth) {
            symbol = SYMBOL_NETH;
            bridgeToken = chain.bridgeTokenEth;
        } else if (token == chain.nusd || token == chain.dai || token == chain.usdc || token == chain.usdt) {
            symbol = SYMBOL_NUSD;
            bridgeToken = chain.bridgeTokenUsd;
        }
    }

    function getRecipientBalance(ChainSetup memory chain, address token) public view returns (uint256) {
        if (token == address(chain.weth)) {
            return TO.balance;
        } else {
            return IERC20(token).balanceOf(TO);
        }
    }

    function _addDepositToken(SynapseRouter router, address token) internal {
        chains[ETH_CHAINID];
        router.addToken({
            token: token,
            tokenType: LocalBridgeConfig.TokenType.Deposit,
            bridgeToken: token,
            bridgeFee: BRIDGE_FEE,
            minFee: MIN_FEE,
            maxFee: MAX_FEE
        });
    }

    function _addRedeemToken(SynapseRouter router, address token) internal {
        router.addToken({
            token: token,
            tokenType: LocalBridgeConfig.TokenType.Redeem,
            bridgeToken: token,
            bridgeFee: BRIDGE_FEE,
            minFee: MIN_FEE,
            maxFee: MAX_FEE
        });
    }

    function _castToArray(IERC20 token0, IERC20 token1) internal pure returns (IERC20[] memory tokens) {
        tokens = new IERC20[](2);
        tokens[0] = token0;
        tokens[1] = token1;
    }

    function _castToArray(
        IERC20 token0,
        IERC20 token1,
        IERC20 token2
    ) internal pure returns (IERC20[] memory tokens) {
        tokens = new IERC20[](3);
        tokens[0] = token0;
        tokens[1] = token1;
        tokens[2] = token2;
    }
}
