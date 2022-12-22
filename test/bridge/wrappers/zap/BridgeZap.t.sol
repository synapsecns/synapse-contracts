// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "../../../utils/Utilities06.sol";

import "../../../../contracts/bridge/wrappers/zap/SwapQuoter.sol";
import "../../../../contracts/bridge/wrappers/zap/BridgeZap.sol";

// solhint-disable func-name-mixedcase
// solhint-disable not-rely-on-time
contract BridgeZapTest is Utilities06 {
    address internal constant OWNER = address(1337);
    address internal constant USER = address(4242);
    address internal constant TO = address(2424);

    uint256 internal constant ETH_CHAINID = 1;
    uint256 internal constant OPT_CHAINID = 10;
    uint256 internal constant DEADLINE = 4815162342;

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

    address internal nexusPool;
    IERC20[] internal nexusTokens;
    ERC20 internal nexusNusd;
    ERC20 internal nexusDai;
    ERC20 internal nexusUsdc;
    ERC20 internal nexusUsdt;

    function setUp() public override {
        super.setUp();

        weth = deployWETH();
        neth = deploySynapseERC20("neth");
        nusd = deploySynapseERC20("nusd");
        usdc = deployERC20("usdc", 6);

        nexusDai = deployERC20("ETH DAI", 18);
        nexusUsdc = deployERC20("ETH USDC", 6);
        nexusUsdt = deployERC20("ETH USDT", 6);

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
        {
            uint256[] memory amounts = new uint256[](3);
            amounts[0] = 1000000;
            amounts[1] = 1002000;
            amounts[2] = 1003000;
            nexusTokens.push(IERC20(address(nexusDai)));
            nexusTokens.push(IERC20(address(nexusUsdc)));
            nexusTokens.push(IERC20(address(nexusUsdt)));
            nexusPool = deployPoolWithLiquidity(nexusTokens, amounts);
        }

        bridge = deployBridge();
        zap = new BridgeZap(payable(weth), address(bridge));
        quoter = new SwapQuoter(address(zap));

        quoter.addPool(nEthPool);
        quoter.addPool(nUsdPool);
        quoter.addPool(nexusPool);
        (, address nexusLpToken) = quoter.poolInfo(nexusPool);
        nexusNusd = ERC20(nexusLpToken);

        zap.initialize();
        zap.setSwapQuoter(quoter);

        _dealAndApprove(address(weth));
        _dealAndApprove(address(neth));
        _dealAndApprove(address(nusd));
        _dealAndApprove(address(usdc));
        _dealAndApprove(address(nexusUsdc));
        deal(address(nexusUsdc), address(this), 10**20);
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
        zap.addBurnTokens(_castToArray(address(nusd)));
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
        zap.addBurnTokens(_castToArray(address(nusd)));
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
        uint256 amount = 10**6;
        zap.addDepositTokens(_castToArray(address(nexusNusd)));
        SwapQuery memory emptyQuery;
        // usdc -> nusd (addLiquidity) on origin chain
        uint256[] memory amounts = new uint256[](nexusTokens.length);
        amounts[1] = amount; // USDC index is 1
        uint256 amountOut = quoter.calculateAddLiquidity(nexusPool, amounts);
        // Deposit usdc to receive nusd on origin chain
        SwapQuery memory originQuery = quoter.getAmountOut(address(nexusUsdc), address(nexusNusd), amount);
        vm.expectEmit(true, true, true, true);
        emit TokenDeposit(TO, OPT_CHAINID, address(nexusNusd), amountOut);
        vm.prank(USER);
        zap.bridge({
            to: TO,
            chainId: OPT_CHAINID,
            token: address(nexusUsdc),
            amount: amount,
            originQuery: originQuery,
            destQuery: emptyQuery
        });
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                         TESTS: BRIDGE & SWAP                         ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/
    /// @notice Bridge & Swap tests are prefixed test_bs

    function test_bs_depositAndSwap() public {
        uint256 amount = 10**18;
        zap.addDepositTokens(_castToArray(address(weth)));
        SwapQuery memory emptyQuery;
        // Emulate bridge fees
        uint256 amountInDest = (amount * 999) / 1000;
        // neth -> weth on dest chain
        uint256 amountOut = ISwap(nEthPool).calculateSwap(0, 1, amountInDest);
        SwapQuery memory destQuery = quoter.getAmountOut(address(neth), address(weth), amountInDest);
        destQuery.deadline = DEADLINE;
        vm.expectEmit(true, true, true, true);
        emit TokenDepositAndSwap({
            to: TO,
            chainId: OPT_CHAINID,
            token: address(weth),
            amount: amount,
            tokenIndexFrom: 0,
            tokenIndexTo: 1,
            minDy: amountOut,
            deadline: DEADLINE
        });
        vm.prank(USER);
        // Bridge weth, swap neth -> weth on dest chain
        zap.bridge({
            to: TO,
            chainId: OPT_CHAINID,
            token: address(weth),
            amount: amount,
            originQuery: emptyQuery,
            destQuery: destQuery
        });
    }

    function test_bs_depositETHAndSwap() public {
        // Make sure user has no WETH
        _unwrapUserWETH();
        uint256 amount = 10**18;
        zap.addDepositTokens(_castToArray(address(weth)));
        SwapQuery memory emptyQuery;
        // Emulate bridge fees
        uint256 amountInDest = (amount * 999) / 1000;
        // neth -> weth on dest chain
        uint256 amountOut = ISwap(nEthPool).calculateSwap(0, 1, amountInDest);
        SwapQuery memory destQuery = quoter.getAmountOut(address(neth), address(weth), amountInDest);
        destQuery.deadline = DEADLINE;
        vm.expectEmit(true, true, true, true);
        emit TokenDepositAndSwap({
            to: TO,
            chainId: OPT_CHAINID,
            token: address(weth),
            amount: amount,
            tokenIndexFrom: 0,
            tokenIndexTo: 1,
            minDy: amountOut,
            deadline: DEADLINE
        });
        vm.prank(USER);
        // Wrap ETH, bridge weth, swap neth -> weth on dest chain
        zap.bridge{value: amount}({
            to: TO,
            chainId: OPT_CHAINID,
            token: address(weth),
            amount: amount,
            originQuery: emptyQuery,
            destQuery: destQuery
        });
    }

    function test_bs_redeemAndSwap() public {
        uint256 amount = 10**18;
        zap.addBurnTokens(_castToArray(address(neth)));
        SwapQuery memory emptyQuery;
        // Emulate bridge fees
        uint256 amountInDest = (amount * 999) / 1000;
        // neth -> weth on dest chain
        uint256 amountOut = ISwap(nEthPool).calculateSwap(0, 1, amountInDest);
        SwapQuery memory destQuery = quoter.getAmountOut(address(neth), address(weth), amountInDest);
        destQuery.deadline = DEADLINE;
        vm.expectEmit(true, true, true, true);
        emit TokenRedeemAndSwap({
            to: TO,
            chainId: OPT_CHAINID,
            token: address(neth),
            amount: amount,
            tokenIndexFrom: 0,
            tokenIndexTo: 1,
            minDy: amountOut,
            deadline: DEADLINE
        });
        vm.prank(USER);
        // Bridge neth, swap neth -> weth on dest chain
        zap.bridge({
            to: TO,
            chainId: OPT_CHAINID,
            token: address(neth),
            amount: amount,
            originQuery: emptyQuery,
            destQuery: destQuery
        });
    }

    function test_bs_redeemAndSwap_nUSD() public {
        uint256 amount = 10**18;
        zap.addBurnTokens(_castToArray(address(nusd)));
        SwapQuery memory emptyQuery;
        // Emulate bridge fees
        uint256 amountInDest = (amount * 999) / 1000;
        // nusd -> usdc on dest chain
        uint256 amountOut = ISwap(nUsdPool).calculateSwap(0, 1, amountInDest);
        SwapQuery memory destQuery = quoter.getAmountOut(address(nusd), address(usdc), amountInDest);
        destQuery.deadline = DEADLINE;
        vm.expectEmit(true, true, true, true);
        emit TokenRedeemAndSwap({
            to: TO,
            chainId: OPT_CHAINID,
            token: address(nusd),
            amount: amount,
            tokenIndexFrom: 0,
            tokenIndexTo: 1,
            minDy: amountOut,
            deadline: DEADLINE
        });
        vm.prank(USER);
        // Bridge nusd, swap nusd -> usdc on dest chain
        zap.bridge({
            to: TO,
            chainId: OPT_CHAINID,
            token: address(nusd),
            amount: amount,
            originQuery: emptyQuery,
            destQuery: destQuery
        });
    }

    function test_bs_redeemAndRemove_nUSD() public {
        uint256 amount = 10**18;
        zap.addBurnTokens(_castToArray(address(nusd)));
        SwapQuery memory emptyQuery;
        // Emulate bridge fees
        uint256 amountInDest = (amount * 999) / 1000;
        // nusd -> usdc on dest chain
        uint256 amountOut = ISwap(nexusPool).calculateRemoveLiquidityOneToken(amountInDest, 1);
        SwapQuery memory destQuery = quoter.getAmountOut(address(nexusNusd), address(nexusUsdc), amountInDest);
        destQuery.deadline = DEADLINE;
        vm.expectEmit(true, true, true, true);
        emit TokenRedeemAndRemove({
            to: TO,
            chainId: ETH_CHAINID,
            token: address(nusd),
            amount: amount,
            swapTokenIndex: 1,
            swapMinAmount: amountOut,
            swapDeadline: DEADLINE
        });
        vm.prank(USER);
        // Bridge nusd, withdraw nusd -> usdc on dest chain
        zap.bridge({
            to: TO,
            chainId: ETH_CHAINID,
            token: address(nusd),
            amount: amount,
            originQuery: emptyQuery,
            destQuery: destQuery
        });
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                     TESTS: SWAP & BRIDGE & SWAP                      ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/
    /// @notice Swap & Bridge & Swap tests are prefixed test_sbs

    function test_sbs_swapAndRedeemAndSwap() public {
        uint256 amount = 10**18;
        zap.addBurnTokens(_castToArray(address(neth)));
        // weth -> neth on origin chain
        uint256 amountOutOrigin = ISwap(nEthPool).calculateSwap(1, 0, amount);
        SwapQuery memory originQuery = quoter.getAmountOut(address(weth), address(neth), amount);
        originQuery.deadline = block.timestamp;
        // Emulate bridge fees
        uint256 amountInDest = (amountOutOrigin * 999) / 1000;
        // neth -> weth on dest chain
        uint256 amountOutDest = ISwap(nEthPool).calculateSwap(0, 1, amountInDest);
        SwapQuery memory destQuery = quoter.getAmountOut(address(neth), address(weth), amountInDest);
        destQuery.deadline = DEADLINE;
        vm.expectEmit(true, true, true, true);
        emit TokenRedeemAndSwap({
            to: TO,
            chainId: OPT_CHAINID,
            token: address(neth),
            amount: amountOutOrigin,
            tokenIndexFrom: 0,
            tokenIndexTo: 1,
            minDy: amountOutDest,
            deadline: DEADLINE
        });
        vm.prank(USER);
        // Swap weth -> neth, bridge neth, swap neth -> weth on dest chain
        zap.bridge({
            to: TO,
            chainId: OPT_CHAINID,
            token: address(weth),
            amount: amount,
            originQuery: originQuery,
            destQuery: destQuery
        });
    }

    function test_sbs_swapETHAndRedeemAndSwap() public {
        // Make sure user has no WETH
        _unwrapUserWETH();
        uint256 amount = 10**18;
        zap.addBurnTokens(_castToArray(address(neth)));
        // weth -> neth on origin chain
        uint256 amountOutOrigin = ISwap(nEthPool).calculateSwap(1, 0, amount);
        SwapQuery memory originQuery = quoter.getAmountOut(address(weth), address(neth), amount);
        originQuery.deadline = block.timestamp;
        // Emulate bridge fees
        uint256 amountInDest = (amountOutOrigin * 999) / 1000;
        // neth -> weth on dest chain
        uint256 amountOutDest = ISwap(nEthPool).calculateSwap(0, 1, amountInDest);
        SwapQuery memory destQuery = quoter.getAmountOut(address(neth), address(weth), amountInDest);
        destQuery.deadline = DEADLINE;
        vm.expectEmit(true, true, true, true);
        emit TokenRedeemAndSwap({
            to: TO,
            chainId: OPT_CHAINID,
            token: address(neth),
            amount: amountOutOrigin,
            tokenIndexFrom: 0,
            tokenIndexTo: 1,
            minDy: amountOutDest,
            deadline: DEADLINE
        });
        vm.prank(USER);
        // Swap weth -> neth, bridge neth, swap neth -> weth on dest chain
        zap.bridge{value: amount}({
            to: TO,
            chainId: OPT_CHAINID,
            token: address(weth),
            amount: amount,
            originQuery: originQuery,
            destQuery: destQuery
        });
    }

    function test_sbs_swapAndRedeemAndSwap_nUSD() public {
        uint256 amount = 10**6;
        zap.addBurnTokens(_castToArray(address(nusd)));
        // usdc -> nusd on origin chain
        uint256 amountOutOrigin = ISwap(nUsdPool).calculateSwap(1, 0, amount);
        SwapQuery memory originQuery = quoter.getAmountOut(address(usdc), address(nusd), amount);
        originQuery.deadline = block.timestamp;
        // Emulate bridge fees
        uint256 amountInDest = (amountOutOrigin * 999) / 1000;
        // nusd -> usdc on dest chain
        uint256 amountOutDest = ISwap(nUsdPool).calculateSwap(0, 1, amountInDest);
        SwapQuery memory destQuery = quoter.getAmountOut(address(nusd), address(usdc), amountInDest);
        destQuery.deadline = DEADLINE;
        vm.expectEmit(true, true, true, true);
        emit TokenRedeemAndSwap({
            to: TO,
            chainId: OPT_CHAINID,
            token: address(nusd),
            amount: amountOutOrigin,
            tokenIndexFrom: 0,
            tokenIndexTo: 1,
            minDy: amountOutDest,
            deadline: DEADLINE
        });
        vm.prank(USER);
        // Swap usdc -> nusd, bridge nusd, swap nusd -> usdc on dest chain
        zap.bridge({
            to: TO,
            chainId: OPT_CHAINID,
            token: address(usdc),
            amount: amount,
            originQuery: originQuery,
            destQuery: destQuery
        });
    }

    function test_sbs_swapAndRedeemAndRemove_nUSD() public {
        uint256 amount = 10**6;
        zap.addBurnTokens(_castToArray(address(nusd)));
        // usdc -> nusd on origin chain
        uint256 amountOutOrigin = ISwap(nUsdPool).calculateSwap(1, 0, amount);
        SwapQuery memory originQuery = quoter.getAmountOut(address(usdc), address(nusd), amount);
        originQuery.deadline = block.timestamp;
        // Emulate bridge fees
        uint256 amountInDest = (amountOutOrigin * 999) / 1000;
        // withdraw nusd -> usdc on dest chain
        uint256 amountOutDest = ISwap(nexusPool).calculateRemoveLiquidityOneToken(amountInDest, 1);
        SwapQuery memory destQuery = quoter.getAmountOut(address(nexusNusd), address(nexusUsdc), amountInDest);
        destQuery.deadline = DEADLINE;
        vm.expectEmit(true, true, true, true);
        emit TokenRedeemAndRemove({
            to: TO,
            chainId: ETH_CHAINID,
            token: address(nusd),
            amount: amountOutOrigin,
            swapTokenIndex: 1,
            swapMinAmount: amountOutDest,
            swapDeadline: DEADLINE
        });
        vm.prank(USER);
        // Swap usdc -> nusd, bridge nusd, withdraw nusd -> usdc on dest chain
        zap.bridge({
            to: TO,
            chainId: ETH_CHAINID,
            token: address(usdc),
            amount: amount,
            originQuery: originQuery,
            destQuery: destQuery
        });
    }

    function test_sbs_zapAndDepositAndSwap() public {
        uint256 amount = 10**6;
        zap.addDepositTokens(_castToArray(address(nexusNusd)));
        // usdc -> nusd (addLiquidity) on origin chain
        uint256[] memory amounts = new uint256[](nexusTokens.length);
        amounts[1] = amount; // USDC index is 1
        uint256 amountOutOrigin = quoter.calculateAddLiquidity(nexusPool, amounts);
        // Deposit usdc to receive nusd on origin chain
        SwapQuery memory originQuery = quoter.getAmountOut(address(nexusUsdc), address(nexusNusd), amount);
        originQuery.deadline = block.timestamp;
        // Emulate bridge fees
        uint256 amountInDest = (amountOutOrigin * 999) / 1000;
        // nusd -> usdc on dest chain
        uint256 amountOutDest = ISwap(nUsdPool).calculateSwap(0, 1, amountInDest);
        SwapQuery memory destQuery = quoter.getAmountOut(address(nusd), address(usdc), amountInDest);
        destQuery.deadline = DEADLINE;
        vm.expectEmit(true, true, true, true);
        emit TokenDepositAndSwap({
            to: TO,
            chainId: OPT_CHAINID,
            token: address(nexusNusd),
            amount: amountOutOrigin,
            tokenIndexFrom: 0,
            tokenIndexTo: 1,
            minDy: amountOutDest,
            deadline: DEADLINE
        });
        vm.prank(USER);
        zap.bridge({
            to: TO,
            chainId: OPT_CHAINID,
            token: address(nexusUsdc),
            amount: amount,
            originQuery: originQuery,
            destQuery: destQuery
        });
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
