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
        uint256 fee = calculateBridgeFee(token, amount);
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

    function calculateBridgeFee(address token, uint256 amount) public view returns (uint256 fee) {
        fee = (amount * BRIDGE_FEE) / 10**10;
        if (fee < MIN_FEE) fee = MIN_FEE;
        if (fee > MAX_FEE) fee = MAX_FEE;
        // Scale down fee according to token decimals
        uint256 decimals;
        try ERC20(token).decimals() returns (uint8 _decimals) {
            decimals = _decimals;
        } catch {
            decimals = 18;
        }
        fee = (fee * 10**decimals) / 10**18;
    }

    function _rotateKappa() internal returns (bytes32 oldKappa) {
        oldKappa = mockKappa;
        mockKappa = keccak256(abi.encode(oldKappa));
    }
}

// solhint-disable func-name-mixedcase
// solhint-disable not-rely-on-time
abstract contract SynapseRouterSuite is Utilities06 {
    using SafeERC20 for IERC20;

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

    string[] internal allSymbols;

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
        allSymbols.push(SYMBOL_NUSD);
        allSymbols.push(SYMBOL_NETH);
        allSymbols.push(SYMBOL_GMX);
        allSymbols.push(SYMBOL_JEWEL);
        allSymbols.push(SYMBOL_DAI);
        allSymbols.push(SYMBOL_USDC);
        allSymbols.push(SYMBOL_USDT);
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
        deployWETH(chain, gasName);
        // Deploy WETH
        if (equals(gasName, "ETH")) {
            chain.weth = chain.wgas;
        } else {
            chain.weth = deployERC20(chain, "WETH", 18);
        }
        // Deploy USD tokens (not all necessarily used later)
        chain.dai = deployERC20(chain, "DAI", 18);
        chain.usdc = deployERC20(chain, "USDC", 6);
        chain.usdt = deployERC20(chain, "USDT", 6);
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
            chain.neth = deploySynapseERC20(chain, SYMBOL_NETH, 18);
            chain.nusd = deploySynapseERC20(chain, SYMBOL_NUSD, 18);
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
        _addDepositToken(chain, SYMBOL_NETH, address(chain.weth));
        _addDepositToken(chain, SYMBOL_NUSD, address(chain.nusd));
        _addDepositToken(chain, SYMBOL_DAI, address(chain.dai));
        _addDepositToken(chain, SYMBOL_USDC, address(chain.usdc));
        _addDepositToken(chain, SYMBOL_USDT, address(chain.usdt));
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

    function deployPool(
        ChainSetup memory,
        IERC20[] memory tokens,
        uint256 seedAmount
    ) public virtual returns (address pool) {
        uint256[] memory amounts = new uint256[](tokens.length);
        pool = deployPool(tokens);
        for (uint256 i = 0; i < tokens.length; ++i) {
            uint256 decimals = ERC20(address(tokens[i])).decimals();
            // Make the initial pool slightly imbalanced
            amounts[i] = (seedAmount * 10**decimals * (1000 + i)) / 1000;
            // Test contract should have enough tokes for testing purposes
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
    ) public returns (SwapQuery memory originQuery, SwapQuery memory destQuery) {
        prepareBridgeTx(origin, tokenIn, amountIn);
        (originQuery, destQuery) = performQuoteCalls(origin, destination, tokenIn, tokenOut, amountIn);
        SwapQuery memory _originQuery;
        SwapQuery memory _destQuery;
        (_originQuery, _destQuery) = findBestQuotes(origin, destination, tokenIn, tokenOut, amountIn);
        checkEqualQueries(originQuery, _originQuery, "originQuery");
        checkEqualQueries(destQuery, _destQuery, "destQuery");
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
            tokenIn.safeTransfer(USER, amountIn);
            // Approve token spending
            vm.prank(USER);
            tokenIn.approve(address(origin.router), amountIn);
        }
    }

    /// @dev Mints the initial balance of the test tokens. Should not be used with Mainnet nUSD.
    function mintInitialTestTokens(
        ChainSetup memory chain,
        address to,
        address token,
        uint256 amount
    ) public {
        if (token == address(chain.wgas)) {
            deal(address(this), amount);
            IWETH9(payable(token)).deposit{value: amount}();
        } else {
            require(!equals(chain.name, "ETH") || token != address(chain.nusd), "Can't mint Nexus nUSD");
            // solhint-disable-next-line no-empty-blocks
            try SynapseERC20(token).mint(address(this), amount) {
                // Mint successful
            } catch {
                // Deal tokens using cheat codes and update the total supply
                deal(token, address(this), amount, true);
            }
        }
        if (to != address(this)) {
            IERC20(token).safeTransfer(to, amount);
        }
    }

    function setupBridgeDeposit(ChainSetup memory chain, IERC20 token) public {
        // Use half of the test contract balance
        uint256 amount = token.balanceOf(address(this)) / 2;
        require(amount != 0, "Failed to setup initial deposit");
        token.safeTransfer(address(chain.bridge), amount);
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
        for (uint256 i = 0; i < tokens.length; ++i) {
            if (destQueries[i].minAmountOut > destQuery.minAmountOut) {
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

    /// @dev Finds the best quote for cross-chain swap using the straightforward logic.
    /// Every symbol is checked as potential candidate for an intermediary bridge token, the best quote is returned.
    function findBestQuotes(
        ChainSetup memory origin,
        ChainSetup memory destination,
        IERC20 tokenIn,
        IERC20 tokenOut,
        uint256 amountIn
    ) public view returns (SwapQuery memory originQuery, SwapQuery memory destQuery) {
        // Check every possible bridge token symbol
        for (uint256 i = 0; i < allSymbols.length; ++i) {
            string memory symbol = allSymbols[i];
            // Get bridge token address on origin and destination chains
            address bridgeTokenOrigin = origin.router.symbolToToken(symbol);
            address bridgeTokenDest = destination.router.symbolToToken(symbol);
            if (bridgeTokenOrigin == address(0) || bridgeTokenDest == address(0)) continue;
            // Find path between tokenIn and bridge token on origin chain: all swap Actions are available
            SwapQuery memory _originQuery = origin.quoter.getAmountOut(
                LimitedToken(ActionLib.allActions(), address(tokenIn)),
                bridgeTokenOrigin,
                amountIn
            );
            // Check that non-zero amount would be bridged to destination chain
            if (_originQuery.minAmountOut == 0) continue;
            uint256 fee = destination.router.calculateBridgeFee(bridgeTokenDest, _originQuery.minAmountOut);
            if (fee >= _originQuery.minAmountOut) continue;
            // Figure out what kind of actions are available for swap on desttination chain
            (LocalBridgeConfig.TokenType tokenType, ) = destination.router.config(bridgeTokenDest);
            uint256 destActionMask = tokenType == LocalBridgeConfig.TokenType.Redeem
                ? ActionLib.mask(Action.Swap)
                : ActionLib.mask(Action.RemoveLiquidity, Action.HandleEth);
            // Find path between bridge token and tokenOut on dest chain. Use amount after bridge fee.
            SwapQuery memory _destQuery = destination.quoter.getAmountOut(
                LimitedToken(destActionMask, address(bridgeTokenDest)),
                address(tokenOut),
                _originQuery.minAmountOut - fee
            );
            if (_destQuery.minAmountOut > destQuery.minAmountOut) {
                originQuery = _originQuery;
                destQuery = _destQuery;
            }
        }
        require(destQuery.minAmountOut != 0, "No path exists");
        originQuery.deadline = block.timestamp;
        destQuery.deadline = block.timestamp + DELAY;
    }

    function checkEqualQueries(
        SwapQuery memory a,
        SwapQuery memory b,
        string memory name
    ) public {
        assertEq(a.swapAdapter, b.swapAdapter, concat(name, ": !swapAdapter"));
        assertEq(a.tokenOut, b.tokenOut, concat(name, ": !tokenOut"));
        assertEq(a.minAmountOut, b.minAmountOut, concat(name, ": !minAmountOut"));
        assertEq(a.deadline, b.deadline, concat(name, ": !deadline"));
        assertEq(a.rawParams.length, b.rawParams.length, concat(name, ": !rawParams"));
        if (a.rawParams.length != 0 && b.rawParams.length != 0) {
            SynapseParams memory paramsA = abi.decode(a.rawParams, (SynapseParams));
            SynapseParams memory paramsB = abi.decode(b.rawParams, (SynapseParams));
            assertEq(uint256(paramsA.action), uint256(paramsB.action), concat(name, ": !action"));
            assertEq(paramsA.pool, paramsB.pool, concat(name, ": !pool"));
            assertEq(
                uint256(paramsA.tokenIndexFrom),
                uint256(paramsB.tokenIndexFrom),
                concat(name, ": !tokenIndexFrom")
            );
            assertEq(uint256(paramsA.tokenIndexTo), uint256(paramsB.tokenIndexTo), concat(name, ": !tokenIndexTo"));
        }
    }

    function getRecipientBalance(ChainSetup memory chain, address token) public view returns (uint256) {
        if (token == address(chain.wgas) || token == address(chain.gas)) {
            return TO.balance;
        } else {
            return IERC20(token).balanceOf(TO);
        }
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                           DEPLOY OVERRIDES                           ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /**
     * @notice Deploys and labels an ERC20 mock. Mints the tokens for tests to this address.
     */
    function deployERC20(
        ChainSetup memory chain,
        string memory symbol,
        uint8 decimals
    ) public returns (ERC20 token) {
        token = deployERC20(concat(chain.name, " ", symbol), decimals);
        mintInitialTestTokens(chain, address(this), address(token), 10**uint256(decimals + 9));
    }

    /**
     * @notice Deploys and labels a SynapseERC20 token.
     * Mints the tokens for tests to this address.
     * Adds token as Redeem bridge token.
     */
    function deploySynapseERC20(
        ChainSetup memory chain,
        string memory symbol,
        uint8 decimals
    ) public returns (IERC20 token) {
        SynapseERC20 _token = deploySynapseERC20(concat(chain.name, " ", symbol), decimals);
        _token.grantRole(_token.MINTER_ROLE(), address(chain.bridge));
        _token.grantRole(_token.MINTER_ROLE(), address(this));
        token = IERC20(address(_token));
        mintInitialTestTokens(chain, address(this), address(token), 10**uint256(decimals + 9));
        _addRedeemToken(chain, symbol, address(token));
    }

    /**
     * @notice Deploys and labels a WETH implementation. Mints the tokens for tests to this address.
     */
    function deployWETH(ChainSetup memory chain, string memory gasName) public returns (IWETH9 token) {
        token = deployWETH(concat(chain.name, " W", gasName));
        chain.wgas = IERC20(address(token));
        mintInitialTestTokens(chain, address(this), address(token), 10**uint256(18 + 9));
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                           INTERNAL HELPERS                           ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function _addDepositToken(
        ChainSetup memory chain,
        string memory symbol,
        address token
    ) internal {
        _addToken(chain.router, symbol, token, LocalBridgeConfig.TokenType.Deposit, token);
        setupBridgeDeposit(chain, IERC20(token));
    }

    function _addRedeemToken(
        ChainSetup memory chain,
        string memory symbol,
        address token
    ) internal {
        _addToken(chain.router, symbol, token, LocalBridgeConfig.TokenType.Redeem, token);
    }

    function _addToken(
        SynapseRouter router,
        string memory symbol,
        address token,
        LocalBridgeConfig.TokenType tokenType,
        address bridgeToken
    ) internal {
        // Set appropriate mock fees for tokens with lower decimals
        uint256 feeDenominator = 10**18 / 10**uint256(ERC20(token).decimals());
        router.addToken(
            symbol,
            token,
            tokenType,
            bridgeToken,
            BRIDGE_FEE / feeDenominator,
            MIN_FEE / feeDenominator,
            MAX_FEE / feeDenominator
        );
    }
}
