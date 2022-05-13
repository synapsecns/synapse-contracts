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

    function testBridgeOutToken(uint256 amountIn, uint8 indexFrom) public {
        _testBridgeOuts(amountIn, indexFrom, false);
    }

    function testBridgeOutGas(uint256 amountIn) public {
        // WGAS is always the first token
        uint8 indexFrom = 0;

        _testBridgeOuts(amountIn, indexFrom, true);
    }

    function _testBridgeOuts(
        uint256 amountIn,
        uint8 indexFrom,
        bool startFromGas
    ) internal {
        uint256 tokensAmount = bridgeTokens.length;
        uint256 chainsAmount = dstChainIdsEVM.length;

        for (uint256 j = 0; j < chainsAmount; ++j) {
            _BridgeOutBools memory bools = _BridgeOutBools({
                gasdropRequested: false,
                isEVM: true,
                startFromGas: startFromGas
            });
            uint256 chainId = dstChainIdsEVM[j];
            for (uint256 i = 0; i < tokensAmount; ++i) {
                address bridgeToken = bridgeTokens[i];
                // gasDrop = false, isEVM = true
                _testBridgeOut(amountIn, indexFrom, bridgeToken, chainId, bools);
                // gasDrop = true, isEVM = true
                bools.gasdropRequested = true;
                _testBridgeOut(amountIn, indexFrom, bridgeToken, chainId, bools);
            }
        }

        for (uint256 i = 0; i < tokensAmount; ++i) {
            address bridgeToken = bridgeTokens[i];
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
        if (canUnderquote[address(adapter)]) {
            assertTrue(quoteOut <= amountOut, "Quote amount is bigger than actual received");
        } else {
            assertEq(quoteOut, amountOut, "Failed to provide exact quote");
        }
    }

    // solhint-disable-next-line
    struct _BridgeOutState {
        bool isMintBurn;
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
        bool canUnderquote;
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
        assertTrue(data.offer.path.length > 0, "Path not found");
        if (data.offer.path.length == 0) return;
        data.swapParams = IBridge.SwapParams({
            minAmountOut: 0,
            path: data.offer.path,
            adapters: data.offer.adapters,
            deadline: block.timestamp
        });

        // Check if any of the adapters can give quote less than actual
        for (uint256 i = 0; i < data.offer.adapters.length; ++i) {
            if (canUnderquote[data.offer.adapters[i]]) {
                data.canUnderquote = true;
                break;
            }
        }

        _addTokenTo(data.tokenIn, user, amountIn);
        startHoax(user);
        _BridgeOutState memory state = _saveBridgeOutState(data.tokenIn, bridgeToken, bools.startFromGas);
        IERC20(data.tokenIn).safeApprove(address(router), amountIn);
        vm.stopPrank();

        if (data.canUnderquote) {
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
            data.amountOut = data.offer.amounts[data.offer.amounts.length - 1];
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
                router.bridgeGasToEVM{value: amountIn}(
                    user,
                    chainId,
                    data.swapParams,
                    data.dstSwapParams,
                    bools.gasdropRequested
                );
            } else {
                router.bridgeTokenToEVM(
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
                router.bridgeGasToNonEVM{value: amountIn}(data.to, chainId, data.swapParams);
            } else {
                router.bridgeTokenToNonEVM(data.to, chainId, data.swapParams, amountIn);
            }
        }

        vm.stopPrank();

        _checkBridgeOutState(data.tokenIn, bridgeToken, amountIn, data.amountOut, state);
    }

    function _saveBridgeOutState(
        address tokenIn,
        address tokenOut,
        bool startFromGas
    ) internal view returns (_BridgeOutState memory state) {
        IERC20 _in = IERC20(tokenIn);
        IERC20 _out = IERC20(tokenOut);
        (tokenOut, , state.isMintBurn) = bridgeConfig.getBridgeToken(tokenOut);
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
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        _BridgeOutState memory state
    ) internal {
        IERC20 _in = IERC20(tokenIn);
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

        if (tokenIn != tokenOut) {
            assertEq(_out.balanceOf(address(router)) - state.routerTokenOutBalance, 0, "TokenOut left in Router");
            assertEq(_out.balanceOf(address(bridge)) - state.bridgeTokenOutBalance, 0, "TokenOut left in Bridge");
        }
        if (state.isMintBurn) {
            assertEq(state.tokenOutTotalSupply - _out.totalSupply(), amountOut, "Incomplete burn");
        } else {
            assertEq(vault.getTokenBalance(_out) - state.vaultTokenOutBalance, amountOut, "Incomplete deposit");
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
