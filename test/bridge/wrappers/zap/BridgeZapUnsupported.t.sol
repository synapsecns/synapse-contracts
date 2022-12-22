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

    SynapseBridge internal bridge;
    SwapQuoter internal quoter;
    BridgeZap internal zap;

    address internal nEthPool;
    IERC20[] internal nEthTokens;

    IWETH9 internal weth;
    SynapseERC20 internal neth;

    function setUp() public override {
        super.setUp();

        weth = deployWETH();
        neth = deploySynapseERC20("neth");

        {
            uint256[] memory amounts = new uint256[](2);
            amounts[0] = 1000;
            amounts[1] = 1050;
            nEthTokens.push(IERC20(address(neth)));
            nEthTokens.push(IERC20(address(weth)));
            nEthPool = deployPoolWithLiquidity(nEthTokens, amounts);
        }

        bridge = deployBridge();
        zap = new BridgeZap(payable(weth), address(bridge));
        quoter = new SwapQuoter(address(zap));

        zap.initialize();

        quoter.addPool(nEthPool);
        zap.setSwapQuoter(quoter);

        _dealAndApprove(address(weth));
        _dealAndApprove(address(neth));
        deal(USER, 10**20);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                      TESTS: UNSUPPORTED TOKENS                       ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function test_b_revert_unsupportedToken() public {
        uint256 amount = 10**18;
        SwapQuery memory emptyQuery;
        vm.expectRevert("Token not supported");
        vm.prank(USER);
        zap.bridge({
            to: TO,
            chainId: ETH_CHAINID,
            token: address(neth),
            amount: amount,
            originQuery: emptyQuery,
            destQuery: emptyQuery
        });
    }

    function test_b_revert_unsupportedWETH() public {
        uint256 amount = 10**18;
        SwapQuery memory emptyQuery;
        vm.expectRevert("Token not supported");
        vm.prank(USER);
        zap.bridge({
            to: TO,
            chainId: ETH_CHAINID,
            token: address(weth),
            amount: amount,
            originQuery: emptyQuery,
            destQuery: emptyQuery
        });
    }

    function test_b_revert_unsupportedETH() public {
        // Make sure user has no WETH
        _unwrapUserWETH();
        uint256 amount = 10**18;
        SwapQuery memory emptyQuery;
        vm.expectRevert("Token not supported");
        vm.prank(USER);
        zap.bridge{value: amount}({
            to: TO,
            chainId: ETH_CHAINID,
            token: address(weth),
            amount: amount,
            originQuery: emptyQuery,
            destQuery: emptyQuery
        });
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║             TESTS: SWAP INTO UNSUPPORTED TOKEN ON ORIGIN             ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function test_sb_revert_fromTokenToUnsupported() public {
        uint256 amount = 10**18;
        SwapQuery memory emptyQuery;
        SwapQuery memory originQuery = quoter.getAmountOut(address(weth), address(neth), amount);
        vm.expectRevert("Token not supported");
        vm.prank(USER);
        zap.bridge({
            to: TO,
            chainId: ETH_CHAINID,
            token: address(weth),
            amount: amount,
            originQuery: originQuery,
            destQuery: emptyQuery
        });
    }

    function test_sb_revert_fromETHToUnsupported() public {
        // Make sure user has no WETH
        _unwrapUserWETH();
        uint256 amount = 10**18;
        SwapQuery memory emptyQuery;
        SwapQuery memory originQuery = quoter.getAmountOut(address(weth), address(neth), amount);
        vm.expectRevert("Token not supported");
        vm.prank(USER);
        zap.bridge{value: amount}({
            to: TO,
            chainId: ETH_CHAINID,
            token: address(weth),
            amount: amount,
            originQuery: originQuery,
            destQuery: emptyQuery
        });
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                TESTS: UNSUPPORTED SWAP ON DEST CHAIN                 ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function test_bs_revert_depositAndRemove() public {
        // depositAndRemove() does not exist
        uint256 amount = 10**18;
        SwapQuery memory emptyQuery;
        zap.addDepositTokens(_castToArray(address(weth)));
        SwapQuery memory destQuery = SwapQuery({
            swapAdapter: address(1),
            tokenOut: address(0),
            minAmountOut: 0,
            deadline: type(uint256).max,
            rawParams: abi.encode(
                SynapseParams({action: Action.RemoveLiquidity, pool: address(0), tokenIndexFrom: 0, tokenIndexTo: 0})
            )
        });
        vm.expectRevert("Unsupported dest action");
        vm.prank(USER);
        zap.bridge({
            to: TO,
            chainId: ETH_CHAINID,
            token: address(weth),
            amount: amount,
            originQuery: emptyQuery,
            destQuery: destQuery
        });
    }

    function test_bs_revert_depositETHAndRemove() public {
        // Make sure user has no WETH
        _unwrapUserWETH();
        // depositETHAndRemove() does not exist
        uint256 amount = 10**18;
        SwapQuery memory emptyQuery;
        zap.addDepositTokens(_castToArray(address(weth)));
        SwapQuery memory destQuery = SwapQuery({
            swapAdapter: address(1),
            tokenOut: address(0),
            minAmountOut: 0,
            deadline: type(uint256).max,
            rawParams: abi.encode(
                SynapseParams({action: Action.RemoveLiquidity, pool: address(0), tokenIndexFrom: 0, tokenIndexTo: 0})
            )
        });
        vm.expectRevert("Unsupported dest action");
        vm.prank(USER);
        zap.bridge{value: amount}({
            to: TO,
            chainId: ETH_CHAINID,
            token: address(weth),
            amount: amount,
            originQuery: emptyQuery,
            destQuery: destQuery
        });
    }

    function test_bs_revert_depositAndAdd() public {
        // depositAndAdd() does not exist
        uint256 amount = 10**18;
        SwapQuery memory emptyQuery;
        zap.addDepositTokens(_castToArray(address(weth)));
        SwapQuery memory destQuery = SwapQuery({
            swapAdapter: address(1),
            tokenOut: address(0),
            minAmountOut: 0,
            deadline: type(uint256).max,
            rawParams: abi.encode(
                SynapseParams({action: Action.AddLiquidity, pool: address(0), tokenIndexFrom: 0, tokenIndexTo: 0})
            )
        });
        vm.expectRevert("Unsupported dest action");
        vm.prank(USER);
        zap.bridge({
            to: TO,
            chainId: ETH_CHAINID,
            token: address(weth),
            amount: amount,
            originQuery: emptyQuery,
            destQuery: destQuery
        });
    }

    function test_bs_revert_depositETHAndAdd() public {
        // Make sure user has no WETH
        _unwrapUserWETH();
        // depositETHAndAdd() does not exist
        uint256 amount = 10**18;
        SwapQuery memory emptyQuery;
        zap.addDepositTokens(_castToArray(address(weth)));
        SwapQuery memory destQuery = SwapQuery({
            swapAdapter: address(1),
            tokenOut: address(0),
            minAmountOut: 0,
            deadline: type(uint256).max,
            rawParams: abi.encode(
                SynapseParams({action: Action.AddLiquidity, pool: address(0), tokenIndexFrom: 0, tokenIndexTo: 0})
            )
        });
        vm.expectRevert("Unsupported dest action");
        vm.prank(USER);
        zap.bridge{value: amount}({
            to: TO,
            chainId: ETH_CHAINID,
            token: address(weth),
            amount: amount,
            originQuery: emptyQuery,
            destQuery: destQuery
        });
    }

    function test_bs_revert_redeemAndAdd() public {
        // redeemAndAdd() does not exist
        uint256 amount = 10**18;
        SwapQuery memory emptyQuery;
        zap.addBurnTokens(_castToArray(address(neth)));
        SwapQuery memory destQuery = SwapQuery({
            swapAdapter: address(1),
            tokenOut: address(0),
            minAmountOut: 0,
            deadline: type(uint256).max,
            rawParams: abi.encode(
                SynapseParams({action: Action.AddLiquidity, pool: address(0), tokenIndexFrom: 0, tokenIndexTo: 0})
            )
        });
        vm.expectRevert("Unsupported dest action");
        vm.prank(USER);
        zap.bridge({
            to: TO,
            chainId: ETH_CHAINID,
            token: address(neth),
            amount: amount,
            originQuery: emptyQuery,
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
