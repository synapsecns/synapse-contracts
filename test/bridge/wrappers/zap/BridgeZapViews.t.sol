// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "../../../utils/Utilities06.sol";

import "../../../../contracts/bridge/wrappers/zap/SwapQuoter.sol";
import "../../../../contracts/bridge/wrappers/zap/BridgeZap.sol";

// solhint-disable func-name-mixedcase
// solhint-disable not-rely-on-time
contract BridgeZapViewsTest is Utilities06 {
    SynapseBridge internal bridge;
    SwapQuoter internal quoter;
    BridgeZap internal zap;

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
        zap = new BridgeZap(payable(address(weth)), address(bridge));
        quoter = new SwapQuoter(address(zap));

        quoter.addPool(nEthPool);
        quoter.addPool(nUsdPool);
        quoter.addPool(nexusPool);

        zap.initialize();
        zap.setSwapQuoter(quoter);
        zap.addBurnTokens(_castToArray(address(neth)));
        zap.addBurnTokens(_castToArray(address(nusd)));
        zap.addDepositTokens(_castToArray(address(nexusNusd)));
    }

    function test_getters() public {
        assertEq(address(zap.synapseBridge()), address(bridge), "!synapseBridge");
        assertEq(address(zap.weth()), address(weth), "!weth");
        assertEq(address(zap.swapQuoter()), address(quoter), "!swapQuoter");
    }

    function test_bridgeTokens() public {
        address[] memory tokens = zap.bridgeTokens();
        assertEq(tokens.length, 3, "!bridgeTokens.length");
        assertEq(tokens[0], address(neth), "!bridgeTokens[0]");
        assertEq(tokens[1], address(nusd), "!bridgeTokens[1]");
        assertEq(tokens[2], address(nexusNusd), "!bridgeTokens[2]");
        assertEq(zap.bridgeTokensAmount(), 3, "!bridgeTokensAmount");
    }

    function test_pools() public {
        Pool[] memory pools = zap.allPools();
        assertEq(pools.length, 3, "!allPools.length");
        _checkPool(pools[0], nEthPool, _getLpToken(nEthPool), nEthTokens);
        _checkPool(pools[1], nUsdPool, _getLpToken(nUsdPool), nUsdTokens);
        _checkPool(pools[2], nexusPool, address(nexusNusd), nexusTokens);
        assertEq(zap.poolsAmount(), 3, "!poolsAmounts");
    }

    function test_poolInfo() public {
        _checkPoolInfo(nEthPool, _getLpToken(nEthPool), nEthTokens);
        _checkPoolInfo(nUsdPool, _getLpToken(nUsdPool), nUsdTokens);
        _checkPoolInfo(nexusPool, address(nexusNusd), nexusTokens);
    }

    function _checkPoolInfo(
        address pool,
        address lpToken,
        IERC20[] memory tokens
    ) internal {
        (uint256 amount, address _lpToken) = zap.poolInfo(pool);
        assertEq(amount, tokens.length, "!poolInfo.amount");
        address[] memory _tokens = zap.poolTokens(pool);
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
            assertEq(_pool.tokens[i], address(tokens[i]), "!tokens");
        }
    }

    function _getLpToken(address pool) internal view returns (address) {
        (, , , , , , address _lpToken) = ISwap(pool).swapStorage();
        return _lpToken;
    }

    function _castToArray(address token) internal pure returns (address[] memory tokens) {
        tokens = new address[](1);
        tokens[0] = token;
    }
}
