// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// prettier-ignore
import {
    Action,
    BridgeToken,
    DefaultParams,
    SwapQuery,
    SynapseBridgeModule
} from "../../../../contracts/router/modules/bridge/SynapseBridgeModule.sol";

import {MockERC20} from "../../mocks/MockERC20.sol";

import {DelegateCaller} from "./DelegateCaller.sol";
import {SynapseBridgeUtils} from "./SynapseBridgeUtils.sol";

contract SynapseBridgeModuleTest is SynapseBridgeUtils {
    // Fake different values for bridging
    address public constant TO = address(10);
    uint256 public constant CHAIN_ID = 20;
    uint256 public constant AMOUNT = 1 ether;
    // Fake values for SwapQuery
    address public constant TOKEN_OUT = address(30);
    uint256 public constant MIN_AMOUNT_OUT = 40;
    uint256 public constant DEADLINE = 50;
    // Fake values for DefaultParams
    address public constant POOL = address(60);
    uint8 public constant TOKEN_INDEX_FROM = 70;
    uint8 public constant TOKEN_INDEX_TO = 80;

    SynapseBridgeModule public module;
    DelegateCaller public delegateCaller;

    address public depositToken;
    address public redeemToken;
    address public unknownToken;

    function setUp() public virtual override {
        super.setUp();
        delegateCaller = new DelegateCaller();
        module = new SynapseBridgeModule({
            localBridgeConfig_: address(localBridgeConfig),
            synapseBridge_: synapseBridge
        });
        depositToken = address(new MockERC20("DT", 18));
        redeemToken = address(new MockERC20("RT", 18));
        unknownToken = address(new MockERC20("UT", 18));
        vm.label(depositToken, "DT");
        vm.label(redeemToken, "RT");
    }

    function testConstructor() public {
        assertEq(address(module.localBridgeConfig()), address(localBridgeConfig));
        assertEq(address(module.synapseBridge()), synapseBridge);
    }

    function addTokens() public virtual {
        addDepositToken("DT", depositToken);
        addRedeemToken("RT", redeemToken, DEFAULT_BRIDGE_FEE / 10, DEFAULT_MIN_FEE, DEFAULT_MAX_FEE);
    }

    // ══════════════════════════════════════════════ TESTS: BRIDGING ══════════════════════════════════════════════════

    function testDelegateBridgeRevertsWhenDirectCall() public {
        SwapQuery memory emptyQuery;
        vm.expectRevert("Not a delegate call");
        module.delegateBridge(address(0), 0, address(0), 0, emptyQuery);
    }

    // Wrapper test should override this function
    function getBridgeToken(address token) public virtual returns (address) {
        return token;
    }

    function verifyDepositTokenBalance() public virtual {
        assertEq(MockERC20(depositToken).balanceOf(address(delegateCaller)), 0);
        assertEq(MockERC20(depositToken).balanceOf(address(synapseBridge)), AMOUNT);
    }

    function verifyRedeemTokenBalance() public virtual {
        assertEq(MockERC20(redeemToken).balanceOf(address(delegateCaller)), 0);
        assertEq(MockERC20(redeemToken).balanceOf(address(synapseBridge)), 0);
    }

    // Flow for all delegateBridge tests:
    // - Tokens are minted to `delegateCaller` contract, which is mock for SynapseRouterV2
    // - `delegateCaller` issues a delegate call to `module.delegateBridge()` which should initiate the bridging
    // module.delegateBridge(address to, uint256 chainId, address token, uint256 AMOUNT, SwapQuery memory destQuery)

    function testDelegateBridgeRedeem() public {
        addTokens();
        MockERC20(redeemToken).mint(address(delegateCaller), AMOUNT);
        SwapQuery memory emptyQuery;
        bytes memory payload = abi.encodeWithSelector(
            module.delegateBridge.selector,
            TO,
            CHAIN_ID,
            redeemToken,
            AMOUNT,
            emptyQuery
        );
        vm.expectEmit(synapseBridge);
        emit TokenRedeem(TO, CHAIN_ID, getBridgeToken(redeemToken), AMOUNT);
        delegateCaller.performDelegateCall(address(module), payload);
        verifyRedeemTokenBalance();
    }

    function testDelegateBridgeRedeemAndSwap() public {
        addTokens();
        MockERC20(redeemToken).mint(address(delegateCaller), AMOUNT);
        SwapQuery memory destQuery = SwapQuery({
            routerAdapter: address(delegateCaller),
            tokenOut: TOKEN_OUT,
            minAmountOut: MIN_AMOUNT_OUT,
            deadline: DEADLINE,
            rawParams: abi.encode(
                DefaultParams({
                    action: Action.Swap,
                    pool: POOL,
                    tokenIndexFrom: TOKEN_INDEX_FROM,
                    tokenIndexTo: TOKEN_INDEX_TO
                })
            )
        });
        bytes memory payload = abi.encodeWithSelector(
            module.delegateBridge.selector,
            TO,
            CHAIN_ID,
            redeemToken,
            AMOUNT,
            destQuery
        );
        vm.expectEmit(synapseBridge);
        emit TokenRedeemAndSwap({
            to: TO,
            chainId: CHAIN_ID,
            token: getBridgeToken(redeemToken),
            amount: AMOUNT,
            tokenIndexFrom: TOKEN_INDEX_FROM,
            tokenIndexTo: TOKEN_INDEX_TO,
            minDy: MIN_AMOUNT_OUT,
            deadline: DEADLINE
        });
        delegateCaller.performDelegateCall(address(module), payload);
        verifyRedeemTokenBalance();
    }

    function testDelegateBridgeRedeemAndRemove() public {
        addTokens();
        MockERC20(redeemToken).mint(address(delegateCaller), AMOUNT);
        SwapQuery memory destQuery = SwapQuery({
            routerAdapter: address(delegateCaller),
            tokenOut: TOKEN_OUT,
            minAmountOut: MIN_AMOUNT_OUT,
            deadline: DEADLINE,
            rawParams: abi.encode(
                DefaultParams({
                    action: Action.RemoveLiquidity,
                    pool: POOL,
                    tokenIndexFrom: 0xFF,
                    tokenIndexTo: TOKEN_INDEX_TO
                })
            )
        });
        bytes memory payload = abi.encodeWithSelector(
            module.delegateBridge.selector,
            TO,
            CHAIN_ID,
            redeemToken,
            AMOUNT,
            destQuery
        );
        vm.expectEmit(synapseBridge);
        emit TokenRedeemAndRemove({
            to: TO,
            chainId: CHAIN_ID,
            token: getBridgeToken(redeemToken),
            amount: AMOUNT,
            swapTokenIndex: TOKEN_INDEX_TO,
            swapMinAmount: MIN_AMOUNT_OUT,
            swapDeadline: DEADLINE
        });
        delegateCaller.performDelegateCall(address(module), payload);
        verifyRedeemTokenBalance();
    }

    function testDelegateBridgeDeposit() public {
        addTokens();
        MockERC20(depositToken).mint(address(delegateCaller), AMOUNT);
        SwapQuery memory emptyQuery;
        bytes memory payload = abi.encodeWithSelector(
            module.delegateBridge.selector,
            TO,
            CHAIN_ID,
            depositToken,
            AMOUNT,
            emptyQuery
        );
        vm.expectEmit(synapseBridge);
        emit TokenDeposit(TO, CHAIN_ID, getBridgeToken(depositToken), AMOUNT);
        delegateCaller.performDelegateCall(address(module), payload);
        verifyDepositTokenBalance();
    }

    function testDelegateBridgeDepositAndSwap() public {
        addTokens();
        MockERC20(depositToken).mint(address(delegateCaller), AMOUNT);
        SwapQuery memory destQuery = SwapQuery({
            routerAdapter: address(delegateCaller),
            tokenOut: TOKEN_OUT,
            minAmountOut: MIN_AMOUNT_OUT,
            deadline: DEADLINE,
            rawParams: abi.encode(
                DefaultParams({
                    action: Action.Swap,
                    pool: POOL,
                    tokenIndexFrom: TOKEN_INDEX_FROM,
                    tokenIndexTo: TOKEN_INDEX_TO
                })
            )
        });
        bytes memory payload = abi.encodeWithSelector(
            module.delegateBridge.selector,
            TO,
            CHAIN_ID,
            depositToken,
            AMOUNT,
            destQuery
        );
        vm.expectEmit(synapseBridge);
        emit TokenDepositAndSwap({
            to: TO,
            chainId: CHAIN_ID,
            token: getBridgeToken(depositToken),
            amount: AMOUNT,
            tokenIndexFrom: TOKEN_INDEX_FROM,
            tokenIndexTo: TOKEN_INDEX_TO,
            minDy: MIN_AMOUNT_OUT,
            deadline: DEADLINE
        });
        delegateCaller.performDelegateCall(address(module), payload);
        verifyDepositTokenBalance();
    }

    // ═══════════════════════════════════════════════ TESTS: VIEWS ════════════════════════════════════════════════════

    function testGetMaxBridgedAmountReturnsMaxForSupportedToken() public {
        addTokens();
        assertEq(module.getMaxBridgedAmount(depositToken), type(uint256).max);
        assertEq(module.getMaxBridgedAmount(redeemToken), type(uint256).max);
    }

    function testGetMaxBridgedAmountReturnsZeroForUnsupportedToken() public {
        addTokens();
        assertEq(module.getMaxBridgedAmount(unknownToken), 0);
    }

    // uint128 to prevent multiplication overflow in tests
    function testCalculateFeeAmount(uint128 amount) public {
        addTokens();
        uint256 expectedDepositTokenFee = localBridgeConfig.calculateBridgeFee(depositToken, amount);
        uint256 expectedRedeemTokenFee = localBridgeConfig.calculateBridgeFee(redeemToken, amount);
        assertEq(module.calculateFeeAmount(depositToken, amount), expectedDepositTokenFee);
        assertEq(module.calculateFeeAmount(redeemToken, amount), expectedRedeemTokenFee);
    }

    function testCalculateFeeAmountRevertsForUnsupportedToken() public {
        addTokens();
        // Revert happens in LocalBridgeConfig.sol
        vm.expectRevert("Token not supported");
        module.calculateFeeAmount(unknownToken, 0);
    }

    function testGetBridgeTokens() public {
        addTokens();
        BridgeToken[] memory bridgeTokens = module.getBridgeTokens();
        assertEq(bridgeTokens.length, 2);
        assertEq(bridgeTokens[0].symbol, "DT");
        assertEq(bridgeTokens[0].token, depositToken);
        assertEq(bridgeTokens[1].symbol, "RT");
        assertEq(bridgeTokens[1].token, redeemToken);
    }

    function testGetBridgeTokensWhenZeroTokens() public {
        BridgeToken[] memory bridgeTokens = module.getBridgeTokens();
        assertEq(bridgeTokens.length, 0);
    }

    function testSymbolToToken() public {
        addTokens();
        assertEq(module.symbolToToken("DT"), depositToken);
        assertEq(module.symbolToToken("RT"), redeemToken);
    }

    function testSymbolToTokenReturnsZeroForUnknownSymbol() public {
        assertEq(module.symbolToToken("UT"), address(0));
    }

    function testTokenToSymbol() public {
        addTokens();
        assertEq(module.tokenToSymbol(depositToken), "DT");
        assertEq(module.tokenToSymbol(redeemToken), "RT");
    }

    function testTokenToSymbolReturnsEmptyStringForUnknownToken() public {
        assertEq(module.tokenToSymbol(unknownToken), "");
    }

    function testTokenToActionMaskDepositToken() public {
        addTokens();
        uint256 expectedMask = (1 << uint256(Action.RemoveLiquidity)) | (1 << uint256(Action.HandleEth));
        assertEq(module.tokenToActionMask(depositToken), expectedMask);
    }

    function testTokenToActionMaskRedeemToken() public {
        addTokens();
        uint256 expectedMask = 1 << uint256(Action.Swap);
        assertEq(module.tokenToActionMask(redeemToken), expectedMask);
    }

    function testTokenToActionMaskReturnsZeroForUnknownToken() public {
        assertEq(module.tokenToActionMask(unknownToken), 0);
    }
}
