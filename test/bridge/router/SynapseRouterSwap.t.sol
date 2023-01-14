// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "../../utils/Utilities06.sol";

import "../../../contracts/bridge/router/SwapQuoter.sol";
import "../../../contracts/bridge/router/SynapseRouter.sol";

contract BtcMaxi {
    receive() external payable {
        revert("I don't hold ETH");
    }
}

// solhint-disable func-name-mixedcase
// solhint-disable not-rely-on-time
contract SynapseRouterSwapTest is Utilities06 {
    address internal constant USER = address(4242);
    address internal constant TO = address(2424);

    uint256 internal constant AMOUNT = 10**18;

    SwapQuoter internal quoter;
    SynapseRouter internal router;

    SwapQuoter internal quoterExt;
    SynapseRouter internal routerExt;

    address internal nEthPool;
    IERC20[] internal nEthTokens;
    SynapseERC20 internal neth;
    IWETH9 internal weth;

    function setUp() public override {
        super.setUp();

        weth = deployWETH();
        neth = deploySynapseERC20("neth", 18);

        {
            uint256[] memory amounts = new uint256[](2);
            amounts[0] = 1000;
            amounts[1] = 1050;
            nEthTokens.push(IERC20(address(neth)));
            nEthTokens.push(IERC20(address(weth)));
            nEthPool = deployPoolWithLiquidity(nEthTokens, amounts);
        }

        // Bridge address is not required for swap testing
        router = new SynapseRouter(address(0));
        quoter = new SwapQuoter(address(router), address(weth));
        quoter.addPool(nEthPool);
        router.setSwapQuoter(quoter);

        // Deploy "external" router/quoter
        routerExt = new SynapseRouter(address(0));
        quoterExt = new SwapQuoter(address(routerExt), address(weth));
        quoterExt.addPool(nEthPool);
        routerExt.setSwapQuoter(quoterExt);

        _dealAndApprove(address(weth));
        _dealAndApprove(address(neth));
        // Don't deal ETH: unwrap WETH for ETH tests to make sure WETH is not being used
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                TESTS: INCORRECT SWAP PARAMS (REVERTS)                ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function test_swap_revert_recipientZero() public {
        address tokenIn = address(weth);
        address tokenOut = address(neth);
        uint256 amount = 10**18;
        SwapQuery memory query = router.getAmountOut(tokenIn, tokenOut, amount);
        vm.expectRevert("!recipient: zero address");
        router.swap(address(0), tokenIn, amount, query);
    }

    function test_swap_revert_recipientRouter() public {
        address tokenIn = address(weth);
        address tokenOut = address(neth);
        uint256 amount = 10**18;
        SwapQuery memory query = router.getAmountOut(tokenIn, tokenOut, amount);
        vm.expectRevert("!recipient: router address");
        router.swap({to: address(router), token: tokenIn, amount: amount, query: query});
    }

    function test_swap_revert_noSwapRequested() public {
        address tokenIn = address(weth);
        address tokenOut = address(weth);
        uint256 amount = 10**18;
        SwapQuery memory query = router.getAmountOut(tokenIn, tokenOut, amount);
        vm.expectRevert("!swapAdapter");
        router.swap(TO, tokenIn, amount, query);
    }

    function test_swap_revert_wrongEthAddress() public {
        // tokenIn should be ETH_ADDRESS instead
        address tokenIn = address(weth);
        address tokenOut = address(neth);
        uint256 amount = 10**18;
        SwapQuery memory query = router.getAmountOut(tokenIn, tokenOut, amount);
        _unwrapUserWETH();
        vm.expectRevert(bytes("!eth"));
        vm.prank(USER);
        router.swap{value: amount}(TO, tokenIn, amount, query);
    }

    function test_swap_revert_incorrectMsgValue() public {
        address tokenIn = UniversalToken.ETH_ADDRESS;
        address tokenOut = address(neth);
        uint256 amount = 10**18;
        SwapQuery memory query = router.getAmountOut(tokenIn, tokenOut, amount);
        _unwrapUserWETH();
        vm.expectRevert("!msg.value");
        vm.prank(USER);
        router.swap{value: amount - 1}(TO, tokenIn, amount, query);
    }

    function test_swap_revert_recipientDeniesEth() public {
        BtcMaxi ethDenier = new BtcMaxi();
        address tokenIn = address(neth);
        address tokenOut = UniversalToken.ETH_ADDRESS;
        uint256 amount = 10**18;
        SwapQuery memory query = router.getAmountOut(tokenIn, tokenOut, amount);
        vm.expectRevert("ETH transfer failed");
        vm.prank(USER);
        router.swap(address(ethDenier), tokenIn, amount, query);
        // Same swap goes through if we don't unwrap WETH
        tokenOut = address(weth);
        query = router.getAmountOut(tokenIn, tokenOut, amount);
        vm.prank(USER);
        router.swap(address(ethDenier), tokenIn, amount, query);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                 TESTS: SWAP USING ROUTER AS ADAPTER                  ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function test_swap_router_basic() public {
        // WETH -> nETH token swap
        _checkSwap({tokenIn: address(weth), tokenOut: address(neth), externalAdapter: false});
        // nETH -> WETH token swap
        _checkSwap({tokenIn: address(neth), tokenOut: address(weth), externalAdapter: false});
    }

    function test_swap_router_fromETH() public {
        // ETH -> nETH swap
        _checkSwap({tokenIn: UniversalToken.ETH_ADDRESS, tokenOut: address(neth), externalAdapter: false});
    }

    function test_swap_router_toETH() public {
        // nETH -> ETH swap
        _checkSwap({tokenIn: address(neth), tokenOut: UniversalToken.ETH_ADDRESS, externalAdapter: false});
    }

    function test_swap_router_handleETH() public {
        address eth = UniversalToken.ETH_ADDRESS;
        // Router can be used for un(wrapping) ETH
        _checkSwap({tokenIn: address(weth), tokenOut: eth, externalAdapter: false});
        _checkSwap({tokenIn: eth, tokenOut: address(weth), externalAdapter: false});
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║            TESTS: SWAP USING ROUTER AS ADAPTER (REVERTS)             ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function test_swap_router_revert_basic_deadlinePassed() public {
        address tokenIn = address(weth);
        address tokenOut = address(neth);
        bool externalAdapter = false;
        SwapQuery memory query = _getQuery(tokenIn, tokenOut, externalAdapter);
        skip(1);
        vm.expectRevert("Deadline not met");
        vm.prank(USER);
        router.swap(TO, tokenIn, AMOUNT, query);
    }

    function test_swap_router_revert_fromETH_deadlinePassed() public {
        _unwrapUserWETH();
        address tokenIn = UniversalToken.ETH_ADDRESS;
        address tokenOut = address(neth);
        bool externalAdapter = false;
        SwapQuery memory query = _getQuery(tokenIn, tokenOut, externalAdapter);
        skip(1);
        vm.expectRevert("Deadline not met");
        vm.prank(USER);
        router.swap{value: AMOUNT}(TO, tokenIn, AMOUNT, query);
    }

    function test_swap_router_revert_basic_minAmountOutFailed() public {
        address tokenIn = address(weth);
        address tokenOut = address(neth);
        bool externalAdapter = false;
        SwapQuery memory query = _getQuery(tokenIn, tokenOut, externalAdapter);
        query.minAmountOut++;
        vm.expectRevert("Swap didn't result in min tokens");
        vm.prank(USER);
        router.swap(TO, tokenIn, AMOUNT, query);
    }

    function test_swap_router_revert_fromETH_minAmountOutFailed() public {
        _unwrapUserWETH();
        address tokenIn = UniversalToken.ETH_ADDRESS;
        address tokenOut = address(neth);
        bool externalAdapter = false;
        SwapQuery memory query = _getQuery(tokenIn, tokenOut, externalAdapter);
        query.minAmountOut++;
        vm.expectRevert("Swap didn't result in min tokens");
        vm.prank(USER);
        router.swap{value: AMOUNT}(TO, tokenIn, AMOUNT, query);
    }

    function test_swap_router_revert_toETH_minAmountOutFailed() public {
        address tokenIn = address(neth);
        address tokenOut = UniversalToken.ETH_ADDRESS;
        bool externalAdapter = false;
        SwapQuery memory query = _getQuery(tokenIn, tokenOut, externalAdapter);
        query.minAmountOut++;
        vm.expectRevert("Swap didn't result in min tokens");
        vm.prank(USER);
        router.swap(TO, tokenIn, AMOUNT, query);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                  TESTS: SWAP USING EXTERNAL ADAPTER                  ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function test_swap_external_basic() public {
        // WETH -> nETH token swap through external adapter
        _checkSwap({tokenIn: address(weth), tokenOut: address(neth), externalAdapter: true});
        // nETH -> WETH token swap
        _checkSwap({tokenIn: address(neth), tokenOut: address(weth), externalAdapter: true});
    }

    function test_swap_external_fromETH() public {
        // ETH -> nETH swap
        _checkSwap({tokenIn: UniversalToken.ETH_ADDRESS, tokenOut: address(neth), externalAdapter: true});
    }

    function test_swap_external_toETH() public {
        // nETH -> ETH swap
        _checkSwap({tokenIn: address(neth), tokenOut: UniversalToken.ETH_ADDRESS, externalAdapter: true});
    }

    function test_swap_external_handleETH() public {
        address eth = UniversalToken.ETH_ADDRESS;
        // External SynapseAdapter can be used for un(wrapping) ETH
        _checkSwap({tokenIn: address(weth), tokenOut: eth, externalAdapter: true});
        _checkSwap({tokenIn: eth, tokenOut: address(weth), externalAdapter: true});
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║             TESTS: SWAP USING EXTERNAL ADAPTER (REVERTS)             ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function test_swap_external_revert_basic_deadlinePassed() public {
        address tokenIn = address(weth);
        address tokenOut = address(neth);
        bool externalAdapter = true;
        SwapQuery memory query = _getQuery(tokenIn, tokenOut, externalAdapter);
        skip(1);
        vm.expectRevert("Deadline not met");
        vm.prank(USER);
        router.swap(TO, tokenIn, AMOUNT, query);
    }

    function test_swap_external_revert_fromETH_deadlinePassed() public {
        _unwrapUserWETH();
        address tokenIn = UniversalToken.ETH_ADDRESS;
        address tokenOut = address(neth);
        bool externalAdapter = true;
        SwapQuery memory query = _getQuery(tokenIn, tokenOut, externalAdapter);
        skip(1);
        vm.expectRevert("Deadline not met");
        vm.prank(USER);
        router.swap{value: AMOUNT}(TO, tokenIn, AMOUNT, query);
    }

    function test_swap_external_revert_basic_minAmountOutFailed() public {
        address tokenIn = address(weth);
        address tokenOut = address(neth);
        bool externalAdapter = true;
        SwapQuery memory query = _getQuery(tokenIn, tokenOut, externalAdapter);
        query.minAmountOut++;
        vm.expectRevert("Swap didn't result in min tokens");
        vm.prank(USER);
        router.swap(TO, tokenIn, AMOUNT, query);
    }

    function test_swap_external_revert_fromETH_minAmountOutFailed() public {
        _unwrapUserWETH();
        address tokenIn = UniversalToken.ETH_ADDRESS;
        address tokenOut = address(neth);
        bool externalAdapter = true;
        SwapQuery memory query = _getQuery(tokenIn, tokenOut, externalAdapter);
        query.minAmountOut++;
        vm.expectRevert("Swap didn't result in min tokens");
        vm.prank(USER);
        router.swap{value: AMOUNT}(TO, tokenIn, AMOUNT, query);
    }

    function test_swap_external_revert_toETH_minAmountOutFailed() public {
        address tokenIn = address(neth);
        address tokenOut = UniversalToken.ETH_ADDRESS;
        bool externalAdapter = true;
        SwapQuery memory query = _getQuery(tokenIn, tokenOut, externalAdapter);
        query.minAmountOut++;
        vm.expectRevert("Swap didn't result in min tokens");
        vm.prank(USER);
        router.swap(TO, tokenIn, AMOUNT, query);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                           INTERNAL HELPERS                           ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function _checkSwap(
        address tokenIn,
        address tokenOut,
        bool externalAdapter
    ) internal {
        bool nativeEthIn = tokenIn == UniversalToken.ETH_ADDRESS;
        if (nativeEthIn) _unwrapUserWETH();
        // Figure out if user should receive native ETH as a result
        bool nativeEthOut = tokenOut == UniversalToken.ETH_ADDRESS;
        SwapQuery memory query = _getQuery(tokenIn, tokenOut, externalAdapter);
        require(query.minAmountOut != 0, "Swap not found");
        // Record balance before the swap
        uint256 balanceBefore = nativeEthOut ? TO.balance : IERC20(tokenOut).balanceOf(TO);
        vm.prank(USER);
        uint256 amountOut = router.swap{value: nativeEthIn ? AMOUNT : 0}({
            to: TO,
            token: tokenIn,
            amount: AMOUNT,
            query: query
        });
        uint256 balanceAfter = nativeEthOut ? TO.balance : IERC20(tokenOut).balanceOf(TO);
        assertEq(amountOut, balanceAfter - balanceBefore, "Failed to report amountOut");
    }

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
        IERC20(token).approve(address(router), type(uint256).max);
    }

    function _unwrapUserWETH() internal {
        uint256 balance = weth.balanceOf(USER);
        vm.prank(USER);
        weth.withdraw(balance);
    }

    function _getQuery(
        address tokenIn,
        address tokenOut,
        bool externalAdapter
    ) internal view returns (SwapQuery memory query) {
        query = (externalAdapter ? routerExt : router).getAmountOut(tokenIn, tokenOut, AMOUNT);
        query.deadline = block.timestamp;
    }
}
