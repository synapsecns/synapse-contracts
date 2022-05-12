// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "./DefaultVaultForkedSetup.t.sol";

import {Offers} from "src-router/libraries/LibOffers.sol";
import {IBridge} from "src-vault/interfaces/IBridge.sol";

abstract contract DefaultVaultForkedTest is DefaultVaultForkedSetup {
    using SafeERC20 for IERC20;

    bytes32[] public kappas;

    uint256 public constant MIN_SWAP_AMOUNT = 10**3;

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

    function testBridgeDirect() public {
        uint256 tokensAmount = bridgeTokens.length;
        uint256 chainsAmount = dstChainIdsEVM.length;

        for (uint256 j = 0; j < chainsAmount; ++j) {
            uint256 chainId = dstChainIdsEVM[j];
            for (uint256 i = 0; i < tokensAmount; ++i) {
                _testDirectBridgeEVM(i, 10**6, chainId, false);
                _testDirectBridgeEVM(i, 10**7, chainId, true);
            }
        }
        for (uint256 i = 0; i < tokensAmount; ++i) {
            _testDirectBridgeNonEVM(i, 10**8);
        }
    }

    function testBridgeSwaps(
        uint256 amountIn,
        uint8 indexFrom,
        bool gasdropRequested
    ) public {
        uint256 tokensAmount = bridgeTokens.length;
        uint256 chainsAmount = dstChainIdsEVM.length;

        for (uint256 j = 0; j < chainsAmount; ++j) {
            uint256 chainId = dstChainIdsEVM[j];
            for (uint256 i = 0; i < tokensAmount; ++i) {
                address bridgeToken = bridgeTokens[i];
                _testBridgeSwapEVM(amountIn, indexFrom, bridgeToken, chainId, gasdropRequested);
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

    function _testDirectBridgeEVM(
        uint256 indexFrom,
        uint256 amount,
        uint256 chainId,
        bool gasdropRequested
    ) internal {
        address token = bridgeTokens[indexFrom % bridgeTokens.length];
        address dstToken = _getTokenDstAddress(token, chainId);

        _addTokenTo(token, user, amount);
        _BridgeOutState memory state = _saveTokenState(token, token, false);

        startHoax(user);
        IERC20(token).safeApprove(address(router), amount);

        vm.expectEmit(true, false, false, true);
        emit BridgedOutEVM(
            user,
            chainId,
            IERC20(token),
            amount,
            IERC20(dstToken),
            _getEmptySwapParams(dstToken),
            gasdropRequested
        );

        router.bridgeTokenToEVM(
            user,
            chainId,
            _getEmptySwapParams(token),
            amount,
            _getEmptySwapParams(dstToken),
            gasdropRequested
        );
        vm.stopPrank();

        _checkTokenState(token, token, amount, amount, state);
    }

    function _testDirectBridgeNonEVM(uint256 indexFrom, uint256 amount) internal {
        address token = bridgeTokens[indexFrom % bridgeTokens.length];
        uint256 chainId = _getTokenChainNonEVM(token);
        if (chainId == 0) return;

        bytes32 to = utils.addressToBytes32(user);
        string memory dstToken = tokenNames[token];

        _addTokenTo(token, user, amount);
        _BridgeOutState memory state = _saveTokenState(token, token, false);

        startHoax(user);
        IERC20(token).safeApprove(address(router), amount);

        vm.expectEmit(true, false, false, true);
        emit BridgedOutNonEVM(to, chainId, IERC20(token), amount, dstToken);

        router.bridgeTokenToNonEVM(to, chainId, _getEmptySwapParams(token), amount);
        vm.stopPrank();

        _checkTokenState(token, token, amount, amount, state);
    }

    struct _BridgeOutData {
        address tokenIn;
        address dstBridgeToken;
        Offers.FormattedOffer offer;
        IBridge.SwapParams swapParams;
        IBridge.SwapParams dstSwapParams;
        bool canUnderquote;
        uint256 amountOut;
    }

    function _testBridgeSwapEVM(
        uint256 amountIn,
        uint256 indexFrom,
        address bridgeToken,
        uint256 chainId,
        bool gasdropRequested
    ) internal {
        _BridgeOutData memory data;
        data.tokenIn = allTokens[indexFrom % allTokens.length];
        if (data.tokenIn == bridgeToken) return;
        amountIn = _getAdjustedAmount(data.tokenIn, amountIn);
        data.dstBridgeToken = _getTokenDstAddress(bridgeToken, chainId);

        data.offer = quoter.bestPathToBridge(data.tokenIn, amountIn, bridgeToken);
        if (data.offer.path.length == 0) return;

        data.swapParams = IBridge.SwapParams({
            minAmountOut: 0,
            path: data.offer.path,
            adapters: data.offer.adapters,
            deadline: block.timestamp
        });

        data.dstSwapParams = _getEmptySwapParams(data.dstBridgeToken);

        // Check if any of the adapters can give quote less than actual
        for (uint256 i = 0; i < data.offer.adapters.length; ++i) {
            if (canUnderquote[data.offer.adapters[i]]) {
                data.canUnderquote = true;
                break;
            }
        }

        _addTokenTo(data.tokenIn, user, amountIn);
        _BridgeOutState memory state = _saveTokenState(data.tokenIn, bridgeToken, false);

        startHoax(user);
        IERC20(data.tokenIn).safeApprove(address(router), amountIn);

        if (data.canUnderquote) {
            // Simulate bridging to get amountOut for event verification
            (bool success, bytes memory returnData) = address(router).staticcall(
                abi.encodeWithSelector(
                    router.bridgeTokenToEVM.selector,
                    user,
                    chainId,
                    data.swapParams,
                    amountIn,
                    data.dstSwapParams,
                    gasdropRequested
                )
            );
            assertTrue(success, "Router.bridgeTokenToEVM failed");
            data.amountOut = abi.decode(returnData, (uint256));
        } else {
            data.amountOut = data.offer.amounts[data.offer.amounts.length - 1];
        }

        vm.expectEmit(true, false, false, true);
        emit BridgedOutEVM(
            user,
            chainId,
            IERC20(bridgeToken),
            data.amountOut,
            IERC20(data.dstBridgeToken),
            data.dstSwapParams,
            gasdropRequested
        );

        router.bridgeTokenToEVM(user, chainId, data.swapParams, amountIn, data.dstSwapParams, gasdropRequested);
        vm.stopPrank();

        _checkTokenState(data.tokenIn, bridgeToken, amountIn, data.amountOut, state);
    }

    function _saveTokenState(
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

    function _checkTokenState(
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
        amountAdj = MIN_SWAP_AMOUNT + (amount % maxTokenAmount[token]);
    }

    function _addTokenTo(
        address token,
        address to,
        uint256 amount
    ) internal {
        if (token == basicTokens.wgas) {
            deal(address(this), amount);
            IWETH9(payable(token)).deposit{value: amount}();
        } else {
            // Do not update totalSupply for nUSD on Mainnet, as this screws pool calculations
            bool updateTotalSupply = (block.chainid != 1) || (token != basicTokens.nusd);
            deal(token, address(this), amount, updateTotalSupply);
        }
        IERC20(token).safeTransfer(to, amount);
    }

    function _getTokenChainNonEVM(address token) internal view returns (uint256 chainIdNonEVM) {
        (, , , , , , , , chainIdNonEVM, ) = bridgeConfig.tokenConfigs(token);
    }
}
