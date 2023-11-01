// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Action, DefaultParams, SwapQuery} from "../../../../contracts/router/libs/Structs.sol";
import {DelegateCaller} from "./DelegateCaller.sol";
import {IntegrationUtils} from "../../../utils/IntegrationUtils.sol";
import {SynapseBridgeModule, SynapseRouterV2BridgeUtils} from "../../v2/integration/SynapseRouterV2.BridgeUtils.sol";

contract SynapseBridgeModuleAvalancheIntegrationTestFork is SynapseRouterV2BridgeUtils, IntegrationUtils {
    // 2023-11-01
    uint256 public constant AVAX_BLOCK_NUMBER = 37199000;

    address private constant AVAX_SYN_ROUTER_V1 = 0x7E7A0e201FD38d3ADAA9523Da6C109a07118C96a;
    address private constant AVAX_SYN_BRIDGE = 0xC05e61d0E7a63D27546389B7aD62FdFf5A91aACE;

    // Deposit token
    address private constant BTC_B = 0x152b9d0FdC40C096757F570A51E494bd4b943E50;

    // Redeem token
    address private constant NUSD = 0xCFc37A6AB183dd4aED08C204D1c2773c0b1BDf46;

    // Redeem token with a wrapper
    address private constant GMX = 0x62edc0692BD897D2295872a9FFCac5425011c661;
    address private constant GMX_WRAPPER = 0x20A9DC684B4d0407EF8C9A302BEAaA18ee15F656;

    DelegateCaller public routerMock;

    constructor() IntegrationUtils("avalanche", "SynapseBridgeModule", AVAX_BLOCK_NUMBER) {}

    function afterBlockchainForked() public override {
        synapseLocalBridgeConfig = AVAX_SYN_ROUTER_V1;
        synapseBridge = AVAX_SYN_BRIDGE;

        deploySynapseBridgeModule();
        routerMock = new DelegateCaller();
    }

    function test_delegateBridge_deposit() public {
        // Deal tokens directly to the Router Mock
        uint256 amount = 1e8;
        deal(BTC_B, address(routerMock), amount);
        depositEvent = DepositEvent({to: address(1), chainId: 2, token: BTC_B, amount: amount});
        SwapQuery memory destQuery;
        bytes memory delegatedCall = abi.encodeCall(
            SynapseBridgeModule.delegateBridge,
            (address(1), 2, BTC_B, amount, destQuery)
        );
        expectDepositEvent();
        routerMock.performDelegateCall(synapseBridgeModule, delegatedCall);
    }

    function test_delegateBridge_depositAndSwap() public {
        // Deal tokens directly to the Router Mock
        uint256 amount = 1e8;
        deal(BTC_B, address(routerMock), amount);
        depositAndSwapEvent = DepositAndSwapEvent({
            to: address(1),
            chainId: 2,
            token: BTC_B,
            amount: amount,
            tokenIndexFrom: 3,
            tokenIndexTo: 4,
            minDy: 5,
            deadline: 6
        });
        SwapQuery memory destQuery = SwapQuery({
            routerAdapter: address(7),
            tokenOut: address(8),
            minAmountOut: 5,
            deadline: 6,
            rawParams: getSwapParams({pool: address(9), indexFrom: 3, indexTo: 4})
        });
        bytes memory delegatedCall = abi.encodeCall(
            SynapseBridgeModule.delegateBridge,
            (address(1), 2, BTC_B, amount, destQuery)
        );
        expectDepositAndSwapEvent();
        routerMock.performDelegateCall(synapseBridgeModule, delegatedCall);
    }

    function test_delegateBridge_redeem() public {
        // Deal tokens directly to the Router Mock
        uint256 amount = 1e18;
        deal(NUSD, address(routerMock), amount);
        redeemEvent = RedeemEvent({to: address(1), chainId: 2, token: NUSD, amount: amount});
        SwapQuery memory destQuery;
        bytes memory delegatedCall = abi.encodeCall(
            SynapseBridgeModule.delegateBridge,
            (address(1), 2, NUSD, amount, destQuery)
        );
        expectRedeemEvent();
        routerMock.performDelegateCall(synapseBridgeModule, delegatedCall);
    }

    function test_delegateBridge_redeem_wrapper_GMX() public {
        // Deal GMX tokens (the user facing token) directly to the Router Mock
        uint256 amount = 1e18;
        deal(GMX, address(routerMock), amount);
        // The actual bridge token is the wrapper
        redeemEvent = RedeemEvent({to: address(1), chainId: 2, token: GMX_WRAPPER, amount: amount});
        SwapQuery memory destQuery;
        bytes memory delegatedCall = abi.encodeCall(
            SynapseBridgeModule.delegateBridge,
            (address(1), 2, GMX, amount, destQuery)
        );
        expectRedeemEvent();
        routerMock.performDelegateCall(synapseBridgeModule, delegatedCall);
    }

    function test_delegateBridge_redeemAndSwap() public {
        // Deal tokens directly to the Router Mock
        uint256 amount = 1e18;
        deal(NUSD, address(routerMock), amount);
        redeemAndSwapEvent = RedeemAndSwapEvent({
            to: address(1),
            chainId: 2,
            token: NUSD,
            amount: amount,
            tokenIndexFrom: 3,
            tokenIndexTo: 4,
            minDy: 5,
            deadline: 6
        });
        SwapQuery memory destQuery = SwapQuery({
            routerAdapter: address(7),
            tokenOut: address(8),
            minAmountOut: 5,
            deadline: 6,
            rawParams: getSwapParams({pool: address(9), indexFrom: 3, indexTo: 4})
        });
        bytes memory delegatedCall = abi.encodeCall(
            SynapseBridgeModule.delegateBridge,
            (address(1), 2, NUSD, amount, destQuery)
        );
        expectRedeemAndSwapEvent();
        routerMock.performDelegateCall(synapseBridgeModule, delegatedCall);
    }

    function test_delegateBridge_redeemAndRemove() public {
        // Deal tokens directly to the Router Mock
        uint256 amount = 1e18;
        deal(NUSD, address(routerMock), amount);
        redeemAndRemoveEvent = RedeemAndRemoveEvent({
            to: address(1),
            chainId: 2,
            token: NUSD,
            amount: amount,
            swapTokenIndex: 3,
            swapMinAmount: 4,
            swapDeadline: 5
        });
        SwapQuery memory destQuery = SwapQuery({
            routerAdapter: address(6),
            tokenOut: address(7),
            minAmountOut: 4,
            deadline: 5,
            rawParams: getRemoveLiquidityParams({pool: address(8), indexTo: 3})
        });
        bytes memory delegatedCall = abi.encodeCall(
            SynapseBridgeModule.delegateBridge,
            (address(1), 2, NUSD, amount, destQuery)
        );
        expectRedeemAndRemoveEvent();
        routerMock.performDelegateCall(synapseBridgeModule, delegatedCall);
    }

    function getSwapParams(
        address pool,
        uint8 indexFrom,
        uint8 indexTo
    ) internal pure returns (bytes memory) {
        return abi.encode(DefaultParams(Action.Swap, pool, indexFrom, indexTo));
    }

    function getRemoveLiquidityParams(address pool, uint8 indexTo) internal pure returns (bytes memory) {
        // indexFrom is set to 0xFF
        return abi.encode(DefaultParams(Action.RemoveLiquidity, pool, 0xFF, indexTo));
    }
}
