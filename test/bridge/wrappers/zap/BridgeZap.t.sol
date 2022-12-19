// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "../../../utils/Utilities06.sol";

import "../../../../contracts/bridge/wrappers/zap/SwapQuoter.sol";
import "../../../../contracts/bridge/wrappers/zap/BridgeZap.sol";

// solhint-disable func-name-mixedcase
contract BridgeZapTest is Utilities06 {
    address internal constant OWNER = address(1337);
    address internal constant USER = address(4242);
    address internal constant TO = address(2424);

    uint256 internal constant ETH_CHAINID = 1;
    uint256 internal constant OPT_CHAINID = 10;

    SynapseBridge internal bridge;
    SwapQuoter internal quoter;
    BridgeZap internal zap;

    address internal nEthPool;
    IERC20[] internal nEthTokens;
    SynapseERC20 internal neth;
    IWETH9 internal weth;

    address internal nUsdPool;
    IERC20[] internal nUsdTokens;
    SynapseERC20 internal nusd;
    ERC20 internal usdc;

    function setUp() public override {
        super.setUp();

        weth = deployWETH();
        neth = deploySynapseERC20("neth");
        nusd = deploySynapseERC20("nusd");
        usdc = deployERC20("usdc", 6);

        {
            uint256[] memory amounts = new uint256[](2);
            amounts[0] = 1000;
            amounts[1] = 1050;
            nEthTokens.push(IERC20(address(neth)));
            nEthTokens.push(IERC20(address(weth)));
            nEthPool = deployPoolWithLiquidity(nEthTokens, amounts);
        }
        {
            uint256[] memory amounts = new uint256[](2);
            amounts[0] = 100000;
            amounts[1] = 100050;
            nUsdTokens.push(IERC20(address(nusd)));
            nUsdTokens.push(IERC20(address(usdc)));
            nUsdPool = deployPoolWithLiquidity(nUsdTokens, amounts);
        }

        bridge = deployBridge();
        zap = new BridgeZap(payable(weth), address(bridge));
        quoter = new SwapQuoter(address(zap));

        quoter.addPool(nEthPool);
        quoter.addPool(nUsdPool);

        _dealAndApprove(address(weth));
        _dealAndApprove(address(neth));
        _dealAndApprove(address(nusd));
        _dealAndApprove(address(usdc));
        deal(USER, 10**20);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                       TESTS: BRIDGE, NO SWAPS                        ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/
    /// @notice Bridge tests (no swaps) are prefixed test_b

    function test_b_deposit() public {
        uint256 amount = 10**18;
        zap.addDepositTokens(_castToArray(address(weth)));
        SwapQuery memory emptyQuery;
        vm.expectEmit(true, true, true, true);
        emit TokenDeposit(TO, OPT_CHAINID, address(weth), amount);
        vm.prank(USER);
        zap.bridge({
            to: TO,
            chainId: OPT_CHAINID,
            token: address(weth),
            amount: amount,
            originQuery: emptyQuery,
            destQuery: emptyQuery
        });
    }

    function test_b_depositETH() public {
        // Make sure user has no WETH
        _unwrapUserWETH();
        uint256 amount = 10**18;
        zap.addDepositTokens(_castToArray(address(weth)));
        SwapQuery memory emptyQuery;
        vm.expectEmit(true, true, true, true);
        emit TokenDeposit(TO, OPT_CHAINID, address(weth), amount);
        vm.prank(USER);
        zap.bridge{value: amount}({
            to: TO,
            chainId: OPT_CHAINID,
            token: address(weth),
            amount: amount,
            originQuery: emptyQuery,
            destQuery: emptyQuery
        });
    }

    function test_b_redeem() public {
        uint256 amount = 10**18;
        zap.addBurnTokens(_castToArray(address(neth)));
        SwapQuery memory emptyQuery;
        vm.expectEmit(true, true, true, true);
        emit TokenRedeem(TO, OPT_CHAINID, address(neth), amount);
        vm.prank(USER);
        zap.bridge({
            to: TO,
            chainId: OPT_CHAINID,
            token: address(neth),
            amount: amount,
            originQuery: emptyQuery,
            destQuery: emptyQuery
        });
    }

    function test_b_redeem_nusd() public {
        uint256 amount = 10**18;
        zap.addBurnNusd(address(nusd));
        SwapQuery memory emptyQuery;
        vm.expectEmit(true, true, true, true);
        emit TokenRedeem(TO, ETH_CHAINID, address(nusd), amount);
        vm.prank(USER);
        zap.bridge({
            to: TO,
            chainId: ETH_CHAINID,
            token: address(nusd),
            amount: amount,
            originQuery: emptyQuery,
            destQuery: emptyQuery
        });
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                         TESTS: SWAP & BRIDGE                         ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/
    /// @notice Swap & Bridge tests are prefixed test_sb

    function test_sb_swapAndRedeem() public {
        uint256 amount = 10**18;
        zap.addBurnTokens(_castToArray(address(neth)));
        SwapQuery memory emptyQuery;
        // weth -> neth on origin chain
        uint256 amountOut = ISwap(nEthPool).calculateSwap(1, 0, amount);
        SwapQuery memory originQuery = quoter.getAmountOut(address(weth), address(neth), amount);
        vm.expectEmit(true, true, true, true);
        emit TokenRedeem(TO, ETH_CHAINID, address(neth), amountOut);
        vm.prank(USER);
        // Swap (weth -> neth), then bridge neth
        zap.bridge({
            to: TO,
            chainId: ETH_CHAINID,
            token: address(weth),
            amount: amount,
            originQuery: originQuery,
            destQuery: emptyQuery
        });
    }

    function test_sb_swapAndRedeem_nUSD() public {
        uint256 amount = 10**6;
        zap.addBurnNusd(address(nusd));
        SwapQuery memory emptyQuery;
        // usdc -> nusd on origin chain
        uint256 amountOut = ISwap(nUsdPool).calculateSwap(1, 0, amount);
        SwapQuery memory originQuery = quoter.getAmountOut(address(usdc), address(nusd), amount);
        vm.expectEmit(true, true, true, true);
        emit TokenRedeem(TO, ETH_CHAINID, address(nusd), amountOut);
        vm.prank(USER);
        // Swap (usdc -> nusd), then bridge nusd
        zap.bridge({
            to: TO,
            chainId: ETH_CHAINID,
            token: address(usdc),
            amount: amount,
            originQuery: originQuery,
            destQuery: emptyQuery
        });
    }

    function test_sb_swapETHAndRedeem() public {
        // Make sure user has no WETH
        _unwrapUserWETH();
        uint256 amount = 10**18;
        zap.addBurnTokens(_castToArray(address(neth)));
        SwapQuery memory emptyQuery;
        // weth -> neth on origin chain
        uint256 amountOut = ISwap(nEthPool).calculateSwap(1, 0, amount);
        SwapQuery memory originQuery = quoter.getAmountOut(address(weth), address(neth), amount);
        vm.expectEmit(true, true, true, true);
        emit TokenRedeem(TO, ETH_CHAINID, address(neth), amountOut);
        vm.prank(USER);
        // Wrap ETH, swap (weth -> neth), then bridge neth
        zap.bridge{value: amount}({
            to: TO,
            chainId: ETH_CHAINID,
            token: address(weth),
            amount: amount,
            originQuery: originQuery,
            destQuery: emptyQuery
        });
    }

    function test_sb_zapAndDeposit_nUSD() public {
        // TODO: add support for zapping into nUSD on Ethereum
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                           INTERNAL HELPERS                           ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function _dealAndApprove(address token) internal {
        if (token == address(weth)) {
            deal(USER, 10**20);
            vm.prank(USER);
            weth.deposit{value: 10**20}();
        } else {
            // update total supply
            deal(token, USER, 10**20, true);
        }
        vm.prank(USER);
        IERC20(token).approve(address(zap), type(uint256).max);
    }

    function _unwrapUserWETH() internal {
        uint256 balance = weth.balanceOf(USER);
        vm.prank(USER);
        weth.withdraw(balance);
    }

    function _castToArray(address token) internal pure returns (address[] memory tokens) {
        tokens = new address[](1);
        tokens[0] = token;
    }
}
