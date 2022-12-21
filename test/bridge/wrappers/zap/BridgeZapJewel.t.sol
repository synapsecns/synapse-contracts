// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "../../../utils/Utilities06.sol";

import "../../../../contracts/bridge/wrappers/JewelBridgeSwap.sol";
import "../../../../contracts/bridge/wrappers/zap/SwapQuoter.sol";
import "../../../../contracts/bridge/wrappers/zap/BridgeZap.sol";

// solhint-disable func-name-mixedcase
contract BridgeZapJewelTest is Utilities06 {
    address internal constant USER = address(4242);
    address internal constant TO = address(2424);
    uint256 internal constant DEADLINE = 4815162342;

    uint256 internal constant DFK_CHAINID = 53935;
    uint256 internal constant HAR_CHAINID = 1666600000;

    SynapseBridge internal bridge;
    SwapQuoter internal quoter;
    BridgeZap internal zap;

    IWETH9 internal dfkJewel;
    ERC20 internal jewel;
    SynapseERC20 internal harSynJewel;
    SynapseERC20 internal avaSynJewel;

    JewelBridgeSwap internal jewelSwap;

    function setUp() public override {
        super.setUp();

        dfkJewel = deployWETH();
        jewel = deployERC20("JEWEL", 18);
        harSynJewel = deploySynapseERC20("harSynJEWEL");
        avaSynJewel = deploySynapseERC20("avaSynJewel");

        jewelSwap = new JewelBridgeSwap(jewel, IERC20(address(harSynJewel)));
        // JewelSwap should have a minter role
        harSynJewel.grantRole(harSynJewel.MINTER_ROLE(), address(jewelSwap));

        bridge = deployBridge();
        zap = new BridgeZap(address(dfkJewel), address(bridge));
        quoter = new SwapQuoter(address(zap));

        quoter.addPool(address(jewelSwap));

        zap.initialize();
        zap.setSwapQuoter(quoter);

        _dealAndApprove(address(jewel));
        _dealAndApprove(address(avaSynJewel));
        _dealAndApprove(address(dfkJewel));
        deal(USER, 10**20);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                         TESTS: BRIDGE & SWAP                         ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function test_bs_jewel_fromAvaxToHarmony() public {
        uint256 amount = 10**18;
        zap.addBurnTokens(_castToArray(address(avaSynJewel)));
        SwapQuery memory emptyQuery;
        // Emulate bridge fees
        uint256 amountInDest = (amount * 999) / 1000;
        SwapQuery memory destQuery = quoter.getAmountOut(address(harSynJewel), address(jewel), amountInDest);
        destQuery.deadline = DEADLINE;
        vm.expectEmit(true, true, true, true);
        emit TokenRedeemAndSwap({
            to: TO,
            chainId: HAR_CHAINID,
            token: address(avaSynJewel),
            amount: amount,
            tokenIndexFrom: 1, // this is the only swap ool with reversed tokens
            tokenIndexTo: 0,
            minDy: amountInDest,
            deadline: DEADLINE
        });
        vm.prank(USER);
        zap.bridge({
            to: TO,
            chainId: HAR_CHAINID,
            token: address(avaSynJewel),
            amount: amount,
            originQuery: emptyQuery,
            destQuery: destQuery
        });
    }

    function test_bs_jewel_fromDFKToHarmony() public {
        // depositETHAndSwap()
        uint256 amount = 10**18;
        zap.addDepositTokens(_castToArray(address(dfkJewel)));
        SwapQuery memory emptyQuery;
        // Emulate bridge fees
        uint256 amountInDest = (amount * 999) / 1000;
        SwapQuery memory destQuery = quoter.getAmountOut(address(harSynJewel), address(jewel), amountInDest);
        destQuery.deadline = DEADLINE;
        vm.expectEmit(true, true, true, true);
        emit TokenDepositAndSwap({
            to: TO,
            chainId: HAR_CHAINID,
            token: address(dfkJewel),
            amount: amount,
            tokenIndexFrom: 1, // this is the only swap ool with reversed tokens
            tokenIndexTo: 0,
            minDy: amountInDest,
            deadline: DEADLINE
        });
        vm.prank(USER);
        zap.bridge{value: amount}({
            to: TO,
            chainId: HAR_CHAINID,
            token: address(dfkJewel),
            amount: amount,
            originQuery: emptyQuery,
            destQuery: destQuery
        });
    }

    function test_bs_jewel_fromDFKToHarmony_wrapped() public {
        // depositAndSwap() for DFK's WJEWEL
        uint256 amount = 10**18;
        zap.addDepositTokens(_castToArray(address(dfkJewel)));
        SwapQuery memory emptyQuery;
        // Emulate bridge fees
        uint256 amountInDest = (amount * 999) / 1000;
        SwapQuery memory destQuery = quoter.getAmountOut(address(harSynJewel), address(jewel), amountInDest);
        destQuery.deadline = DEADLINE;
        vm.expectEmit(true, true, true, true);
        emit TokenDepositAndSwap({
            to: TO,
            chainId: HAR_CHAINID,
            token: address(dfkJewel),
            amount: amount,
            tokenIndexFrom: 1, // this is the only swap ool with reversed tokens
            tokenIndexTo: 0,
            minDy: amountInDest,
            deadline: DEADLINE
        });
        vm.prank(USER);
        zap.bridge({
            to: TO,
            chainId: HAR_CHAINID,
            token: address(dfkJewel),
            amount: amount,
            originQuery: emptyQuery,
            destQuery: destQuery
        });
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                         TESTS: SWAP & BRIDGE                         ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function test_sb_jewel_fromHarmony() public {
        uint256 amount = 10**18;
        zap.addBurnTokens(_castToArray(address(harSynJewel)));
        SwapQuery memory emptyQuery;
        SwapQuery memory originQuery = quoter.getAmountOut(address(jewel), address(harSynJewel), amount);
        vm.expectEmit(true, true, true, true);
        emit TokenRedeem(TO, DFK_CHAINID, address(harSynJewel), amount);
        vm.prank(USER);
        zap.bridge({
            to: TO,
            chainId: DFK_CHAINID,
            token: address(jewel),
            amount: amount,
            originQuery: originQuery,
            destQuery: emptyQuery
        });
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                           INTERNAL HELPERS                           ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function _dealAndApprove(address token) internal {
        if (token == address(dfkJewel)) {
            deal(USER, 10**20);
            vm.prank(USER);
            dfkJewel.deposit{value: 10**20}();
        } else {
            // update total supply
            deal(token, USER, 10**20, true);
        }
        vm.prank(USER);
        IERC20(token).approve(address(zap), type(uint256).max);
    }

    function _castToArray(address token) internal pure returns (address[] memory tokens) {
        tokens = new address[](1);
        tokens[0] = token;
    }
}
