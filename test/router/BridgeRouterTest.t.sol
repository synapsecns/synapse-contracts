// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "../utils/DefaultBridgeTest.t.sol";

contract BridgeRouterTest is DefaultBridgeTest {
    /**
     * @notice Checks all functions with restricted access.
     */
    function testAccessControl() public {
        address _r = address(router);
        utils.checkAccessControl(
            _r,
            abi.encodeWithSelector(router.setBridgeMaxSwaps.selector, 0),
            router.GOVERNANCE_ROLE()
        );
        utils.checkAccess(
            _r,
            abi.encodeWithSelector(router.refundToAddress.selector, address(0), address(0), 0),
            "Caller is not Bridge"
        );
        Bridge.SwapParams memory swapParams;
        utils.checkAccess(
            _r,
            abi.encodeWithSelector(router.postBridgeSwap.selector, address(0), swapParams, 0),
            "Caller is not Bridge"
        );
    }

    /**
     * @notice Checks that governance can set bridgeMaxSwaps.
     */
    function testSetBridgeMaxSwaps() public {
        for (uint8 i = 1; i <= 4; ++i) {
            hoax(governance);
            router.setBridgeMaxSwaps(i);
            assertEq(router.bridgeMaxSwaps(), i, "Failed to set bridgeMaxSwaps");
        }
        utils.checkRevert(
            governance,
            address(router),
            abi.encodeWithSelector(router.setBridgeMaxSwaps.selector, 0),
            "Max swaps can't be 0"
        );
        utils.checkRevert(
            governance,
            address(router),
            abi.encodeWithSelector(router.setBridgeMaxSwaps.selector, 5),
            "Max swaps too big"
        );
    }

    // -- TEST: FAKE TOKENS

    /**
     * @notice Checks that bridging out unrecognized token to EVM-chain fails.
     */
    function testBridgeOutFakeTokenToEVM() public {
        IERC20 fake = _deployERC20("FAKE");
        uint256 amount = 10**18;
        _dealToken(fake, user, amount);

        hoax(user);
        fake.approve(address(router), amount);

        IBridge.SwapParams memory swapParams = _constructEmptySwapParams(address(fake));
        swapParams.deadline = MAX_UINT;

        utils.checkRevert(
            user,
            address(router),
            abi.encodeWithSelector(
                router.bridgeTokenToEVM.selector,
                user,
                ID_EVM,
                swapParams,
                amount,
                swapParams,
                false
            ),
            "!token"
        );
    }

    /**
     * @notice Checks that bridging out unrecognized token to non-EVM chain fails.
     */
    function testBridgeOutFakeTokenToNonEVM() public {
        bytes32 to = keccak256(abi.encode(user));
        IERC20 fake = _deployERC20("FAKE");
        uint256 amount = 10**18;
        _dealToken(fake, user, amount);

        hoax(user);
        fake.approve(address(router), amount);

        IBridge.SwapParams memory swapParams = _constructEmptySwapParams(address(fake));
        swapParams.deadline = MAX_UINT;

        utils.checkRevert(
            user,
            address(router),
            abi.encodeWithSelector(router.bridgeTokenToNonEVM.selector, to, ID_NON_EVM, swapParams, amount),
            "!token"
        );
    }

    /**
     * @notice Checks that bridging in nUSD, but requesting nETH -> wETH swap
     * leads to attacker receiving bridged nUSD.
     */
    function testBridgeInFakeSwap() public {
        uint256 amount = 10**20;

        IBridge.SwapParams memory swapParams;
        swapParams.path = new address[](2);
        swapParams.path[0] = address(_tokens.nETH);
        swapParams.path[1] = address(_tokens.wETH);
        swapParams.adapters = new address[](1);
        swapParams.adapters[0] = address(_adapters.nETHAdapter);
        swapParams.deadline = MAX_UINT;

        bytes32 kappa = utils.getNextKappa();

        uint256 userPre = _tokens.nUSD.balanceOf(attacker);

        (uint256 fee, , , ) = bridgeConfig.calculateBridgeFee(
            address(_tokens.nUSD),
            amount,
            false,
            swapParams.adapters.length
        );

        hoax(node);
        bridge.bridgeInEVM(attacker, _tokens.nUSD, amount, swapParams, false, kappa);

        assertEq(_tokens.nUSD.balanceOf(attacker) - userPre, amount - fee, "Attacker managed to receive not nUSD");
    }

    // -- TEST: BRIDGE TO EVM

    /**
     * @notice Checks that bridging a token to EVM chain w/o swap on src chain
     * works as intended.
     */
    function testBridgeOutTokenNoSwapToEVM(uint8 _indexTo, uint64 _amountIn) public {
        vm.assume(_amountIn > 0);
        uint256 amountIn = uint256(_amountIn) << 20;

        (address bridgeToken, ) = _getBridgeToken(_indexTo);
        IBridge.SwapParams memory srcSwapParams = _constructEmptySwapParams(bridgeToken);
        IBridge.SwapParams memory dstSwapParams = _constructDestinationSwapParams(bridgeToken);

        srcSwapParams.deadline = block.timestamp;

        _checkBridgeTokenToEVM(
            IERC20(bridgeToken),
            amountIn,
            IERC20(bridgeToken),
            amountIn,
            srcSwapParams,
            dstSwapParams
        );
    }

    /**
     * @notice Checks that bridging a token to EVM chain with a swap on src chain
     * works as intended.
     */
    function testBridgeOutTokenToEVM(
        uint8 indexFrom,
        uint8 _indexTo,
        uint64 _amountIn
    ) public {
        (address bridgeToken, uint8 indexTo) = _getBridgeToken(_indexTo);
        (Offers.FormattedOffer memory offer, uint256 amountIn, uint256 amountOut) = _askQuoter(
            _config.maxSwaps,
            indexFrom,
            indexTo,
            _amountIn
        );
        (IBridge.SwapParams memory srcSwapParams, IBridge.SwapParams memory dstSwapParams) = _getSwapParams(
            bridgeToken,
            offer
        );

        _checkBridgeTokenToEVM(
            IERC20(allTokens[indexFrom]),
            amountIn,
            IERC20(bridgeToken),
            amountOut,
            srcSwapParams,
            dstSwapParams
        );
    }

    /**
     * @notice Submits a bridge out transaction to EVM chain.
     * Checks that the correct event is emitted.
     */
    function _checkBridgeTokenToEVM(
        IERC20 tokenFrom,
        uint256 amountIn,
        IERC20 bridgeToken,
        uint256 amountOut,
        IBridge.SwapParams memory srcSwapParams,
        IBridge.SwapParams memory dstSwapParams
    ) internal {
        _dealToken(tokenFrom, user, amountIn);
        startHoax(user);
        tokenFrom.approve(address(router), amountIn);

        vm.expectEmit(true, false, false, true);
        emit BridgedOutEVM(
            user,
            ID_EVM,
            bridgeToken,
            amountOut,
            IERC20(tokenAddressEVM[address(bridgeToken)]),
            dstSwapParams,
            false
        );
        router.bridgeTokenToEVM(user, ID_EVM, srcSwapParams, amountIn, dstSwapParams, false);
        vm.stopPrank();
    }

    /**
     * @notice Checks that bridging GAS to EVM chain with a swap on src chain
     * works as intended. Checks that the correct event is emitted.
     */
    function testBridgeOutGasToEVM(uint8 _indexTo, uint64 _amountIn) public {
        uint8 indexFrom = WETH_INDEX;
        (address bridgeToken, uint8 indexTo) = _getBridgeToken(_indexTo);
        (Offers.FormattedOffer memory offer, uint256 amountIn, uint256 amountOut) = _askQuoter(
            _config.maxSwaps,
            indexFrom,
            indexTo,
            _amountIn
        );
        (IBridge.SwapParams memory srcSwapParams, IBridge.SwapParams memory dstSwapParams) = _getSwapParams(
            bridgeToken,
            offer
        );

        deal(user, amountIn);

        vm.expectEmit(true, false, false, true);
        emit BridgedOutEVM(
            user,
            ID_EVM,
            IERC20(bridgeToken),
            amountOut,
            IERC20(tokenAddressEVM[bridgeToken]),
            dstSwapParams,
            false
        );

        hoax(user);
        router.bridgeGasToEVM{value: amountIn}(user, ID_EVM, srcSwapParams, dstSwapParams, false);
    }

    // -- TEST: BRIDGE TO NON-EVM

    /**
     * @notice Checks that bridging a token to non-EVM chain w/o swap on src chain
     * works as intended.
     */
    function testBridgeOutTokenNoSwapToNonEVM(uint8 _indexTo, uint64 _amountIn) public {
        vm.assume(_amountIn > 0);
        uint256 amountIn = uint256(_amountIn) << 20;

        bytes32 to = keccak256(abi.encode(user));
        (address bridgeToken, ) = _getBridgeToken(_indexTo);
        IBridge.SwapParams memory srcSwapParams = _constructEmptySwapParams(bridgeToken);
        srcSwapParams.deadline = block.timestamp;

        _checkBridgeTokenToNonEVM(to, IERC20(bridgeToken), amountIn, IERC20(bridgeToken), amountIn, srcSwapParams);
    }

    /**
     * @notice Checks that bridging a token to non-EVM chain with swap on src chain
     * works as intended.
     */
    function testBridgeOutTokenToNonEVM(
        uint8 indexFrom,
        uint8 _indexTo,
        uint64 _amountIn
    ) public {
        bytes32 to = keccak256(abi.encode(user));
        (address bridgeToken, uint8 indexTo) = _getBridgeToken(_indexTo);
        (Offers.FormattedOffer memory offer, uint256 amountIn, uint256 amountOut) = _askQuoter(
            _config.maxSwaps,
            indexFrom,
            indexTo,
            _amountIn
        );
        (IBridge.SwapParams memory srcSwapParams, ) = _getSwapParams(bridgeToken, offer);

        _checkBridgeTokenToNonEVM(
            to,
            IERC20(allTokens[indexFrom]),
            amountIn,
            IERC20(bridgeToken),
            amountOut,
            srcSwapParams
        );
    }

    /**
     * @notice Submits a bridge out transaction to EVM chain.
     * Checks that the correct event is emitted.
     */
    function _checkBridgeTokenToNonEVM(
        bytes32 to,
        IERC20 tokenFrom,
        uint256 amountIn,
        IERC20 bridgeToken,
        uint256 amountOut,
        IBridge.SwapParams memory srcSwapParams
    ) internal {
        _dealToken(tokenFrom, user, amountIn);
        startHoax(user);
        tokenFrom.approve(address(router), amountIn);

        vm.expectEmit(true, false, false, true);
        emit BridgedOutNonEVM(to, ID_NON_EVM, bridgeToken, amountOut, tokenAddressNonEVM[address(bridgeToken)]);

        router.bridgeTokenToNonEVM(to, ID_NON_EVM, srcSwapParams, amountIn);
        vm.stopPrank();
    }

    /**
     * @notice Checks that bridging GAS to EVM chain with a swap on src chain
     * works as intended. Checks that the correct event is emitted.
     */
    function testBridgeOutGasToNonEVM(uint8 _indexTo, uint64 _amountIn) public {
        uint8 indexFrom = WETH_INDEX;
        bytes32 to = keccak256(abi.encode(user));
        (address bridgeToken, uint8 indexTo) = _getBridgeToken(_indexTo);
        (Offers.FormattedOffer memory offer, uint256 amountIn, uint256 amountOut) = _askQuoter(
            _config.maxSwaps,
            indexFrom,
            indexTo,
            _amountIn
        );
        (IBridge.SwapParams memory srcSwapParams, ) = _getSwapParams(bridgeToken, offer);

        deal(user, amountIn);

        vm.expectEmit(true, false, false, true);
        emit BridgedOutNonEVM(to, ID_NON_EVM, IERC20(bridgeToken), amountOut, tokenAddressNonEVM[bridgeToken]);

        hoax(user);
        router.bridgeGasToNonEVM{value: amountIn}(to, ID_NON_EVM, srcSwapParams);
    }

    // -- TEST: BRIDGE IN & SWAP

    /**
     * @notice Checks that bridge in transaction with swap works as intended.
     * Checks that the correct fee was applied and correct event was emitted.
     */
    function testBridgeInWithSwap(
        uint8 _indexFrom,
        uint8 indexTo,
        uint64 _amountIn,
        bool gasdropRequested
    ) public {
        _TestData memory data = _getParamsForBridgeSwap(_indexFrom, indexTo, _amountIn, gasdropRequested);

        vm.expectEmit(true, true, false, true);
        emit TokenBridgedIn(
            user,
            IERC20(data.bridgeToken),
            data.amountIn,
            data.bridgeFee,
            IERC20(allTokens[indexTo]),
            data.amountOut,
            data.gasdropAmount,
            data.kappa
        );

        hoax(node);
        bridge.bridgeInEVM(
            user,
            IERC20(data.bridgeToken),
            data.amountIn,
            data.swapParams,
            gasdropRequested,
            data.kappa
        );

        _checkPostBridgeIn(indexTo, data);
    }

    /**
     * @notice Checks that bridge in transaction with swap, that has
     * too big minAmountOut, results in user receiving bridged tokens (instead of requested).
     * Checks that the correct fee was applied and correct event was emitted.
     */
    function testBridgeInSwapFailed(
        uint8 _indexFrom,
        uint8 indexTo,
        uint64 _amountIn,
        bool gasdropRequested
    ) public {
        _TestData memory data = _getParamsForBridgeSwap(_indexFrom, indexTo, _amountIn, gasdropRequested);
        // this should get swap failed
        data.swapParams.minAmountOut = data.amountOut + 1;

        _checkBridgeInDirectEVM(data, gasdropRequested, _config.bridgeMaxSwaps);
    }

    /**
     * @notice Checks that bridge in transaction with swap, that has
     * deadline failed, results in user receiving bridged tokens (instead of requested).
     * Checks that the correct fee was applied (deadline fail leads to lower minFee) and correct event was emitted.
     */
    function testBridgeInDeadlineFailed(
        uint8 _indexFrom,
        uint8 indexTo,
        uint64 _amountIn,
        bool gasdropRequested
    ) public {
        _TestData memory data = _getParamsForBridgeSwap(_indexFrom, indexTo, _amountIn, gasdropRequested);
        // this should get swap failed
        --data.swapParams.deadline;

        // Deadline check is failed => 0 swaps is used for fee calculation
        _checkBridgeInDirectEVM(data, gasdropRequested, 0);
    }

    /**
     * @notice Checks that bridge in transaction with no swap works as intended.
     * Checks that the correct fee was applied and correct event was emitted.
     */
    function testBridgeInNoSwap(
        uint8 _indexTo,
        uint64 _amountIn,
        bool gasdropRequested
    ) public {
        vm.assume(_indexTo < bridgeTokens.length);
        vm.assume(_amountIn > 0);
        _TestData memory data;

        (data.bridgeToken, data.indexFrom) = _getBridgeToken(_indexTo);
        data.gasdropAmount = _setupGasDrop(gasdropRequested);
        data.swapParams = _constructEmptySwapParams(data.bridgeToken);

        // use at least minTotalFee: (1)*minFee w/o gasDrop, (1+2)*minFee w/ gasDrop
        data.amountIn = _getMinFee(data.bridgeToken) * (gasdropRequested ? 3 : 1) + _amountIn + 1;
        data.gasPre = user.balance;

        // Direct bridging => 0 swaps
        _checkBridgeInDirectEVM(data, gasdropRequested, 0);
    }

    /**
     * @notice Submits a bridge in tx and checks all invariants.
     */
    function _checkBridgeInDirectEVM(
        _TestData memory data,
        bool gasdropRequested,
        uint256 amountOfSwaps
    ) public {
        // store user amount of bridge token
        data.tokenPre = IERC20(data.bridgeToken).balanceOf(user);
        (data.bridgeFee, , , ) = bridgeConfig.calculateBridgeFee(
            data.bridgeToken,
            data.amountIn,
            gasdropRequested,
            amountOfSwaps
        );
        data.amountOut = data.amountIn - data.bridgeFee;

        vm.expectEmit(true, true, false, true);
        emit TokenBridgedIn(
            user,
            IERC20(data.bridgeToken),
            data.amountIn,
            data.bridgeFee,
            IERC20(data.bridgeToken),
            data.amountOut,
            data.gasdropAmount,
            data.kappa
        );

        hoax(node);
        bridge.bridgeInEVM(
            user,
            IERC20(data.bridgeToken),
            data.amountIn,
            data.swapParams,
            gasdropRequested,
            data.kappa
        );

        _checkPostBridgeIn(data.indexFrom, data);
    }

    struct _TestData {
        uint256 gasdropAmount;
        bytes32 kappa;
        address bridgeToken;
        uint8 indexFrom;
        uint256 amountIn;
        uint256 bridgeFee;
        uint256 amountOut;
        IBridge.SwapParams swapParams;
        uint256 tokenPre;
        uint256 gasPre;
    }

    /**
     * @notice Constructs parameters for a test berdige in transaction.
     */
    function _getParamsForBridgeSwap(
        uint8 _indexFrom,
        uint8 indexTo,
        uint64 _amountIn,
        bool gasdropRequested
    ) internal returns (_TestData memory data) {
        vm.assume(_indexFrom < bridgeTokens.length);
        vm.assume(indexTo < allTokens.length);
        (data.bridgeToken, data.indexFrom) = _getBridgeToken(_indexFrom);
        vm.assume(data.indexFrom != indexTo);

        data.gasdropAmount = _setupGasDrop(gasdropRequested);

        // use at least minTotalFee: (1+4)*minFee w/o gasDrop, (1+2+4)*minFee w/ gasDrop
        data.amountIn = _getMinFee(data.bridgeToken) * (gasdropRequested ? 7 : 5) + _amountIn + 1;
        (data.bridgeFee, , , ) = bridgeConfig.calculateBridgeFee(
            data.bridgeToken,
            data.amountIn,
            gasdropRequested,
            _config.bridgeMaxSwaps
        );
        Offers.FormattedOffer memory offer = quoter.bestPathFromBridge(
            data.bridgeToken,
            data.amountIn,
            allTokens[indexTo],
            gasdropRequested
        );

        vm.assume(offer.path.length > 0);
        data.amountOut = offer.amounts[offer.amounts.length - 1];

        data.kappa = utils.getNextKappa();
        (data.swapParams, ) = _getSwapParams(data.bridgeToken, offer);

        data.tokenPre = IERC20(allTokens[indexTo]).balanceOf(user);
        data.gasPre = user.balance;
    }

    /**
     * @notice Checks invariants post bridge in transaction.
     * User token and gas balance is checked.
     */
    function _checkPostBridgeIn(uint8 indexTo, _TestData memory data) internal {
        emit log_uint(indexTo);
        if (indexTo == WETH_INDEX) {
            assertEq(user.balance - data.gasPre, data.amountOut + data.gasdropAmount, "WETH bridging incomplete");
        } else {
            assertEq(
                IERC20(allTokens[indexTo]).balanceOf(user) - data.tokenPre,
                data.amountOut,
                "Token bridging incomplete"
            );
            assertEq(user.balance - data.gasPre, data.gasdropAmount, "Gas airdrop incomplete");
        }
    }

    /**
     * @notice Finds a test bridge token, and returns its index in allTokens array.
     */
    function _getBridgeToken(uint8 _indexTo) internal returns (address bridgeToken, uint8 indexTo) {
        vm.assume(_indexTo < bridgeTokens.length);
        bridgeToken = bridgeTokens[_indexTo];

        indexTo = tokenIndexes[bridgeToken];
        require(indexTo > 0, "Unknown token found");
        --indexTo;
    }

    /**
     * @notice Constructs swapParams for src (from offer) and dst (empty swap) chain
     */
    function _getSwapParams(address bridgeToken, Offers.FormattedOffer memory offer)
        internal
        view
        returns (IBridge.SwapParams memory srcSwapParams, IBridge.SwapParams memory dstSwapParams)
    {
        srcSwapParams = IBridge.SwapParams({
            minAmountOut: 0,
            path: offer.path,
            adapters: offer.adapters,
            deadline: block.timestamp
        });
        dstSwapParams = _constructDestinationSwapParams(bridgeToken);
    }

    /**
     * @notice Sets up GasDrop and returns amount of GAS user will receive,
     */
    function _setupGasDrop(bool gasdropRequested) internal returns (uint256 gasdropAmount) {
        if (gasdropRequested) {
            gasdropAmount = TEST_AMOUNT;

            hoax(governance);
            vault.setChainGasAmount(gasdropAmount);
            deal(address(vault), 1000 * gasdropAmount);
        }
    }
}
