// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "./DefaultVaultForkedSetup.t.sol";

import {Offers} from "src-router/libraries/LibOffers.sol";
import {IBridge} from "src-vault/interfaces/IBridge.sol";

// solhint-disable code-complexity
// solhint-disable not-rely-on-time

abstract contract DefaultVaultForkedTest is DefaultVaultForkedSetup {
    using SafeERC20 for IERC20;

    bytes32[] public kappas;

    constructor(TestSetup memory config) DefaultVaultForkedSetup(config) {
        this;
    }

    function testVaultUpgrade() public {
        _testUpgrade(kappas);
    }

    function testAllAdapters(uint256 amountIn, uint8 indexFrom) public {
        uint256 amount = adapters.length;
        for (uint256 i = 0; i < amount; ++i) {
            _testAdapterSwaps(IAdapter(adapters[i]), indexFrom, amountIn);
        }
    }

    function testBridgeOutToken(
        uint256 amountIn,
        uint8 indexFrom,
        uint8 indexTo,
        uint8 chainIndex
    ) public {
        _testBridgeOuts(amountIn, indexFrom, indexTo, chainIndex, false);
    }

    function testBridgeOutGas(
        uint256 amountIn,
        uint8 indexTo,
        uint8 chainIndex
    ) public {
        // WGAS is always the first token
        uint256 indexFrom = 0;

        _testBridgeOuts(amountIn, indexFrom, indexTo, chainIndex, true);
    }

    function testBridgeIn(
        uint256 amountIn,
        uint8 indexFrom,
        uint8 indexTo
    ) public {
        _testBridgeIns(amountIn, indexFrom, indexTo);
    }

    function _testBridgeOuts(
        uint256 amountIn,
        uint256 indexFrom,
        uint256 indexTo,
        uint256 chainIndex,
        bool startFromGas
    ) internal {
        address bridgeToken = bridgeTokens[indexTo % bridgeTokens.length];

        {
            uint256 chainId = dstChainIdsEVM[chainIndex % dstChainIdsEVM.length];
            _BridgeOutBools memory bools = _BridgeOutBools({
                gasdropRequested: false,
                isEVM: true,
                startFromGas: startFromGas
            });
            // gasDrop = false, isEVM = true
            _testBridgeOut(amountIn, indexFrom, bridgeToken, chainId, bools);
            // gasDrop = true, isEVM = true
            bools.gasdropRequested = true;
            _testBridgeOut(amountIn, indexFrom, bridgeToken, chainId, bools);
        }

        {
            uint256 chainId = _getTokenChainNonEVM(bridgeToken);
            if (chainId != 0) {
                _BridgeOutBools memory bools = _BridgeOutBools({
                    gasdropRequested: false,
                    isEVM: false,
                    startFromGas: startFromGas
                });
                // gasDrop = false, isEVM = false
                _testBridgeOut(amountIn, indexFrom, bridgeToken, chainId, bools);
            }
        }
    }

    function _testBridgeIns(
        uint256 amountIn,
        uint256 indexFrom,
        uint256 indexTo
    ) internal {
        address bridgeToken = bridgeTokens[indexFrom % bridgeTokens.length];
        amountIn = _getAdjustedAmount(bridgeToken, amountIn);
        {
            // gasDrop = false, fromEVM = true
            _testBridgeIn(amountIn, bridgeToken, indexTo, false, true);
            // gasDrop = true, fromEVM = true
            _testBridgeIn(amountIn, bridgeToken, indexTo, true, true);
            // gasDrop = true, fromEVM = true
            _testBridgeIn(amountIn, bridgeToken, indexTo, true, false);
        }
    }

    function _testAdapterSwaps(
        IAdapter adapter,
        uint256 indexFrom,
        uint256 amountIn
    ) internal {
        address[] memory tokens = adapterTestTokens[address(adapter)];
        indexFrom = indexFrom % tokens.length;
        address tokenIn = tokens[indexFrom];
        amountIn = _getAdjustedAmount(tokenIn, amountIn);

        for (uint256 i = 0; i < tokens.length; ++i) {
            if (i != indexFrom) {
                _testAdapterSwap(adapter, tokenIn, amountIn, tokens[i]);
            }
        }
    }

    function _testAdapterSwap(
        IAdapter adapter,
        address tokenIn,
        uint256 amountIn,
        address tokenOut
    ) internal {
        uint256 quoteOut = adapter.query(amountIn, tokenIn, tokenOut);
        if (quoteOut == 0) return;

        _addTokenTo(tokenIn, adapter.depositAddress(tokenIn, tokenOut), amountIn);

        uint256 userPre = IERC20(tokenOut).balanceOf(user);
        uint256 amountOut = adapter.swap(amountIn, tokenIn, tokenOut, user);
        assertEq(IERC20(tokenOut).balanceOf(user) - userPre, amountOut, "Failed to report amountOut");
        if (isUnderquoting[address(adapter)]) {
            assertTrue(quoteOut <= amountOut, "Quote amount is bigger than actual received");
        } else {
            assertEq(quoteOut, amountOut, "Failed to provide exact quote");
        }
    }

    // -- TEST: BRIDGE OUT --

    // solhint-disable-next-line
    struct _BridgeOutState {
        bool isMintBurn;
        bool hasWrapper;
        bool startFromGas;
        uint256 userTokenInBalance;
        uint256 routerTokenInBalance;
        uint256 routerTokenOutBalance;
        uint256 bridgeTokenInBalance;
        uint256 bridgeTokenOutBalance;
        uint256 vaultTokenOutBalance;
        uint256 tokenOutTotalSupply;
    }

    // solhint-disable-next-line
    struct _BridgeOutData {
        address tokenIn;
        address dstBridgeTokenEVM;
        Offers.FormattedOffer offer;
        IBridge.SwapParams swapParams;
        IBridge.SwapParams dstSwapParams;
        bool isUnderquoting;
        uint256 quotedOut;
        uint256 reportedOut;
        uint256 amountOut;
        bytes32 to;
        string dstBridgeTokenNonEVM;
    }

    // solhint-disable-next-line
    struct _BridgeOutBools {
        bool gasdropRequested;
        bool isEVM;
        bool startFromGas;
    }

    function _testBridgeOut(
        uint256 amountIn,
        uint256 indexFrom,
        address bridgeToken,
        uint256 chainId,
        _BridgeOutBools memory bools
    ) internal {
        if (chainId == 0) return;

        _BridgeOutData memory data;
        data.tokenIn = allTokens[indexFrom % allTokens.length];
        amountIn = _getAdjustedAmount(data.tokenIn, amountIn);

        if (bools.isEVM) {
            data.dstBridgeTokenEVM = _getTokenDstAddress(bridgeToken, chainId);
            data.dstSwapParams = _getEmptySwapParams(data.dstBridgeTokenEVM);
        } else {
            data.to = utils.addressToBytes32(user);
            data.dstBridgeTokenNonEVM = tokenNames[bridgeToken];
        }

        // This should work both with tokenIn != tokenOut and tokenIn == tokenOut
        data.offer = quoter.bestPathToBridge(data.tokenIn, amountIn, bridgeToken);

        if (data.offer.path.length == 0) return;
        data.swapParams = IBridge.SwapParams({
            minAmountOut: 0,
            path: data.offer.path,
            adapters: data.offer.adapters,
            deadline: block.timestamp
        });
        data.quotedOut = data.offer.amounts[data.offer.amounts.length - 1];

        // Check if any of the adapters can give quote less than actual
        for (uint256 i = 0; i < data.offer.adapters.length; ++i) {
            if (isUnderquoting[data.offer.adapters[i]]) {
                data.isUnderquoting = true;
                break;
            }
        }

        _addTokenTo(data.tokenIn, user, amountIn);
        startHoax(user);
        _BridgeOutState memory state = _saveBridgeOutState(data.tokenIn, bridgeToken, bools.startFromGas);
        IERC20(data.tokenIn).safeApprove(address(router), amountIn);
        vm.stopPrank();

        if (data.isUnderquoting) {
            // Simulate swapping to get amountOut for event verification
            // Utils will swap the tokens and revert, using amountOut as revert reason
            // Hacky af, but this works
            try
                utils.peekReturnValue(
                    user,
                    address(router),
                    abi.encodeWithSelector(
                        bools.startFromGas ? router.swapFromGAS.selector : router.swap.selector,
                        user,
                        data.swapParams.path,
                        data.swapParams.adapters,
                        amountIn,
                        data.swapParams.minAmountOut,
                        data.swapParams.deadline
                    ),
                    bools.startFromGas ? amountIn : 0
                )
            {
                this;
            } catch Error(string memory reason) {
                data.amountOut = abi.decode(bytes(reason), (uint256));
            }
        } else {
            data.amountOut = data.quotedOut;
        }

        vm.expectEmit(true, false, false, true);
        vm.startPrank(user);
        if (bools.isEVM) {
            emit BridgedOutEVM(
                user,
                chainId,
                IERC20(bridgeToken),
                data.amountOut,
                IERC20(data.dstBridgeTokenEVM),
                data.dstSwapParams,
                bools.gasdropRequested
            );
            if (bools.startFromGas) {
                data.reportedOut = router.bridgeGasToEVM{value: amountIn}(
                    user,
                    chainId,
                    data.swapParams,
                    data.dstSwapParams,
                    bools.gasdropRequested
                );
            } else {
                data.reportedOut = router.bridgeTokenToEVM(
                    user,
                    chainId,
                    data.swapParams,
                    amountIn,
                    data.dstSwapParams,
                    bools.gasdropRequested
                );
            }
        } else {
            emit BridgedOutNonEVM(data.to, chainId, IERC20(bridgeToken), data.amountOut, data.dstBridgeTokenNonEVM);
            if (bools.startFromGas) {
                data.reportedOut = router.bridgeGasToNonEVM{value: amountIn}(data.to, chainId, data.swapParams);
            } else {
                data.reportedOut = router.bridgeTokenToNonEVM(data.to, chainId, data.swapParams, amountIn);
            }
        }

        vm.stopPrank();

        _checkBridgeOutState(bridgeToken, amountIn, data, state);
    }

    function _saveBridgeOutState(
        address tokenIn,
        address tokenOut,
        bool startFromGas
    ) internal view returns (_BridgeOutState memory state) {
        IERC20 _in = IERC20(tokenIn);
        IERC20 _out = IERC20(tokenOut);
        address wrapper;
        (wrapper, , state.isMintBurn) = bridgeConfig.getBridgeToken(tokenOut);
        state.hasWrapper = (wrapper != tokenOut);
        state.startFromGas = startFromGas;

        state.userTokenInBalance = startFromGas ? user.balance : _in.balanceOf(user);

        state.routerTokenInBalance = startFromGas ? address(router).balance : _in.balanceOf(address(router));
        state.routerTokenOutBalance = _out.balanceOf(address(router));

        state.bridgeTokenInBalance = startFromGas ? address(bridge).balance : _in.balanceOf(address(bridge));
        state.bridgeTokenOutBalance = _out.balanceOf(address(bridge));

        state.vaultTokenOutBalance = vault.getTokenBalance(_out);

        state.tokenOutTotalSupply = _out.totalSupply();
    }

    function _checkBridgeOutState(
        address tokenOut,
        uint256 amountIn,
        _BridgeOutData memory data,
        _BridgeOutState memory state
    ) internal {
        IERC20 _in = IERC20(data.tokenIn);
        IERC20 _out = IERC20(tokenOut);
        if (state.startFromGas) {
            assertEq(address(router).balance - state.routerTokenInBalance, 0, "TokenIn left in Router");
            assertEq(address(bridge).balance - state.bridgeTokenInBalance, 0, "TokenIn left in Bridge");
            assertEq(state.userTokenInBalance - user.balance, amountIn, "Incorrect amount spent from user");
        } else {
            assertEq(_in.balanceOf(address(router)) - state.routerTokenInBalance, 0, "TokenIn left in Router");
            assertEq(_in.balanceOf(address(bridge)) - state.bridgeTokenInBalance, 0, "TokenIn left in Bridge");
            assertEq(state.userTokenInBalance - _in.balanceOf(user), amountIn, "Incorrect amount spent from user");
        }

        if (data.tokenIn != tokenOut) {
            assertEq(_out.balanceOf(address(router)) - state.routerTokenOutBalance, 0, "TokenOut left in Router");
            assertEq(_out.balanceOf(address(bridge)) - state.bridgeTokenOutBalance, 0, "TokenOut left in Bridge");
        }
        if (state.isMintBurn) {
            if (!state.hasWrapper) {
                // Tokens that need a wrapper to be bridged are supposed to check invariant separately
                assertEq(state.tokenOutTotalSupply - _out.totalSupply(), data.amountOut, "Incomplete burn");
            }
        } else {
            assertEq(vault.getTokenBalance(_out) - state.vaultTokenOutBalance, data.amountOut, "Incomplete deposit");
        }

        assertEq(data.reportedOut, data.amountOut, "Failed to report correct bridged amount");
        assertTrue(data.reportedOut >= data.quotedOut, "Quote amount too big");
    }

    // -- TEST: BRIDGE IN --

    // solhint-disable-next-line
    struct _BridgeInData {
        address tokenOut;
        Offers.FormattedOffer offer;
        IBridge.SwapParams swapParams;
        bool isUnderquoting;
        uint256 amountOut;
        uint256 quotedOut;
        bytes32 kappa;
        uint256 bridgeFee;
        uint256 gasdropAmount;
        uint256 chainIdNonEVM;
        string bridgeTokenNonEVM;
    }

    // solhint-disable-next-line
    struct _BridgeInState {
        bool isMintBurn;
        bool hasWrapper;
        bool endsWithGas;
        uint256 userTokenOutBalance;
        uint256 userGasBalance;
        uint256 routerTokenInBalance;
        uint256 routerTokenOutBalance;
        uint256 vaultTokenInBalance;
        uint256 vaultTokenInFees;
        uint256 tokenInTotalSupply;
    }

    function _testBridgeIn(
        uint256 amountIn,
        address bridgeToken,
        uint256 indexTo,
        bool gasdropRequested,
        bool fromEVM
    ) internal {
        _BridgeInData memory data;
        data.tokenOut = allTokens[indexTo % allTokens.length];
        amountIn = _getAdjustedAmount(bridgeToken, amountIn);

        (data.bridgeFee, , , ) = bridgeConfig.calculateBridgeFee(
            bridgeToken,
            amountIn,
            gasdropRequested,
            bridgeToken == data.tokenOut ? 0 : _config.bridgeMaxSwaps
        );
        data.gasdropAmount = gasdropRequested ? vault.chainGasAmount() : 0;
        data.kappa = utils.getNextKappa();

        if (!fromEVM) {
            (, , , , , , , , data.chainIdNonEVM, data.bridgeTokenNonEVM) = bridgeConfig.tokenConfigs(bridgeToken);
            if (data.chainIdNonEVM == 0) return;
        }

        data.offer = quoter.bestPathFromBridge(bridgeToken, amountIn, data.tokenOut, gasdropRequested);

        if (data.offer.path.length == 0) return;
        data.swapParams = IBridge.SwapParams({
            minAmountOut: 0,
            path: data.offer.path,
            adapters: data.offer.adapters,
            deadline: block.timestamp
        });
        data.quotedOut = data.offer.amounts[data.offer.amounts.length - 1];

        // Check if any of the adapters can give quote less than actual
        for (uint256 i = 0; i < data.offer.adapters.length; ++i) {
            if (isUnderquoting[data.offer.adapters[i]]) {
                data.isUnderquoting = true;
                break;
            }
        }

        if (data.isUnderquoting) {
            _addTokenTo(bridgeToken, dude, amountIn);
            startHoax(dude);
            IERC20(bridgeToken).safeApprove(address(router), amountIn);
            vm.stopPrank();
            try
                utils.peekReturnValue(
                    dude,
                    address(router),
                    abi.encodeWithSelector(
                        router.swap.selector,
                        dude,
                        data.swapParams.path,
                        data.swapParams.adapters,
                        amountIn - data.bridgeFee,
                        data.swapParams.minAmountOut,
                        data.swapParams.deadline
                    ),
                    0
                )
            {
                this;
            } catch Error(string memory reason) {
                data.amountOut = abi.decode(bytes(reason), (uint256));
            }
            startHoax(dude);
            IERC20(bridgeToken).safeApprove(address(router), 0);
            vm.stopPrank();
        } else {
            data.amountOut = data.quotedOut;
        }

        _BridgeInState memory state = _saveBridgeInState(bridgeToken, data.tokenOut);

        vm.expectEmit(true, false, false, true);
        emit TokenBridgedIn(
            user,
            IERC20(bridgeToken),
            amountIn,
            data.bridgeFee,
            IERC20(data.tokenOut),
            data.amountOut,
            data.gasdropAmount,
            data.kappa
        );

        hoax(node);
        if (fromEVM) {
            bridge.bridgeInEVM(user, IERC20(bridgeToken), amountIn, data.swapParams, gasdropRequested, data.kappa);
        } else {
            bridge.bridgeInNonEVM(user, data.chainIdNonEVM, data.bridgeTokenNonEVM, amountIn, data.kappa);
        }

        _checkBridgeInState(bridgeToken, amountIn, state, data);
    }

    function _saveBridgeInState(address tokenIn, address tokenOut) internal view returns (_BridgeInState memory state) {
        IERC20 _in = IERC20(tokenIn);
        IERC20 _out = IERC20(tokenOut);
        state.endsWithGas = tokenOut == allTokens[0];
        address wrapper;
        (wrapper, , state.isMintBurn) = bridgeConfig.getBridgeToken(tokenIn);
        state.hasWrapper = (tokenIn != wrapper);

        state.userTokenOutBalance = _out.balanceOf(user);
        state.userGasBalance = user.balance;

        state.routerTokenInBalance = _in.balanceOf(address(router));
        state.routerTokenOutBalance = _out.balanceOf(address(router));

        state.vaultTokenInBalance = vault.getTokenBalance(_in);
        state.vaultTokenInFees = vault.getFeeBalance(_in);

        state.tokenInTotalSupply = _in.totalSupply();
    }

    function _checkBridgeInState(
        address tokenIn,
        uint256 amountIn,
        _BridgeInState memory state,
        _BridgeInData memory data
    ) internal {
        IERC20 _in = IERC20(tokenIn);
        IERC20 _out = IERC20(data.tokenOut);
        if (state.endsWithGas) {
            assertEq(
                user.balance - state.userGasBalance,
                data.amountOut + data.gasdropAmount,
                "Incorrect amount of GAS gained"
            );
        } else {
            assertEq(
                _out.balanceOf(user) - state.userTokenOutBalance,
                data.amountOut,
                "Incorrect amount of tokenOut gained"
            );
            assertEq(user.balance - state.userGasBalance, data.gasdropAmount, "Incorrect amount of GAS airdropped");
        }

        assertTrue(data.amountOut >= data.quotedOut, "Quote amount too big");

        assertEq(_in.balanceOf(address(router)), state.routerTokenInBalance, "TokenIn left in Router");
        assertEq(_out.balanceOf(address(router)), state.routerTokenOutBalance, "TokenOut left in Router");

        assertEq(
            vault.getFeeBalance(_in) - state.vaultTokenInFees,
            data.bridgeFee,
            "Incorrect amount of fee gained by Vault"
        );

        if (state.isMintBurn) {
            if (!state.hasWrapper) {
                // Tokens that need a wrapper to be bridged are supposed to check invariant separately
                assertEq(_in.totalSupply() - state.tokenInTotalSupply, amountIn, "Incorrect amount minted");
            }
        } else {
            assertEq(state.vaultTokenInBalance - vault.getTokenBalance(_in), amountIn, "Incorrect amount withdrawn");
        }
    }

    function _getEmptySwapParams(address token) internal pure returns (IBridge.SwapParams memory swapParams) {
        swapParams.path = new address[](1);
        swapParams.path[0] = token;
    }

    function _getAdjustedAmount(address token, uint256 amount) internal view returns (uint256 amountAdj) {
        amountAdj = minTokenAmount[token] + (amount % maxTokenAmount[token]);
    }

    function _addTokenTo(
        address token,
        address to,
        uint256 amount
    ) internal {
        if (token == allTokens[0]) {
            deal(address(this), amount);
            IWETH9(payable(token)).deposit{value: amount}();
        } else {
            // Do not update totalSupply for nUSD on Mainnet, as this screws pool calculations
            bool updateTotalSupply = (token != tokenFixedTotalSupply);
            deal(token, address(this), amount, updateTotalSupply);
        }
        IERC20(token).safeTransfer(to, amount);
    }

    function _getTokenChainNonEVM(address token) internal view returns (uint256 chainIdNonEVM) {
        (, , , , , , , , chainIdNonEVM, ) = bridgeConfig.tokenConfigs(token);
    }
}
