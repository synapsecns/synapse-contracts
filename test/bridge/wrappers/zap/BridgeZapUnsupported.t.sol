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

    IWETH9 internal weth;
    SynapseERC20 internal neth;

    function setUp() public override {
        super.setUp();

        weth = deployWETH();
        neth = deploySynapseERC20("neth");

        bridge = deployBridge();
        zap = new BridgeZap(payable(weth), address(bridge));
        quoter = new SwapQuoter(address(zap));

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
}
