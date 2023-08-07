// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "../../utils/Utilities06.sol";

import "../../../contracts/bridge/router/SwapQuoter.sol";
import "../../../contracts/bridge/router/SynapseRouter.sol";

// solhint-disable func-name-mixedcase
// solhint-disable not-rely-on-time
contract SynapseRouterViewsTest is Utilities06 {
    SynapseBridge internal bridge;
    SwapQuoter internal quoter;
    SynapseRouter internal router;

    address internal nEthPool;
    IERC20[] internal nEthTokens;
    ERC20 internal neth;
    ERC20 internal weth;

    address internal nUsdPool;
    IERC20[] internal nUsdTokens;
    ERC20 internal nusd;
    ERC20 internal usdc;

    address internal nexusPool;
    IERC20[] internal nexusTokens;
    ERC20 internal nexusNusd;
    ERC20 internal nexusDai;
    ERC20 internal nexusUsdc;
    ERC20 internal nexusUsdt;

    function setUp() public override {
        super.setUp();

        weth = deployERC20("weth", 18);
        neth = deployERC20("neth", 18);
        nusd = deployERC20("nusd", 18);
        usdc = deployERC20("usdc", 6);

        nexusDai = deployERC20("ETH DAI", 18);
        nexusUsdc = deployERC20("ETH USDC", 6);
        nexusUsdt = deployERC20("ETH USDT", 6);

        nEthTokens.push(IERC20(address(neth)));
        nEthTokens.push(IERC20(address(weth)));
        nEthPool = deployPool(nEthTokens);

        nUsdTokens.push(IERC20(address(nusd)));
        nUsdTokens.push(IERC20(address(usdc)));
        nUsdPool = deployPool(nUsdTokens);

        nexusTokens.push(IERC20(address(nexusDai)));
        nexusTokens.push(IERC20(address(nexusUsdc)));
        nexusTokens.push(IERC20(address(nexusUsdt)));
        nexusPool = deployPool(nexusTokens);
        (, , , , , , address _lpToken) = ISwap(nexusPool).swapStorage();
        nexusNusd = ERC20(_lpToken);

        bridge = deployBridge();
        // We're using this contract as owner for testing suite deployments
        router = new SynapseRouter(address(bridge), address(this));
        quoter = SwapQuoter(deploySwapQuoter(address(router), address(weth), address(this)));

        addSwapPool(quoter, address(neth), nEthPool);
        addSwapPool(quoter, address(nusd), nUsdPool);
        addNexusPool();

        router.setSwapQuoter(quoter);
        _addRedeemToken("nETH", address(neth));
        _addRedeemToken("nUSD", address(nusd));
        _addDepositToken("Nexus nUSD", address(nexusNusd));
    }

    function deploySwapQuoter(
        address router_,
        address weth_,
        address owner
    ) internal virtual returns (address) {
        return address(new SwapQuoter(router_, weth_, owner));
    }

    function addSwapPool(
        SwapQuoter swapQuoter,
        address, // bridgeToken
        address pool
    ) public virtual {
        swapQuoter.addPool(pool);
    }

    function addNexusPool() public virtual {
        // Nexus pool is used for add/remove liquidity bridge operations and does not require LinkedPool
        quoter.addPool(nexusPool);
    }

    function addedEthPool() public view virtual returns (address) {
        return nEthPool;
    }

    function addedUsdPool() public view virtual returns (address) {
        return nUsdPool;
    }

    function test_getters() public {
        assertEq(address(router.synapseBridge()), address(bridge), "!synapseBridge");
        assertEq(address(router.swapQuoter()), address(quoter), "!swapQuoter");
    }

    function test_bridgeTokens() public {
        address[] memory tokens = router.bridgeTokens();
        assertEq(tokens.length, 3, "!bridgeTokens.length");
        assertEq(tokens[0], address(neth), "!bridgeTokens[0]");
        assertEq(tokens[1], address(nusd), "!bridgeTokens[1]");
        assertEq(tokens[2], address(nexusNusd), "!bridgeTokens[2]");
        assertEq(router.bridgeTokensAmount(), 3, "!bridgeTokensAmount");
    }

    function test_pools() public {
        Pool[] memory pools = router.allPools();
        assertEq(pools.length, 3, "!allPools.length");
        _checkPool(pools[0], addedEthPool(), _getLpToken(nEthPool), nEthTokens);
        _checkPool(pools[1], addedUsdPool(), _getLpToken(nUsdPool), nUsdTokens);
        _checkPool(pools[2], nexusPool, address(nexusNusd), nexusTokens);
        assertEq(router.poolsAmount(), 3, "!poolsAmounts");
    }

    function test_poolInfo() public {
        _checkPoolInfo(addedEthPool(), _getLpToken(nEthPool), nEthTokens);
        _checkPoolInfo(addedUsdPool(), _getLpToken(nUsdPool), nUsdTokens);
        _checkPoolInfo(nexusPool, address(nexusNusd), nexusTokens);
    }

    function _checkPoolInfo(
        address pool,
        address lpToken,
        IERC20[] memory tokens
    ) internal {
        (uint256 amount, address _lpToken) = router.poolInfo(pool);
        assertEq(amount, tokens.length, "!poolInfo.amount");
        PoolToken[] memory _tokens = router.poolTokens(pool);
        _checkPool(Pool({pool: pool, lpToken: _lpToken, tokens: _tokens}), pool, lpToken, tokens);
    }

    function _checkPool(
        Pool memory _pool,
        address pool,
        address lpToken,
        IERC20[] memory tokens
    ) internal {
        assertEq(_pool.pool, pool, "!pool");
        assertEq(_pool.lpToken, lpToken, "!lpToken");
        assertEq(_pool.tokens.length, tokens.length, "!tokens.length");
        for (uint256 i = 0; i < tokens.length; ++i) {
            IERC20 token = tokens[i];
            assertEq(_pool.tokens[i].token, address(token), "!token");
            assertEq(_pool.tokens[i].isWeth, token == weth, "!isWeth");
        }
    }

    function _getLpToken(address pool) internal view virtual returns (address) {
        (, , , , , , address _lpToken) = ISwap(pool).swapStorage();
        return _lpToken;
    }

    function _addDepositToken(string memory symbol, address token) internal {
        router.addToken(symbol, token, LocalBridgeConfig.TokenType.Deposit, token, 0, 0, 0);
    }

    function _addRedeemToken(string memory symbol, address token) internal {
        router.addToken(symbol, token, LocalBridgeConfig.TokenType.Redeem, token, 0, 0, 0);
    }
}
