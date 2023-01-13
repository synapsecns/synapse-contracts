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

    /// @notice Mocks Validator logic for executing a SynapseBridge transaction on destination chain.
    function completeBridgeTx(
        SynapseBridge bridge,
        address payable to,
        LocalBridgeConfig.TokenType tokenType,
        address token,
        uint256 amount,
        SwapQuery memory query
    ) external {
        require(token != address(0), "Unknown token");
        uint256 fee = calculateBridgeFee(amount);
        bytes32 kappa = _rotateKappa();
        // Decode params, if swap adapter was specified
        SynapseParams memory params;
        if (query.swapAdapter != address(0)) params = abi.decode(query.rawParams, (SynapseParams));
        if (query.swapAdapter == address(0) || params.action == Action.HandleEth) {
            // If no swapAdapter is present, or "Handle ETH" was specified: execute vanilla withdraw/mint
            if (tokenType == LocalBridgeConfig.TokenType.Deposit) {
                bridge.withdraw(to, IERC20(token), amount, fee, kappa);
            } else {
                bridge.mint(to, IERC20Mintable(token), amount, fee, kappa);
            }
        } else {
            // Otherwise, we need to execute <...>And<...> bridge method
            if (tokenType == LocalBridgeConfig.TokenType.Deposit) {
                require(params.action == Action.RemoveLiquidity, "Unknown action");
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
            } else {
                require(params.action == Action.Swap, "Unknown action");
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
abstract contract SynapseRouterSuite is Utilities06 {
    address internal constant USER = address(4242);
    address internal constant TO = address(2424);

    uint256 internal constant ETH_CHAINID = 1;
    uint256 internal constant OPT_CHAINID = 10;
    uint256 internal constant ARB_CHAINID = 42161;
    uint256 internal constant AVA_CHAINID = 43114;
    uint256 internal constant DFK_CHAINID = 53935;
    uint256 internal constant HAR_CHAINID = 1666600000;

    uint256 internal constant DELAY = 1 minutes;

    uint256 internal constant BRIDGE_FEE = 10**7; // 10bps
    uint256 internal constant MIN_FEE = 10**15;
    uint256 internal constant MAX_FEE = 10**16;

    string internal constant SYMBOL_NUSD = "nUSD";
    string internal constant SYMBOL_NETH = "nETH";
    string internal constant SYMBOL_GMX = "GMX";
    string internal constant SYMBOL_JEWEL = "JEWEL";

    string internal constant SYMBOL_DAI = "DAI";
    string internal constant SYMBOL_USDC = "USDC";
    string internal constant SYMBOL_USDT = "USDT";

    ValidatorMock internal validator;

    struct ChainSetup {
        uint256 chainId;
        string name;
        SynapseBridge bridge;
        SynapseRouter router;
        SwapQuoter quoter;
        IERC20 gas;
        IERC20 wgas;
        address nEthPool;
        IERC20 neth;
        IERC20 weth;
        address nUsdPool;
        IERC20 nusd;
        IERC20 dai;
        IERC20 usdc;
        IERC20 usdt;
    }

    mapping(uint256 => ChainSetup) internal chains;

    function setUp() public virtual override {
        super.setUp();
        validator = new ValidatorMock();
        chains[ETH_CHAINID] = deployTestEthereum();
        chains[ARB_CHAINID] = deployTestArbitrum();
        chains[OPT_CHAINID] = deployTestOptimism();
        chains[AVA_CHAINID] = deployTestAvalanche();
        chains[DFK_CHAINID] = deployTestDFK();
        chains[HAR_CHAINID] = deployTestHarmony();
    }

    function deployChainBasics(
        ChainSetup memory chain,
        string memory name,
        string memory gasName,
        uint256 chainId
    ) public virtual {
        chain.name = name;
        chain.chainId = chainId;
        // Convenience shortcut
        chain.gas = IERC20(UniversalToken.ETH_ADDRESS);
        // Deploy WGAS
        IWETH9 wgas = deployWETH(concat(chain.name, " W", gasName));
        chain.wgas = IERC20(address(wgas));
        deal(address(this), 10**24);
        wgas.deposit{value: 10**24}();

        // Deploy WETH
        if (equals(gasName, "ETH")) {
            chain.weth = chain.wgas;
        } else {
            chain.weth = deployERC20(concat(chain.name, " WETH"), 18);
        }
        // Deploy USD tokens (not all necessarily used later)
        chain.dai = deployERC20(concat(chain.name, " DAI"), 18);
        chain.usdc = deployERC20(concat(chain.name, " USDC"), 6);
        chain.usdt = deployERC20(concat(chain.name, " USDT"), 6);
    }

    function deployChainBridge(ChainSetup memory chain) public virtual {
        chain.bridge = deployBridge();
        chain.bridge.grantRole(chain.bridge.NODEGROUP_ROLE(), address(validator));
        chain.bridge.setWethAddress(payable(address(chain.wgas)));
    }

    function deployChainRouter(ChainSetup memory chain) public virtual {
        chain.router = new SynapseRouter(address(chain.bridge));
        chain.quoter = new SwapQuoter(address(chain.router), address(chain.wgas));
        chain.router.setSwapQuoter(chain.quoter);

        vm.label(address(chain.bridge), concat(chain.name, " Bridge"));
        vm.label(address(chain.router), concat(chain.name, " Router"));
        vm.label(address(chain.quoter), concat(chain.name, " Quoter"));

        // Deploy Bridge tokens
        if (!equals(chain.name, "ETH")) {
            chain.neth = deploySynapseERC20(chain, concat(chain.name, " nETH"));
            chain.nusd = deploySynapseERC20(chain, concat(chain.name, " nUSD"));
            _addRedeemToken(chain.router, SYMBOL_NETH, address(chain.neth));
            _addRedeemToken(chain.router, SYMBOL_NUSD, address(chain.nusd));
        }
    }

    function deployTestEthereum() public virtual returns (ChainSetup memory chain) {
        deployChainBasics({chain: chain, name: "ETH", gasName: "ETH", chainId: ETH_CHAINID});
        deployChainBridge(chain);
        deployChainRouter(chain);
        chain.nUsdPool = deployPool(chain, castToArray(chain.dai, chain.usdc, chain.usdt), 1_000_000);
        // Set up Swap Quoter and fetch nUSD address
        chain.quoter.addPool(chain.nUsdPool);
        (, address nexusLpToken) = chain.quoter.poolInfo(chain.nUsdPool);
        vm.label(nexusLpToken, "ETH nUSD");
        chain.nusd = IERC20(nexusLpToken);
        // Setup bridge tokens for Mainnet
        _addDepositToken(chain.router, SYMBOL_NETH, address(chain.weth));
        _addDepositToken(chain.router, SYMBOL_NUSD, address(chain.nusd));
        _addDepositToken(chain.router, SYMBOL_DAI, address(chain.dai));
        _addDepositToken(chain.router, SYMBOL_USDC, address(chain.usdc));
        _addDepositToken(chain.router, SYMBOL_USDT, address(chain.usdt));
        // Setup initial WETH, nUSD, DAI, USDC, USDT Bridge deposits
        dealToken(chain, address(chain.bridge), chain.weth, 10**24);
        chain.nusd.transfer(address(chain.bridge), chain.nusd.balanceOf(address(this)));
        dealToken(chain, address(chain.bridge), chain.dai, 10**24);
        dealToken(chain, address(chain.bridge), chain.usdc, 10**12);
        dealToken(chain, address(chain.bridge), chain.usdt, 10**12);
    }

    function deployTestArbitrum() public virtual returns (ChainSetup memory chain) {
        deployChainBasics({chain: chain, name: "ARB", gasName: "ETH", chainId: ARB_CHAINID});
        deployChainBridge(chain);
        deployChainRouter(chain);
        // Deploy nETH pool: nETH + WETH
        chain.nEthPool = deployPool(chain, castToArray(chain.neth, chain.weth), 1_000);
        // Deploy nUSD pool: nUSD + USDC + USDT
        chain.nUsdPool = deployPool(chain, castToArray(chain.nusd, chain.usdc, chain.usdt), 100_000);
        // Set up Swap Quoter
        chain.quoter.addPool(chain.nEthPool);
        chain.quoter.addPool(chain.nUsdPool);
    }

    function deployTestOptimism() public virtual returns (ChainSetup memory chain) {
        deployChainBasics({chain: chain, name: "OPT", gasName: "ETH", chainId: OPT_CHAINID});
        deployChainBridge(chain);
        deployChainRouter(chain);
        // Deploy nETH pool: nETH + WETH
        chain.nEthPool = deployPool(chain, castToArray(chain.neth, chain.weth), 2_000);
        // Deploy nUSD pool: nUSD + USDC
        chain.nUsdPool = deployPool(chain, castToArray(chain.nusd, chain.usdc), 200_000);
        // Set up Swap Quoter
        chain.quoter.addPool(chain.nEthPool);
        chain.quoter.addPool(chain.nUsdPool);
    }

    function deployTestAvalanche() public virtual returns (ChainSetup memory chain) {
        deployChainBasics({chain: chain, name: "AVA", gasName: "AVAX", chainId: AVA_CHAINID});
        deployChainBridge(chain);
        deployChainRouter(chain);
        // TODO: setup Aave WETH Mock
        // Deploy nETH pool: nETH + WETH
        chain.nEthPool = deployPool(chain, castToArray(chain.neth, chain.weth), 3_000);
        // Deploy nUSD pool: nUSD + DAI + USDC + USDT
        chain.nUsdPool = deployPool(chain, castToArray(chain.nusd, chain.dai, chain.usdc, chain.usdt), 300_000);
        // Set up Swap Quoter
        chain.quoter.addPool(chain.nEthPool);
        chain.quoter.addPool(chain.nUsdPool);
    }

    function deployTestDFK() public virtual returns (ChainSetup memory chain) {
        deployChainBasics({chain: chain, name: "DFK", gasName: "JEWEL", chainId: DFK_CHAINID});
        deployChainBridge(chain);
        deployChainRouter(chain);
        // no pools on DFK
    }

    function deployTestHarmony() public virtual returns (ChainSetup memory chain) {
        deployChainBasics({chain: chain, name: "HAR", gasName: "ONE", chainId: HAR_CHAINID});
        deployChainBridge(chain);
        deployChainRouter(chain);
        // Let's imagine a world where Harmony assets are traded 1:1
        // Deploy nETH pool: nETH + WETH
        chain.nEthPool = deployPool(chain, castToArray(chain.neth, chain.weth), 500);
        // Deploy nUSD pool: nUSD + DAI + USDC + USDT
        chain.nUsdPool = deployPool(chain, castToArray(chain.nusd, chain.dai, chain.usdc, chain.usdt), 50_000);
        // Set up Swap Quoter
        chain.quoter.addPool(chain.nEthPool);
        chain.quoter.addPool(chain.nUsdPool);
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
    ) public virtual returns (address pool) {
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
        IERC20 tokenIn,
        IERC20 tokenOut,
        uint256 amountIn
    ) public {
        prepareBridgeTx(origin, tokenIn, amountIn);
        (SwapQuery memory originQuery, SwapQuery memory destQuery) = performQuoteCalls(
            origin,
            destination,
            tokenIn,
            tokenOut,
            amountIn
        );
        vm.prank(USER);
        bool startFromETH = address(tokenIn) == UniversalToken.ETH_ADDRESS;
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
        IERC20 tokenIn,
        uint256 amountIn
    ) public {
        if (address(tokenIn) == UniversalToken.ETH_ADDRESS) {
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
        if (token == chain.wgas) {
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
        // Step 0: find connected bridge tokens on destination
        BridgeToken[] memory tokens = destination.router.getConnectedBridgeTokens(address(tokenOut));
        // Break execution if setup is not correct
        require(tokens.length != 0, "No symbols found");
        string[] memory symbols = new string[](tokens.length);
        for (uint256 i = 0; i < tokens.length; ++i) {
            // Break execution if incorrect values are returned
            require(bytes(tokens[i].symbol).length != 0, "Empty symbol returned");
            require(tokens[i].token != address(0), "Empty token returned");
            symbols[i] = tokens[i].symbol;
        }
        // Step 1: perform a call to origin SynapseRouter
        SwapQuery[] memory originQueries = origin.router.getOriginAmountOut(address(tokenIn), symbols, amountIn);
        // Step 2: form a list of Destination Requests
        // In practice, there is no need to pass the requests with amountIn = 0, but we will do it for code simplicity
        DestRequest[] memory requests = new DestRequest[](tokens.length);
        for (uint256 i = 0; i < tokens.length; ++i) {
            requests[i].symbol = symbols[i];
            requests[i].amountIn = originQueries[i].minAmountOut;
        }
        // Step 3: perform a call to destination SynapseRouter
        SwapQuery[] memory destQueries = destination.router.getDestinationAmountOut(requests, address(tokenOut));
        // Step 4: find the best query (in practice, we could return them all)
        uint256 maxAmountOut = 0;
        for (uint256 i = 0; i < tokens.length; ++i) {
            if (destQueries[i].minAmountOut > maxAmountOut) {
                originQuery = originQueries[i];
                destQuery = destQueries[i];
            }
        }
        // Break execution if origin quote is zero
        require(originQuery.minAmountOut != 0, "No path found on origin");
        // In practice deadline should be set based on the user settings. For testing we use current time.
        originQuery.deadline = block.timestamp;
        // In practice minAmountOut should be set based on user-defined slippage. For testing we use the exact quote.
        originQuery.minAmountOut;
        // Break execution if destination quote is zero
        require(destQuery.minAmountOut != 0, "No path found on destination");
        // In practice deadline should be set based on the user settings. For testing we use current time + delay.
        destQuery.deadline = block.timestamp + DELAY;
        // In practice minAmountOut should be set based on user-defined slippage. For testing we use the exact quote.
        destQuery.minAmountOut;
    }

    function getRecipientBalance(ChainSetup memory chain, address token) public view returns (uint256) {
        if (token == address(chain.wgas) || token == address(chain.gas)) {
            return TO.balance;
        } else {
            return IERC20(token).balanceOf(TO);
        }
    }

    function _addDepositToken(
        SynapseRouter router,
        string memory symbol,
        address token
    ) internal {
        _addToken(router, symbol, token, LocalBridgeConfig.TokenType.Deposit, token);
    }

    function _addRedeemToken(
        SynapseRouter router,
        string memory symbol,
        address token
    ) internal {
        _addToken(router, symbol, token, LocalBridgeConfig.TokenType.Redeem, token);
    }

    function _addToken(
        SynapseRouter router,
        string memory symbol,
        address token,
        LocalBridgeConfig.TokenType tokenType,
        address bridgeToken
    ) internal {
        router.addToken(symbol, token, tokenType, bridgeToken, BRIDGE_FEE, MIN_FEE, MAX_FEE);
    }
}
