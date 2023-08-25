// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// prettier-ignore
import {
    Action,
    BridgeToken,
    DefaultParams,
    SwapQuery,
    SynapseCCTPModule
} from "../../../../contracts/router/modules/bridge/SynapseCCTPModule.sol";
import {SynapseCCTP} from "../../../../contracts/cctp/SynapseCCTP.sol";

import {BaseCCTPTest, MockERC20, RequestLib} from "../../../cctp/BaseCCTP.t.sol";
import {DelegateCaller} from "./DelegateCaller.sol";

contract SynapseCCTPModuleTest is BaseCCTPTest {
    // 1M USDC
    uint256 public constant MAX_BURN_AMOUNT = 10**6 * 10**6;
    string public constant SYMBOL_USDC = "CCTP.MockC";
    // Fake different values for bridging
    address public constant TO = address(10);
    uint256 public constant AMOUNT = 1 ether;
    uint256 public constant MSG_VALUE = 2 ether;
    // Fake values for SwapQuery
    address public constant TOKEN_OUT = address(20);
    uint256 public constant MIN_AMOUNT_OUT = 30;
    uint256 public constant DEADLINE = 40;
    // Fake values for DefaultParams
    address public constant POOL = address(50);
    uint8 public constant TOKEN_INDEX_FROM = 60;
    uint8 public constant TOKEN_INDEX_TO = 70;

    SynapseCCTP public synapseCCTP;
    address public token;
    address public unknownToken;

    SynapseCCTPModule public module;
    DelegateCaller public delegateCaller;

    bool public attachEther;

    function setUp() public virtual override {
        super.setUp();
        setBurnLimitPerMessage(DOMAIN_ETH);

        synapseCCTP = synapseCCTPs[DOMAIN_ETH];
        token = address(cctpSetups[DOMAIN_ETH].mintBurnToken);
        // Use "MockT" token as the unknown token
        unknownToken = address(poolSetups[DOMAIN_ETH].token);

        delegateCaller = new DelegateCaller();
        module = new SynapseCCTPModule(address(synapseCCTP));

        deal(address(this), MSG_VALUE);
        cctpSetups[DOMAIN_ETH].mintBurnToken.mintPublic(address(delegateCaller), AMOUNT);
    }

    function setBurnLimitPerMessage(uint32 domain) public {
        cctpSetups[domain].tokenMinter.setBurnLimitPerMessage(
            address(cctpSetups[domain].mintBurnToken),
            MAX_BURN_AMOUNT
        );
    }

    function testConstructor() public {
        assertEq(module.synapseCCTP(), address(synapseCCTP));
    }

    // ══════════════════════════════════════════════ TESTS: BRIDGING ══════════════════════════════════════════════════

    function testDelegateBridgeRevertsWhenDirectCall() public {
        SwapQuery memory emptyQuery;
        vm.expectRevert("Not a delegate call");
        module.delegateBridge(address(0), 0, address(0), 0, emptyQuery);
    }

    function verifyTokenBalance() public virtual {
        assertEq(MockERC20(token).balanceOf(address(delegateCaller)), 0);
        assertEq(MockERC20(token).balanceOf(address(synapseCCTP)), 0);
    }

    function performDelegateCall(bytes memory payload) public {
        if (attachEther) {
            delegateCaller.performDelegateCall{value: MSG_VALUE}(address(module), payload);
        } else {
            delegateCaller.performDelegateCall(address(module), payload);
        }
    }

    // Flow for all delegateBridge tests:
    // - Tokens were minted to `delegateCaller` contract in setUp(), which is mock for SynapseRouterV2
    // - `delegateCaller` issues a delegate call to `module.delegateBridge()` which should initiate the bridging
    // module.delegateBridge(address to, uint256 chainId, address token, uint256 AMOUNT, SwapQuery memory destQuery)

    function getModulePayload(bool isBaseRequest) public view returns (bytes memory payload) {
        SwapQuery memory destQuery;
        if (!isBaseRequest) {
            destQuery = SwapQuery({
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
        }
        payload = getModulePayload({bridgeToken: token, destQuery: destQuery});
    }

    function getModulePayload(address bridgeToken, SwapQuery memory destQuery)
        public
        view
        returns (bytes memory payload)
    {
        payload = abi.encodeWithSelector(
            module.delegateBridge.selector,
            TO,
            CHAINID_AVAX,
            bridgeToken,
            AMOUNT,
            destQuery
        );
    }

    function expectSynapseCCTPEvent(bool isBaseRequest) public {
        uint32 requestVersion = isBaseRequest ? RequestLib.REQUEST_BASE : RequestLib.REQUEST_SWAP;
        bytes memory swapParams = isBaseRequest
            ? bytes("")
            : RequestLib.formatSwapParams({
                tokenIndexFrom: TOKEN_INDEX_FROM,
                tokenIndexTo: TOKEN_INDEX_TO,
                deadline: DEADLINE,
                minAmountOut: MIN_AMOUNT_OUT
            });
        uint64 nonce = cctpSetups[DOMAIN_ETH].messageTransmitter.nextAvailableNonce();
        bytes memory expectedRequest = RequestLib.formatRequest({
            requestVersion: requestVersion,
            baseRequest: RequestLib.formatBaseRequest({
                originDomain: DOMAIN_ETH,
                nonce: nonce,
                originBurnToken: token,
                amount: AMOUNT,
                recipient: TO
            }),
            swapParams: swapParams
        });
        bytes32 expectedRequestID = getExpectedrequestID({
            originDomain: DOMAIN_ETH,
            destinationDomain: DOMAIN_AVAX,
            finalRecipient: TO,
            originBurnToken: token,
            amount: AMOUNT,
            requestVersion: requestVersion,
            swapParams: swapParams
        });
        vm.expectEmit(address(synapseCCTP));
        emit CircleRequestSent({
            chainId: CHAINID_AVAX,
            sender: msg.sender,
            nonce: nonce,
            token: token,
            amount: AMOUNT,
            requestVersion: requestVersion,
            formattedRequest: expectedRequest,
            requestID: expectedRequestID
        });
    }

    function testDelegateBridgeBaseRequest() public {
        bytes memory payload = getModulePayload({isBaseRequest: true});
        expectSynapseCCTPEvent({isBaseRequest: true});
        performDelegateCall(payload);
        verifyTokenBalance();
    }

    function testDelegateBridgeSwapRequest() public {
        bytes memory payload = getModulePayload({isBaseRequest: false});
        expectSynapseCCTPEvent({isBaseRequest: false});
        performDelegateCall(payload);
        verifyTokenBalance();
    }

    // ═══════════════════════════════════ TESTS: BRIDGING (WITH ETHER ATTACHED) ═══════════════════════════════════════

    function testDelegateBridgeBaseRequestWithEther() public {
        attachEther = true;
        testDelegateBridgeBaseRequest();
    }

    function testDelegateBridgeSwapRequestWithEther() public {
        attachEther = true;
        testDelegateBridgeSwapRequest();
    }

    // ═══════════════════════════════════ TESTS: BRIDGING WITH INVALID REQUESTS ═══════════════════════════════════════

    function testDelegateBridgeRevertsWhenTokenNotSupported() public {
        MockERC20(unknownToken).mint(address(delegateCaller), AMOUNT);
        SwapQuery memory emptyQuery;
        bytes memory payload = getModulePayload({bridgeToken: unknownToken, destQuery: emptyQuery});
        vm.expectRevert(
            abi.encodeWithSelector(SynapseCCTPModule.SynapseCCTPModule__UnsupportedToken.selector, unknownToken)
        );
        performDelegateCall(payload);
    }

    function testDelegateBridgeRevertsWhenAddLiquidity() public {
        SwapQuery memory destQuery = SwapQuery({
            routerAdapter: address(delegateCaller),
            tokenOut: TOKEN_OUT,
            minAmountOut: MIN_AMOUNT_OUT,
            deadline: DEADLINE,
            rawParams: abi.encode(
                DefaultParams({
                    action: Action.AddLiquidity,
                    pool: POOL,
                    tokenIndexFrom: TOKEN_INDEX_FROM,
                    tokenIndexTo: 0xFF
                })
            )
        });
        bytes memory payload = getModulePayload({bridgeToken: token, destQuery: destQuery});
        vm.expectRevert(
            abi.encodeWithSelector(SynapseCCTPModule.SynapseCCTPModule__UnsupportedAction.selector, Action.AddLiquidity)
        );
        performDelegateCall(payload);
    }

    function testDelegateBridgeRevertsWhenRemoveLiquidity() public {
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
        bytes memory payload = getModulePayload({bridgeToken: token, destQuery: destQuery});
        vm.expectRevert(
            abi.encodeWithSelector(
                SynapseCCTPModule.SynapseCCTPModule__UnsupportedAction.selector,
                Action.RemoveLiquidity
            )
        );
        performDelegateCall(payload);
    }

    function testDelegateBridgeRevertsWhenHandleEth() public {
        SwapQuery memory destQuery = SwapQuery({
            routerAdapter: address(delegateCaller),
            tokenOut: TOKEN_OUT,
            minAmountOut: MIN_AMOUNT_OUT,
            deadline: DEADLINE,
            rawParams: abi.encode(
                DefaultParams({action: Action.HandleEth, pool: address(0), tokenIndexFrom: 0xFF, tokenIndexTo: 0xFF})
            )
        });
        bytes memory payload = getModulePayload({bridgeToken: token, destQuery: destQuery});
        vm.expectRevert(
            abi.encodeWithSelector(SynapseCCTPModule.SynapseCCTPModule__UnsupportedAction.selector, Action.HandleEth)
        );
        performDelegateCall(payload);
    }

    function testDelegateBridgeRevertsWhenSwapWithEqualIndexes() public {
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
                    tokenIndexTo: TOKEN_INDEX_FROM
                })
            )
        });
        bytes memory payload = getModulePayload({bridgeToken: token, destQuery: destQuery});
        vm.expectRevert(
            abi.encodeWithSelector(SynapseCCTPModule.SynapseCCTPModule__EqualSwapIndexes.selector, TOKEN_INDEX_FROM)
        );
        performDelegateCall(payload);
    }

    // ═══════════════════════════════════════════════ TESTS: VIEWS ════════════════════════════════════════════════════

    function testGetMaxBridgedAmountReturnsMaxBurnAmountForSupportedToken() public {
        assertEq(module.getMaxBridgedAmount(token), MAX_BURN_AMOUNT);
    }

    function testGetMaxBridgedAmountReturnsZeroWhenSendingPaused() public {
        address cctpOwner = synapseCCTP.owner();
        vm.prank(cctpOwner);
        synapseCCTP.pauseSending();
        assertEq(module.getMaxBridgedAmount(token), 0);
    }

    function testGetMaxBridgedAmountReturnsZeroForUnsupportedToken() public {
        assertEq(module.getMaxBridgedAmount(unknownToken), 0);
    }

    // uint128 to prevent multiplication overflow in tests
    function testCalculateFeeAmountWhenSwap(uint128 amount) public {
        uint256 expectedFee = synapseCCTP.calculateFeeAmount(token, amount, true);
        assertEq(module.calculateFeeAmount(token, amount, true), expectedFee);
    }

    // uint128 to prevent multiplication overflow in tests
    function testCalculateFeeAmountWhenNoSwap(uint128 amount) public {
        uint256 expectedFee = synapseCCTP.calculateFeeAmount(token, amount, false);
        assertEq(module.calculateFeeAmount(token, amount, false), expectedFee);
    }

    function testCalculateFeeAmountRevertsForUnsupportedToken() public {
        bytes memory expectedError = abi.encodeWithSelector(
            SynapseCCTPModule.SynapseCCTPModule__UnsupportedToken.selector,
            unknownToken
        );
        vm.expectRevert(expectedError);
        module.calculateFeeAmount(unknownToken, 0, false);
        vm.expectRevert(expectedError);
        module.calculateFeeAmount(unknownToken, 0, true);
    }

    function testGetBridgeTokens() public {
        BridgeToken[] memory bridgeTokens = module.getBridgeTokens();
        assertEq(bridgeTokens.length, 1);
        assertEq(bridgeTokens[0].symbol, SYMBOL_USDC);
        assertEq(bridgeTokens[0].token, token);
    }

    function testGetBridgeTokensWhenZeroTokens() public {
        address cctpOwner = synapseCCTP.owner();
        vm.prank(cctpOwner);
        synapseCCTP.removeToken(token);
        BridgeToken[] memory bridgeTokens = module.getBridgeTokens();
        assertEq(bridgeTokens.length, 0);
    }

    function testSymbolToToken() public {
        assertEq(module.symbolToToken(SYMBOL_USDC), token);
    }

    function testSymbolToTokenReturnsZeroForUnknownSymbol() public {
        assertEq(module.symbolToToken("MockT"), address(0));
    }

    function testTokenToSymbol() public {
        assertEq(module.tokenToSymbol(token), SYMBOL_USDC);
    }

    function testTokenToSymbolReturnsEmptyStringForUnknownToken() public {
        assertEq(module.tokenToSymbol(unknownToken), "");
    }

    function testTokenToActionMask() public {
        uint256 expectedMask = 1 << uint256(Action.Swap);
        assertEq(module.tokenToActionMask(token), expectedMask);
    }

    function testTokenToActionMaskReturnsZeroForUnknownToken() public {
        assertEq(module.tokenToActionMask(unknownToken), 0);
    }
}
