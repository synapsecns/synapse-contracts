// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "./DefaultVaultTest.t.sol";

import {Offers} from "src-router/libraries/LibOffers.sol";
import {IAdapter} from "src-router/interfaces/IAdapter.sol";
import {ISynapse} from "src-router/adapters/synapse/interfaces/ISynapse.sol";
import {IUniswapV2Factory} from "src-router/adapters/uniswap/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "src-router/adapters/uniswap/interfaces/IUniswapV2Pair.sol";

import {SynapseBaseTwoAdapter} from "src-router/adapters/synapse/base/SynapseBaseTwoAdapter.sol";
import {SynapseBaseThreeAdapter} from "src-router/adapters/synapse/base/SynapseBaseThreeAdapter.sol";
import {UniswapV2Adapter} from "src-router/adapters/uniswap/UniswapV2Adapter.sol";

import {Swap08} from "src-amm08/Swap08.sol";
import {IWETH9} from "src-bridge/interfaces/IWETH9.sol";

contract DefaultRouterTest is DefaultVaultTest {
    struct Tokens {
        IERC20 nETH;
        IERC20 wETH;
        IERC20 nUSD;
        IERC20 dai;
        IERC20 usdc;
        IERC20 frax;
        IERC20 wBTC;
        IERC20 syn;
        IERC20 gOHM;
    }

    struct Pools {
        ISynapse nETHPool;
        ISynapse nUSDPool;
        ISynapse poolFRAX;
        IUniswapV2Factory uniswapFactoryAAA;
        IUniswapV2Factory uniswapFactoryBBB;
    }

    struct Adapters {
        IAdapter nETHAdapter;
        IAdapter nUSDAdapter;
        IAdapter fraxAdapter;
        IAdapter uniswapAAA;
        IAdapter uniswapBBB;
    }

    Tokens public _tokens;
    Pools public _pools;
    Adapters public _adapters;

    address[] public allAdapters;
    address[] public routeTokens;
    address[] public bridgeTokens;

    mapping(address => uint8) public routeIndex;
    uint8 public constant WETH_INDEX = 0;

    constructor() DefaultVaultTest(defaultConfig) {
        this;
    }

    function setUp() public virtual override {
        _tokens.wETH = _deployWETH("wETH");
        _config.wgas = payable(address(_tokens.wETH));
        super.setUp();

        _tokens.nETH = _deployERC20("nETH");

        _tokens.nUSD = _deployERC20("nUSD");
        _tokens.dai = _deployERC20("DAI");
        _tokens.usdc = _deployERC20Decimals("USDC", 6);

        _tokens.frax = _deployERC20("FRAX");

        _tokens.wBTC = _deployERC20Decimals("wBTC", 8);
        _tokens.syn = _deployERC20("SYN");
        _tokens.gOHM = _deployERC20Decimals("gOHM", 9);

        // using only ETH and stables as intermediate tokens
        routeTokens = new address[](4);
        _saveRouteToken(address(_tokens.wETH), 0);
        _saveRouteToken(address(_tokens.dai), 1);
        _saveRouteToken(address(_tokens.usdc), 2);
        _saveRouteToken(address(_tokens.frax), 3);

        bridgeTokens.push(address(_tokens.nETH));
        bridgeTokens.push(address(_tokens.nUSD));
        bridgeTokens.push(address(_tokens.syn));

        address lpToken = deployCode("./artifacts/LPToken.sol/LPToken.json");

        {
            IERC20[] memory tokens = new IERC20[](2);
            tokens[0] = _tokens.nETH;
            tokens[1] = _tokens.wETH;
            (_pools.nETHPool, _adapters.nETHAdapter) = _deploySynapsePool(
                tokens,
                10000,
                "nETH pool",
                "Synapse ETH",
                "ETH-LP",
                lpToken
            );
        }

        {
            IERC20[] memory tokens = new IERC20[](3);
            tokens[0] = _tokens.nUSD;
            tokens[1] = _tokens.dai;
            tokens[2] = _tokens.usdc;
            (_pools.nUSDPool, _adapters.nUSDAdapter) = _deploySynapsePool(
                tokens,
                10**7,
                "nUSD pool",
                "Synapse USD",
                "USD-LP",
                lpToken
            );
        }

        {
            IERC20[] memory tokens = new IERC20[](2);
            tokens[0] = _tokens.frax;
            tokens[1] = _tokens.usdc;
            (_pools.nETHPool, _adapters.nETHAdapter) = _deploySynapsePool(
                tokens,
                10**6,
                "FRAX pool",
                "FRAX USDC",
                "FRAX-LP",
                lpToken
            );
        }

        (_pools.uniswapFactoryAAA, _adapters.uniswapAAA) = _deployUniswapFactory("Factory AAA", "Uniswap AAA");
        (_pools.uniswapFactoryBBB, _adapters.uniswapBBB) = _deployUniswapFactory("Factory BBB", "Uniswap BBB");

        _deployUniswapPair(_pools.uniswapFactoryAAA, "AAA: WETH/USDC", _tokens.wETH, _tokens.usdc, 100, 100 * 100);
        _deployUniswapPair(_pools.uniswapFactoryAAA, "AAA: WBTC/DAI", _tokens.wBTC, _tokens.dai, 50, 50 * 1000);
        _deployUniswapPair(_pools.uniswapFactoryAAA, "AAA: WETH/SYN", _tokens.wETH, _tokens.syn, 200, 200 * 10);
        _deployUniswapPair(_pools.uniswapFactoryAAA, "AAA: DAI/USDC", _tokens.dai, _tokens.usdc, 100, 110);
        _deployUniswapPair(_pools.uniswapFactoryAAA, "AAA: WETH/FRAX", _tokens.wETH, _tokens.frax, 100, 100 * 99);
        _deployUniswapPair(_pools.uniswapFactoryAAA, "AAA: SYN/FRAX", _tokens.syn, _tokens.frax, 1000, 1000 * 10);
        _deployUniswapPair(_pools.uniswapFactoryAAA, "AAA: gOHM/DAI", _tokens.gOHM, _tokens.dai, 100000, 110000);

        _deployUniswapPair(_pools.uniswapFactoryBBB, "BBB: WETH/DAI", _tokens.wETH, _tokens.dai, 50, 50 * 105);
        _deployUniswapPair(_pools.uniswapFactoryBBB, "BBB: WBTC/USDC", _tokens.wBTC, _tokens.usdc, 100, 100 * 980);
        _deployUniswapPair(_pools.uniswapFactoryBBB, "BBB: WETH/SYN", _tokens.wETH, _tokens.syn, 50, 50 * 11);
        _deployUniswapPair(_pools.uniswapFactoryBBB, "BBB: DAI/USDC", _tokens.dai, _tokens.usdc, 1000, 990);
        _deployUniswapPair(_pools.uniswapFactoryBBB, "BBB: WBTC/FRAX", _tokens.wBTC, _tokens.frax, 10, 10 * 1005);
        _deployUniswapPair(_pools.uniswapFactoryBBB, "BBB: WETH/gOHM", _tokens.wETH, _tokens.gOHM, 1000, 1000 * 95);

        startHoax(governance);
        quoter.setAdapters(allAdapters);
        quoter.setTokens(routeTokens);
        vm.stopPrank();
    }

    function _deployWETH(string memory name) internal returns (IERC20 token) {
        token = IERC20(deployCode("./artifacts/WETH9.sol/WETH9.json"));
        vm.label(address(token), name);
        _addToken(address(token));
    }

    // deal token and update totalSupply
    // custom logic for wETH, as totalSupply is amount of ether stored in WETH contract
    function _dealToken(
        IERC20 token,
        address who,
        uint256 amount
    ) internal {
        if (address(token) == address(_tokens.wETH)) {
            deal(who, amount);
            hoax(who);
            IWETH9(payable(address(token))).deposit{value: amount}();
        } else {
            deal(address(token), who, amount, true);
        }
    }

    function _getMinFee(address bridgeToken) internal view returns (uint256 minFee) {
        // minFee is approx $1 for each token
        if (bridgeToken == address(_tokens.nETH)) {
            // ETH costs ~$100 in this testing suite
            minFee = 10**16;
        } else if (bridgeToken == address(_tokens.syn)) {
            // SYN costs ~$10 in this testing suite
            minFee = 10**17;
        } else if (bridgeToken == address(_tokens.nUSD)) {
            // nUSD costs exactly $1 even in timeline where Thanos wins
            minFee = 10**18;
        }
    }

    function _saveRouteToken(address token, uint8 index) internal {
        routeTokens[index] = token;
        // start from 1, so default zero value => not a route token
        routeIndex[token] = index + 1;
    }

    function _deploySynapsePool(
        IERC20[] memory tokens,
        uint256 initialLiq,
        string memory poolName,
        string memory adapterName,
        string memory lpTokenName,
        address lpTokenTargetAddress
    ) internal returns (ISynapse pool, IAdapter adapter) {
        // pool = ISynapse(
        //     deployCode("./artifacts/SwapFlattened.sol/SwapFlattened.json")
        // );
        pool = ISynapse(address(new Swap08()));

        uint8[] memory decimals = new uint8[](tokens.length);

        for (uint256 i = 0; i < tokens.length; ++i) {
            decimals[i] = tokens[i].decimals();
        }

        (bool success, bytes memory returnData) = address(pool).call(
            abi.encodeWithSelector(
                pool.initialize.selector,
                tokens,
                decimals,
                lpTokenName,
                lpTokenName,
                1000, // A = 1000
                10**6, // fee = 1 bp
                6 * 10**9, // adminFee = 60%,
                lpTokenTargetAddress
            )
        );
        assertTrue(success, utils.getRevertMsg(returnData));

        uint256[] memory amounts = new uint256[](tokens.length);

        for (uint256 i = 0; i < tokens.length; ++i) {
            amounts[i] = initialLiq * 10**decimals[i];
            _dealToken(tokens[i], address(this), amounts[i]);
            tokens[i].approve(address(pool), MAX_UINT);
        }

        pool.addLiquidity(amounts, 0, MAX_UINT);

        if (tokens.length == 2) {
            adapter = new SynapseBaseTwoAdapter(adapterName, 0, address(pool));
        } else if (tokens.length == 3) {
            adapter = new SynapseBaseThreeAdapter(adapterName, 0, address(pool));
        } else {
            revert("Unexpected amount of tokens");
        }

        allAdapters.push(address(adapter));

        vm.label(address(pool), poolName);
        vm.label(address(adapter), adapterName);
    }

    function _deployUniswapFactory(string memory factoryName, string memory adapterName)
        internal
        returns (IUniswapV2Factory factory, IAdapter adapter)
    {
        factory = IUniswapV2Factory(
            deployCode("./artifacts/UniswapV2Factory.sol/UniswapV2Factory.json", abi.encode(0))
        );
        adapter = new UniswapV2Adapter(
            adapterName,
            0,
            address(factory),
            factory.pairCodeHash(),
            30 // 30 bp = 0.3%
        );
        allAdapters.push(address(adapter));

        vm.label(address(factory), factoryName);
        vm.label(address(adapter), adapterName);
    }

    function _deployUniswapPair(
        IUniswapV2Factory factory,
        string memory pairName,
        IERC20 tokenA,
        IERC20 tokenB,
        uint256 amountA,
        uint256 amountB
    ) internal {
        if (address(tokenA) < address(tokenB)) {
            _deployUniswapSortedPair(factory, pairName, tokenA, tokenB, amountA, amountB);
        } else {
            _deployUniswapSortedPair(factory, pairName, tokenB, tokenA, amountB, amountA);
        }
    }

    function _deployUniswapSortedPair(
        IUniswapV2Factory factory,
        string memory pairName,
        IERC20 token0,
        IERC20 token1,
        uint256 amount0,
        uint256 amount1
    ) internal {
        address pair = factory.createPair(address(token0), address(token1));
        // provide initial liquidity
        _dealToken(token0, pair, amount0 * 10**token0.decimals());
        _dealToken(token1, pair, amount1 * 10**token1.decimals());
        IUniswapV2Pair(pair).mint(address(this));

        vm.label(pair, pairName);
    }

    function _bruteForcePath(
        uint256 swapsLeft,
        address tokenCur,
        uint256 amountCur,
        address tokenOut,
        bool[] memory isTokenUsed
    ) internal returns (uint256 foundAmountOut) {
        if (tokenOut == tokenCur) {
            return amountCur;
        }
        if (swapsLeft == 0 || amountCur == 0) {
            return 0;
        }

        /**
         * @dev I'm quite aware that this implementation is very far from being
         * optimal. For testing, however, we need the simplest implementation,
         * which differs from one we're testing against.
         * Optimal would be to iterate through tokens first, then through adapters,
         * and pick the best yielding adapter for selected token. This is, however,
         * already being done in Quoter.findBestPath(), so we're using a dumber yet simpler approach.
         */
        for (uint256 a = 0; a < allAdapters.length; a++) {
            bool wasTokenOut = false;
            for (uint256 t = 0; t < routeTokens.length; t++) {
                if (isTokenUsed[t]) {
                    continue;
                }
                address tokenNext = routeTokens[t];
                if (tokenNext == tokenOut) {
                    wasTokenOut = true;
                }
                uint256 amountOut = IAdapter(allAdapters[a]).query(amountCur, tokenCur, tokenNext);
                if (amountOut > 0) {
                    isTokenUsed[t] = true;
                    uint256 finalOut = _bruteForcePath(swapsLeft - 1, tokenNext, amountOut, tokenOut, isTokenUsed);
                    if (finalOut > foundAmountOut) {
                        foundAmountOut = finalOut;
                    }
                    isTokenUsed[t] = false;
                }
            }
            {
                uint256 amountOut = IAdapter(allAdapters[a]).query(amountCur, tokenCur, tokenOut);
                if (amountOut > 0) {
                    uint256 finalOut = _bruteForcePath(swapsLeft - 1, tokenOut, amountOut, tokenOut, isTokenUsed);
                    if (finalOut > foundAmountOut) {
                        foundAmountOut = finalOut;
                    }
                }
            }
        }
    }

    function _logOffer(Offers.FormattedOffer memory offer) internal {
        for (uint256 i = 0; i < offer.path.length; ++i) {
            emit log_address(offer.path[i]);
        }
        for (uint256 i = 0; i < offer.adapters.length; ++i) {
            emit log_address(offer.adapters[i]);
        }
        for (uint256 i = 0; i < offer.amounts.length; ++i) {
            emit log_uint(offer.amounts[i]);
        }
    }

    /**
     * @notice Finds a test bridge token, and returns its index in allTokens array.
     */
    function _getBridgeToken(uint8 _indexTo) internal returns (address bridgeToken, uint8 indexTo) {
        vm.assume(_indexTo < bridgeTokens.length);
        bridgeToken = bridgeTokens[_indexTo];

        indexTo = tokenIndexes[bridgeToken];
        require(indexTo > 0, "Unknown token found");
        --indexTo;
    }

    function _askQuoter(
        uint8 maxSwaps,
        uint8 indexFrom,
        uint8 indexTo,
        uint64 _amountIn
    )
        internal
        returns (
            Offers.FormattedOffer memory offer,
            uint256 amountIn,
            uint256 amountOut
        )
    {
        vm.assume(indexFrom < allTokens.length);
        vm.assume(indexTo < allTokens.length);
        vm.assume(indexFrom != indexTo);
        vm.assume(_amountIn > 0);

        // use at least 1<<20 (~1e6) for amountIn
        amountIn = uint256(_amountIn) << 20;

        offer = quoter.findBestPath(allTokens[indexFrom], amountIn, allTokens[indexTo], maxSwaps);

        // Ignore runs where there is no path between tokens
        vm.assume(offer.path.length > 0);

        amountOut = offer.amounts[offer.amounts.length - 1];
    }
}
