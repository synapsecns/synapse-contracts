// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "./SynapseRouterSuite.t.sol";
import {JewelBridgeSwap} from "../../../contracts/bridge/wrappers/JewelBridgeSwap.sol";

// solhint-disable func-name-mixedcase
contract SynapseRouterEndToEndJewelTest is SynapseRouterSuite {
    IERC20 internal avaJewel;
    IERC20 internal harJewel;
    IERC20 internal harLegacyJewel;
    JewelBridgeSwap internal harmonyJewelSwap;

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                      OVERRIDES FOR JEWEL SETUP                       ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function deployTestAvalanche() public virtual override returns (ChainSetup memory chain) {
        chain = super.deployTestAvalanche();
        avaJewel = deploySynapseERC20(chain, SYMBOL_JEWEL, 18);
    }

    function deployTestDFK() public virtual override returns (ChainSetup memory chain) {
        chain = super.deployTestDFK();
        // Add JEWEL to Router config
        _addDepositToken(chain, SYMBOL_JEWEL, address(chain.wgas));
    }

    function deployTestHarmony() public virtual override returns (ChainSetup memory chain) {
        chain = super.deployTestHarmony();
        harJewel = deploySynapseERC20(chain, SYMBOL_JEWEL, 18);
        harLegacyJewel = deployERC20(chain, "LEGACY JEWEL", 18);
        harmonyJewelSwap = new JewelBridgeSwap(harLegacyJewel, harJewel);
        // JewelSwap should have a minter role
        {
            SynapseERC20 _harJewel = SynapseERC20(address(harJewel));
            _harJewel.grantRole(_harJewel.MINTER_ROLE(), address(harmonyJewelSwap));
        }
        chain.quoter.addPool(address(harmonyJewelSwap));
        // Setup initial Legacy Jewel balance for JewelBridgeSwap
        mintInitialTestTokens(chain, address(harmonyJewelSwap), address(harLegacyJewel), 10**24);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                    TESTS: JEWEL (FROM AVALANCHE)                     ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function test_avalancheToDfk_inJEWEL_outJEWEL() public {
        // Prepare test parameters: Avalanche JEWEL -> DFK JEWEL (gas)
        ChainSetup memory origin = chains[AVA_CHAINID];
        ChainSetup memory destination = chains[DFK_CHAINID];
        IERC20 tokenIn = avaJewel;
        IERC20 tokenOut = destination.gas;
        uint256 amountIn = 10**18;
        address bridgeTokenDest = address(destination.wgas);
        (SwapQuery memory originQuery, SwapQuery memory destQuery) = performQuoteCalls(
            origin,
            destination,
            tokenIn,
            tokenOut,
            amountIn
        );
        redeemEvent = RedeemEvent(TO, DFK_CHAINID, address(avaJewel), amountIn);
        // User interacts with the SynapseRouter on origin chain
        initiateBridgeTx(expectRedeemEvent, origin, destination, tokenIn, tokenOut, amountIn);
        // Validator completes the transaction on destination chain
        checkCompletedBridgeTx(destination, bridgeTokenDest, originQuery, destQuery);
    }

    function test_avalancheToHarmony_inJEWEL_outSynJEWEL() public {
        // Prepare test parameters: Avalanche JEWEL -> Harmony synJEWEL
        ChainSetup memory origin = chains[AVA_CHAINID];
        ChainSetup memory destination = chains[HAR_CHAINID];
        IERC20 tokenIn = avaJewel;
        IERC20 tokenOut = harJewel;
        uint256 amountIn = 10**18;
        address bridgeTokenDest = address(harJewel);
        (SwapQuery memory originQuery, SwapQuery memory destQuery) = performQuoteCalls(
            origin,
            destination,
            tokenIn,
            tokenOut,
            amountIn
        );
        redeemEvent = RedeemEvent(TO, HAR_CHAINID, address(avaJewel), amountIn);
        // User interacts with the SynapseRouter on origin chain
        initiateBridgeTx(expectRedeemEvent, origin, destination, tokenIn, tokenOut, amountIn);
        // Validator completes the transaction on destination chain
        checkCompletedBridgeTx(destination, bridgeTokenDest, originQuery, destQuery);
    }

    function test_avalancheToHarmony_inJEWEL_outJEWEL() public {
        // Prepare test parameters: Avalanche JEWEL -> Harmony JEWEL
        ChainSetup memory origin = chains[AVA_CHAINID];
        ChainSetup memory destination = chains[HAR_CHAINID];
        IERC20 tokenIn = avaJewel;
        IERC20 tokenOut = harLegacyJewel;
        uint256 amountIn = 10**18;
        address bridgeTokenDest = address(harJewel);
        (SwapQuery memory originQuery, SwapQuery memory destQuery) = performQuoteCalls(
            origin,
            destination,
            tokenIn,
            tokenOut,
            amountIn
        );
        redeemAndSwapEvent = RedeemAndSwapEvent({
            to: TO,
            chainId: HAR_CHAINID,
            token: address(avaJewel),
            amount: amountIn,
            tokenIndexFrom: 1, // this is the only swap pool with a reversed token order
            tokenIndexTo: 0,
            minDy: destQuery.minAmountOut,
            deadline: destQuery.deadline
        });
        // User interacts with the SynapseRouter on origin chain
        initiateBridgeTx(expectRedeemAndSwapEvent, origin, destination, tokenIn, tokenOut, amountIn);
        // Validator completes the transaction on destination chain
        checkCompletedBridgeTx(destination, bridgeTokenDest, originQuery, destQuery);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                       TESTS: JEWEL (FROM DFK)                        ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function test_dfkToAvalanche_inJEWEL_outJEWEL() public {
        // Prepare test parameters: DFK JEWEL (gas) -> Avalanche JEWEL
        ChainSetup memory origin = chains[DFK_CHAINID];
        ChainSetup memory destination = chains[AVA_CHAINID];
        IERC20 tokenIn = origin.gas;
        IERC20 tokenOut = avaJewel;
        uint256 amountIn = 10**18;
        address bridgeTokenDest = address(avaJewel);
        (SwapQuery memory originQuery, SwapQuery memory destQuery) = performQuoteCalls(
            origin,
            destination,
            tokenIn,
            tokenOut,
            amountIn
        );
        depositEvent = DepositEvent(TO, AVA_CHAINID, address(origin.wgas), amountIn);
        // User interacts with the SynapseRouter on origin chain
        initiateBridgeTx(expectDepositEvent, origin, destination, tokenIn, tokenOut, amountIn);
        // Validator completes the transaction on destination chain
        checkCompletedBridgeTx(destination, bridgeTokenDest, originQuery, destQuery);
    }

    function test_dfkToAvalanche_inWJEWEL_outJEWEL() public {
        // Prepare test parameters: DFK WJEWEL (wgas) -> Avalanche JEWEL
        ChainSetup memory origin = chains[DFK_CHAINID];
        ChainSetup memory destination = chains[AVA_CHAINID];
        IERC20 tokenIn = origin.wgas;
        IERC20 tokenOut = avaJewel;
        uint256 amountIn = 10**18;
        address bridgeTokenDest = address(avaJewel);
        (SwapQuery memory originQuery, SwapQuery memory destQuery) = performQuoteCalls(
            origin,
            destination,
            tokenIn,
            tokenOut,
            amountIn
        );
        depositEvent = DepositEvent(TO, AVA_CHAINID, address(origin.wgas), amountIn);
        // User interacts with the SynapseRouter on origin chain
        initiateBridgeTx(expectDepositEvent, origin, destination, tokenIn, tokenOut, amountIn);
        // Validator completes the transaction on destination chain
        checkCompletedBridgeTx(destination, bridgeTokenDest, originQuery, destQuery);
    }

    function test_dfkToHarmony_inJEWEL_outSynJEWEL() public {
        // Prepare test parameters: DFK JEWEL (gas) -> Harmony synJEWEL
        ChainSetup memory origin = chains[DFK_CHAINID];
        ChainSetup memory destination = chains[HAR_CHAINID];
        IERC20 tokenIn = origin.gas;
        IERC20 tokenOut = harJewel;
        uint256 amountIn = 10**18;
        address bridgeTokenDest = address(harJewel);
        (SwapQuery memory originQuery, SwapQuery memory destQuery) = performQuoteCalls(
            origin,
            destination,
            tokenIn,
            tokenOut,
            amountIn
        );
        depositEvent = DepositEvent(TO, HAR_CHAINID, address(origin.wgas), amountIn);
        // User interacts with the SynapseRouter on origin chain
        initiateBridgeTx(expectDepositEvent, origin, destination, tokenIn, tokenOut, amountIn);
        // Validator completes the transaction on destination chain
        checkCompletedBridgeTx(destination, bridgeTokenDest, originQuery, destQuery);
    }

    function test_dfkToHarmony_inJEWEL_outJEWEL() public {
        // Prepare test parameters: DFK JEWEL (gas) -> Harmony JEWEL
        ChainSetup memory origin = chains[DFK_CHAINID];
        ChainSetup memory destination = chains[HAR_CHAINID];
        IERC20 tokenIn = origin.gas;
        IERC20 tokenOut = harLegacyJewel;
        uint256 amountIn = 10**18;
        address bridgeTokenDest = address(harJewel);
        (SwapQuery memory originQuery, SwapQuery memory destQuery) = performQuoteCalls(
            origin,
            destination,
            tokenIn,
            tokenOut,
            amountIn
        );
        depositAndSwapEvent = DepositAndSwapEvent({
            to: TO,
            chainId: HAR_CHAINID,
            token: address(origin.wgas),
            amount: amountIn,
            tokenIndexFrom: 1, // this is the only swap pool with a reversed token order
            tokenIndexTo: 0,
            minDy: destQuery.minAmountOut,
            deadline: destQuery.deadline
        });
        // User interacts with the SynapseRouter on origin chain
        initiateBridgeTx(expectDepositAndSwapEvent, origin, destination, tokenIn, tokenOut, amountIn);
        // Validator completes the transaction on destination chain
        checkCompletedBridgeTx(destination, bridgeTokenDest, originQuery, destQuery);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                     TESTS: JEWEL (FROM HARMONY)                      ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function test_harmonyToAvalanche_inSynJEWEL_outJEWEL() public {
        // Prepare test parameters: Harmony synJEWEL -> Avalanche JEWEL
        ChainSetup memory origin = chains[HAR_CHAINID];
        ChainSetup memory destination = chains[AVA_CHAINID];
        IERC20 tokenIn = harJewel;
        IERC20 tokenOut = avaJewel;
        uint256 amountIn = 10**18;
        address bridgeTokenDest = address(avaJewel);
        (SwapQuery memory originQuery, SwapQuery memory destQuery) = performQuoteCalls(
            origin,
            destination,
            tokenIn,
            tokenOut,
            amountIn
        );
        redeemEvent = RedeemEvent(TO, AVA_CHAINID, address(harJewel), amountIn);
        // User interacts with the SynapseRouter on origin chain
        initiateBridgeTx(expectRedeemEvent, origin, destination, tokenIn, tokenOut, amountIn);
        // Validator completes the transaction on destination chain
        checkCompletedBridgeTx(destination, bridgeTokenDest, originQuery, destQuery);
    }

    function test_harmonyToAvalanche_inJEWEL_outJEWEL() public {
        // Prepare test parameters: Harmony JEWEL -> Avalanche JEWEL
        ChainSetup memory origin = chains[HAR_CHAINID];
        ChainSetup memory destination = chains[AVA_CHAINID];
        IERC20 tokenIn = harLegacyJewel;
        IERC20 tokenOut = avaJewel;
        uint256 amountIn = 10**18;
        address bridgeTokenDest = address(avaJewel);
        (SwapQuery memory originQuery, SwapQuery memory destQuery) = performQuoteCalls(
            origin,
            destination,
            tokenIn,
            tokenOut,
            amountIn
        );
        redeemEvent = RedeemEvent(TO, AVA_CHAINID, address(harJewel), amountIn);
        // User interacts with the SynapseRouter on origin chain
        initiateBridgeTx(expectRedeemEvent, origin, destination, tokenIn, tokenOut, amountIn);
        // Validator completes the transaction on destination chain
        checkCompletedBridgeTx(destination, bridgeTokenDest, originQuery, destQuery);
    }

    function test_harmonyToDFK_inSynJEWEL_outJEWEL() public {
        // Prepare test parameters: Harmony synJEWEL -> DFK JEWEL (gas)
        ChainSetup memory origin = chains[HAR_CHAINID];
        ChainSetup memory destination = chains[DFK_CHAINID];
        IERC20 tokenIn = harJewel;
        IERC20 tokenOut = destination.gas;
        uint256 amountIn = 10**18;
        address bridgeTokenDest = address(destination.wgas);
        (SwapQuery memory originQuery, SwapQuery memory destQuery) = performQuoteCalls(
            origin,
            destination,
            tokenIn,
            tokenOut,
            amountIn
        );
        redeemEvent = RedeemEvent(TO, DFK_CHAINID, address(harJewel), amountIn);
        // User interacts with the SynapseRouter on origin chain
        initiateBridgeTx(expectRedeemEvent, origin, destination, tokenIn, tokenOut, amountIn);
        // Validator completes the transaction on destination chain
        checkCompletedBridgeTx(destination, bridgeTokenDest, originQuery, destQuery);
    }

    function test_harmonyToDFK_inJEWEL_outJEWEL() public {
        // Prepare test parameters: Harmony JEWEL -> DFK JEWEL (gas)
        ChainSetup memory origin = chains[HAR_CHAINID];
        ChainSetup memory destination = chains[DFK_CHAINID];
        IERC20 tokenIn = harLegacyJewel;
        IERC20 tokenOut = destination.gas;
        uint256 amountIn = 10**18;
        address bridgeTokenDest = address(destination.wgas);
        (SwapQuery memory originQuery, SwapQuery memory destQuery) = performQuoteCalls(
            origin,
            destination,
            tokenIn,
            tokenOut,
            amountIn
        );
        redeemEvent = RedeemEvent(TO, DFK_CHAINID, address(harJewel), amountIn);
        // User interacts with the SynapseRouter on origin chain
        initiateBridgeTx(expectRedeemEvent, origin, destination, tokenIn, tokenOut, amountIn);
        // Validator completes the transaction on destination chain
        checkCompletedBridgeTx(destination, bridgeTokenDest, originQuery, destQuery);
    }
}
