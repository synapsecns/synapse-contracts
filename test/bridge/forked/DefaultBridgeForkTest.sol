// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "forge-std/Test.sol";
import {Utilities} from "../../utils/Utilities.sol";

import {IBridge} from "../interfaces/IBridge.sol";
import {ISwap} from "../interfaces/ISwap.sol";
import {BridgeEvents} from "../interfaces/BridgeEvents.sol";

import {ERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/IERC20.sol";

// solhint-disable func-name-mixedcase
// solhint-disable not-rely-on-time

abstract contract DefaultBridgeForkTest is Test, BridgeEvents {
    using stdStorage for StdStorage;

    struct BridgeTestSetup {
        address bridge;
        address wgas;
        address tokenMint;
        address tokenWithdraw;
    }

    struct Snapshot {
        uint256 bridgeTokenFees;
        uint256 userGasBalance;
        uint256 userTokenBalance;
    }

    // every public getter (including constants cause I'm paranoid)
    struct BridgeState {
        bytes32 nodeGroupRole;
        bytes32 governanceRole;
        uint256 startBlockNumber;
        uint256 chainGasAmount;
        address payable wethAddress;
    }

    IBridge internal bridge;
    uint256 internal gasAirdropAmount;

    // nUSD should be added first
    ISwap[] internal swaps;
    IERC20[] internal bridgeTokens;
    mapping(ISwap => IERC20[]) internal swapTokensMap;

    // nUSD and nETH behave differently on Mainnet
    bool internal immutable isMainnet;
    // Whether WGAS is deposited/withdrawn from the Bridge
    bool internal immutable isGasWithdrawable;

    // for testing withdraw() into native gas on applicable chains
    IERC20 internal wgas;
    // for testing mint() on applicable chains
    IERC20 internal tokenMint;
    // for testing withdraw() on applicable chains
    IERC20 internal tokenWithdraw;

    // state of bridge pre-upgrade
    BridgeState private bridgeState;
    bytes32[4] private existingKappas;
    uint256[] private tokenFees;

    Utilities internal utils;
    bytes32 private nextKappa;

    // common test values
    uint256 internal constant AMOUNT = 10**18;
    uint256 internal constant FEE = 10**17;
    uint256 internal constant AMOUNT_FULL = AMOUNT + FEE;

    address internal constant USER = address(1337420);
    address internal constant NODE = 0x230A1AC45690B9Ae1176389434610B9526d2f21b;

    address internal constant ZERO = address(0);
    IERC20 internal constant NULL = IERC20(ZERO);

    // TODO: turn these tests on once swap/withdraw fix is patched
    bool private constant WRONG_INDEX_TEST_ENABLED = false;

    constructor(
        bool _isMainnet,
        bool _isGasWithdrawable,
        BridgeTestSetup memory _setup,
        bytes32[4] memory _kappas
    ) {
        isMainnet = _isMainnet;
        isGasWithdrawable = _isGasWithdrawable;

        bridge = IBridge(_setup.bridge);
        wgas = IERC20(_setup.wgas);
        tokenMint = IERC20(_setup.tokenMint);
        tokenWithdraw = IERC20(_setup.tokenWithdraw);

        existingKappas = _kappas;

        gasAirdropAmount = bridge.chainGasAmount();
        nextKappa = keccak256("very real so genuine wow");
    }

    function setUp() public {
        utils = new Utilities();
        _initSwapArrays();
        _saveBridgeState();
        address bridgeImpl = deployCode("artifacts/SynapseBridge.sol/SynapseBridge.json");
        utils.upgradeTo(address(bridge), bridgeImpl);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                        TESTS: ENABLE AIRDROP                         ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function test_enableAirdrop() public {
        if (_checkEnableAirdropTestSkipped()) return;
        gasAirdropAmount = AMOUNT / 10;
        _setAirdropAmount();
        deal(address(bridge), 10 * AMOUNT);

        test_mint();
        test_mintAndSwap();
        test_withdraw();
        test_withdraw_gas();
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                        TESTS: BRIDGE W/O SWAP                        ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function test_mint() public {
        if (_checkSimpleTestSkipped(tokenMint)) return;
        _test_simple(tokenMint, true);
    }

    function test_withdraw() public {
        if (_checkSimpleTestSkipped(tokenWithdraw)) return;
        _test_simple(tokenWithdraw, false);
    }

    function test_withdraw_gas() public {
        if (_checkSimpleTestSkipped(isGasWithdrawable ? wgas : NULL)) return;
        _test_simple(wgas, false);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                       TESTS: BRIDGE WITH SWAP                        ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function test_mintAndSwap() public {
        if (_checkSwapTestSkipped()) return;
        for (uint256 i = 0; i < swaps.length; ++i) {
            _test_swap(bridgeTokens[i], swaps[i], 0, 0);
        }
    }

    function test_mintAndSwap_amountOutTooLow() public {
        if (_checkSwapTestSkipped()) return;
        for (uint256 i = 0; i < swaps.length; ++i) {
            _test_swap(bridgeTokens[i], swaps[i], type(uint256).max, type(uint256).max);
        }
    }

    function test_mintAndSwap_deadlineFailed() public {
        if (_checkSwapTestSkipped()) return;
        for (uint256 i = 0; i < swaps.length; ++i) {
            _test_swap(bridgeTokens[i], swaps[i], 0, block.timestamp - 1);
        }
    }

    function test_mintAndSwap_wrongIndices() public {
        if (_checkSwapTestSkipped()) return;
        if (_checkWrongIndexTestSkipped()) return;
        for (uint256 i = 0; i < swaps.length; ++i) {
            _test_mintAndSwap(bridgeTokens[i], bridgeTokens[i], swaps[i], 0, 0, 0, type(uint256).max, 0, AMOUNT, false);
        }
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                      TESTS: BRIDGE WITH REMOVE                       ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function test_withdrawAndRemove() public {
        if (_checkRemoveTestSkipped()) return;
        _test_remove(bridgeTokens[0], swaps[0], 0, 0);
    }

    function test_withdrawAndRemove_amountOutTooLow() public {
        if (_checkRemoveTestSkipped()) return;
        _test_remove(bridgeTokens[0], swaps[0], type(uint256).max, type(uint256).max);
    }

    function test_withdrawAndRemove_deadlineFailed() public {
        if (_checkRemoveTestSkipped()) return;
        _test_remove(bridgeTokens[0], swaps[0], 0, block.timestamp - 1);
    }

    function test_withdrawAndRemove_wrongIndex() public {
        if (_checkRemoveTestSkipped()) return;
        if (_checkWrongIndexTestSkipped()) return;
        _test_withdrawAndRemove(
            bridgeTokens[0],
            bridgeTokens[0],
            swaps[0],
            uint8(swapTokensMap[swaps[0]].length),
            0,
            type(uint256).max,
            AMOUNT,
            false
        );
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                            TESTS: UPGRADE                            ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function test_upgrade() public {
        assertEq(bridge.NODEGROUP_ROLE(), bridgeState.nodeGroupRole, "NODEGROUP_ROLE rekt post-upgrade");
        assertEq(bridge.GOVERNANCE_ROLE(), bridgeState.governanceRole, "GOVERNANCE_ROLE rekt post-upgrade");
        assertEq(bridge.startBlockNumber(), bridgeState.startBlockNumber, "startBlockNumber rekt post-upgrade");
        assertEq(bridge.chainGasAmount(), bridgeState.chainGasAmount, "chainGasAmount rekt post-upgrade");
        assertEq(bridge.WETH_ADDRESS(), bridgeState.wethAddress, "WETH_ADDRESS rekt post-upgrade");

        for (uint256 i = 0; i < bridgeTokens.length; ++i) {
            assertEq(bridge.getFeeBalance(bridgeTokens[i]), tokenFees[i], "fees rekt post-upgrade");
        }

        for (uint256 i = 0; i < existingKappas.length; ++i) {
            assertTrue(bridge.kappaExists(existingKappas[i]), "Kappa is missing post-upgrade");
        }

        assertEq(bridge.bridgeVersion(), 7, "Bridge version not bumped");
    }

    function _saveBridgeState() private {
        BridgeState memory state;
        state.nodeGroupRole = bridge.NODEGROUP_ROLE();
        state.governanceRole = bridge.GOVERNANCE_ROLE();
        state.startBlockNumber = bridge.startBlockNumber();
        state.chainGasAmount = bridge.chainGasAmount();
        state.wethAddress = bridge.WETH_ADDRESS();

        for (uint256 i = 0; i < bridgeTokens.length; ++i) {
            tokenFees.push(bridge.getFeeBalance(bridgeTokens[i]));
        }

        for (uint256 i = 0; i < existingKappas.length; ++i) {
            _assertKappa(existingKappas[i]);
        }

        bridgeState = state;
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                     INTERNAL FUNCTIONS: BRIDGING                     ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function _assertKappa(bytes32 kappa) internal view {
        assert(bridge.kappaExists(kappa));
    }

    function _nextKappa() internal returns (bytes32 kappa) {
        kappa = nextKappa;
        nextKappa = keccak256(abi.encode(kappa));
    }

    function _makeSnapshot(IERC20 _bridgeToken, IERC20 _testToken) internal view returns (Snapshot memory snapshot) {
        snapshot.bridgeTokenFees = bridge.getFeeBalance(_bridgeToken);
        snapshot.userGasBalance = USER.balance;
        // skip in case received asset is gas
        if (address(_testToken) != ZERO) snapshot.userTokenBalance = _testToken.balanceOf(USER);
    }

    function _checkSnapshots(
        Snapshot memory _pre,
        Snapshot memory _post,
        uint256 _expectedGas,
        uint256 _expectedToken
    ) internal {
        _expectedGas += gasAirdropAmount;
        require(_post.bridgeTokenFees >= _pre.bridgeTokenFees, "WTF: fees reduced");
        assertEq(_post.bridgeTokenFees - _pre.bridgeTokenFees, FEE, "Incorrect bridgeFee");

        require(_post.userGasBalance >= _pre.userGasBalance, "WFT: user gas balance reduced");
        assertEq(_post.userGasBalance - _pre.userGasBalance, _expectedGas, "Incorrect amount of gas received");

        require(_post.userTokenBalance >= _pre.userTokenBalance, "WFT: user token balance reduced");
        assertEq(_post.userTokenBalance - _pre.userTokenBalance, _expectedToken, "Incorrect amount of tokens received");
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                     TEST IMPLEMENTATION: NO SWAP                     ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function _test_simple(IERC20 _bridgeToken, bool _isMint) internal {
        _logSimpleTest(_bridgeToken);
        bytes32 kappa = _nextKappa();
        IERC20 receivedToken = address(_bridgeToken) == address(wgas) ? NULL : _bridgeToken;
        Snapshot memory pre = _makeSnapshot(_bridgeToken, receivedToken);
        vm.expectEmit(true, true, true, true);
        vm.prank(NODE);
        if (_isMint) {
            emit TokenMint(USER, _bridgeToken, AMOUNT, FEE, kappa);
            bridge.mint(USER, _bridgeToken, AMOUNT_FULL, FEE, kappa);
        } else {
            emit TokenWithdraw(USER, _bridgeToken, AMOUNT, FEE, kappa);
            bridge.withdraw(USER, _bridgeToken, AMOUNT_FULL, FEE, kappa);
        }

        Snapshot memory post = _makeSnapshot(_bridgeToken, receivedToken);
        if (receivedToken == NULL) {
            _checkSnapshots(pre, post, AMOUNT, 0);
        } else {
            _checkSnapshots(pre, post, 0, AMOUNT);
        }
        _assertKappa(kappa);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                      TEST IMPLEMENTATION: SWAP                       ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function _test_swap(
        IERC20 _bridgeToken,
        ISwap _swap,
        uint256 _adjustedQuote,
        uint256 _adjustedTimestamp
    ) internal {
        bool isFailed = _adjustedQuote != 0 || _adjustedTimestamp != 0;
        uint8 indexFrom = _findToken(_swap, _bridgeToken);
        IERC20[] memory poolTokens = swapTokensMap[_swap];
        for (uint8 indexTo = 0; indexTo < poolTokens.length; ++indexTo) {
            if (indexFrom == indexTo) continue;
            if (isFailed) {
                _test_mintAndSwap(
                    _bridgeToken,
                    _bridgeToken,
                    _swap,
                    indexFrom,
                    indexTo,
                    _adjustedQuote,
                    _adjustedTimestamp,
                    0,
                    AMOUNT,
                    false
                );
            } else {
                _logSwapTest(_swap, indexFrom, indexTo);
                uint256 quote = _swap.calculateSwap(indexFrom, indexTo, AMOUNT);
                IERC20 receivedToken = poolTokens[indexTo];
                (uint256 expectedGas, uint256 expectedToken) = address(receivedToken) == address(wgas)
                    ? (quote, uint256(0))
                    : (uint256(0), quote);
                _test_mintAndSwap(
                    _bridgeToken,
                    receivedToken,
                    _swap,
                    indexFrom,
                    indexTo,
                    quote,
                    block.timestamp,
                    expectedGas,
                    expectedToken,
                    true
                );
            }
        }
    }

    function _test_mintAndSwap(
        IERC20 bridgeToken,
        IERC20 receivedToken,
        ISwap pool,
        uint8 indexFrom,
        uint8 indexTo,
        uint256 quote,
        uint256 deadline,
        uint256 expectedGas,
        uint256 expectedToken,
        bool swapSuccess
    ) internal {
        bytes32 kappa = _nextKappa();
        Snapshot memory pre = _makeSnapshot(bridgeToken, receivedToken);
        vm.expectEmit(true, true, true, true);
        emit TokenMintAndSwap(
            USER,
            bridgeToken,
            expectedGas + expectedToken,
            FEE,
            indexFrom,
            indexTo,
            quote,
            deadline,
            swapSuccess,
            kappa
        );
        vm.prank(NODE);
        bridge.mintAndSwap(USER, bridgeToken, AMOUNT_FULL, FEE, pool, indexFrom, indexTo, quote, deadline, kappa);
        Snapshot memory post = _makeSnapshot(bridgeToken, receivedToken);
        _checkSnapshots(pre, post, expectedGas, expectedToken);
        _assertKappa(kappa);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                     TEST IMPLEMENTATION: REMOVE                      ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function _test_remove(
        IERC20 _bridgeToken,
        ISwap _swap,
        uint256 _adjustedQuote,
        uint256 _adjustedTimestamp
    ) internal {
        bool isFailed = _adjustedQuote != 0 || _adjustedTimestamp != 0;
        IERC20[] memory poolTokens = swapTokensMap[_swap];
        for (uint8 indexTo = 0; indexTo < poolTokens.length; ++indexTo) {
            if (!isFailed) _logRemoveTest(_bridgeToken, _swap, indexTo);
            uint256 quote = _swap.calculateRemoveLiquidityOneToken(AMOUNT, indexTo);
            _test_withdrawAndRemove(
                _bridgeToken,
                isFailed ? _bridgeToken : poolTokens[indexTo],
                _swap,
                indexTo,
                isFailed ? _adjustedQuote : quote,
                isFailed ? _adjustedTimestamp : block.timestamp,
                isFailed ? AMOUNT : quote,
                !isFailed
            );
        }
    }

    function _test_withdrawAndRemove(
        IERC20 _bridgeToken,
        IERC20 _receivedToken,
        ISwap _swap,
        uint8 _indexTo,
        uint256 _quote,
        uint256 _deadline,
        uint256 _expectedToken,
        bool _swapSuccess
    ) internal {
        bytes32 kappa = _nextKappa();
        Snapshot memory pre = _makeSnapshot(_bridgeToken, _receivedToken);
        vm.expectEmit(true, true, true, true);
        emit TokenWithdrawAndRemove(
            USER,
            _bridgeToken,
            _expectedToken,
            FEE,
            _indexTo,
            _quote,
            _deadline,
            _swapSuccess,
            kappa
        );
        vm.prank(NODE);
        bridge.withdrawAndRemove(USER, _bridgeToken, AMOUNT_FULL, FEE, _swap, _indexTo, _quote, _deadline, kappa);
        Snapshot memory post = _makeSnapshot(_bridgeToken, _receivedToken);
        _checkSnapshots(pre, post, 0, _expectedToken);
        _assertKappa(kappa);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                          INTERNAL FUNCTIONS                          ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function _addTokenPool(address _bridgeToken, address _swap) internal {
        ISwap swap = ISwap(_swap);

        bridgeTokens.push(IERC20(_bridgeToken));
        swaps.push(swap);

        bool bridgeTokenFound = false;

        for (uint8 index = 0; ; ++index) {
            try swap.getToken(index) returns (IERC20 token) {
                swapTokensMap[swap].push(token);
                if (address(token) == _bridgeToken) bridgeTokenFound = true;
            } catch {
                break;
            }
        }

        // nUSD is not in Nexus pool on Ethereum
        require(isMainnet || bridgeTokenFound, "!bridge token");
    }

    function _getSymbol(IERC20 _token) internal view returns (string memory) {
        return ERC20(address(_token)).symbol();
    }

    function _findToken(ISwap _swap, IERC20 _token) internal view returns (uint8 tokenIndex) {
        for (uint8 index = 0; ; ++index) {
            try _swap.getToken(index) returns (IERC20 token) {
                if (address(token) == address(_token)) {
                    return index;
                }
            } catch {
                break;
            }
        }
        revert("Token not found");
    }

    function _logSwap(IERC20 _tokenFrom, IERC20 _tokenTo) internal {
        emit log_string(string.concat(_getSymbol(_tokenFrom), " -> ", _getSymbol(_tokenTo)));
    }

    function _logSimpleTest(IERC20 _token) internal {
        emit log_string(string.concat("Bridging ", _getSymbol(_token)));
    }

    function _logSwapTest(
        ISwap _swap,
        uint8 _indexFrom,
        uint8 _indexTo
    ) internal {
        IERC20 tokenFrom = swapTokensMap[_swap][_indexFrom];
        IERC20 tokenTo = swapTokensMap[_swap][_indexTo];
        _logSwap(tokenFrom, tokenTo);
    }

    function _logRemoveTest(
        IERC20 _bridgeToken,
        ISwap _swap,
        uint8 _indexTo
    ) internal {
        IERC20 tokenTo = swapTokensMap[_swap][_indexTo];
        _logSwap(_bridgeToken, tokenTo);
    }

    function _setAirdropAmount() internal {
        stdstore.target(address(bridge)).sig(IBridge.chainGasAmount.selector).checked_write(gasAirdropAmount);
        require(bridge.chainGasAmount() == gasAirdropAmount, "Failed to set gas airdrop");
    }

    function _setWethAddress(address _admin) internal {
        vm.prank(_admin);
        bridge.setWethAddress(payable(address(wgas)));
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                        SKIPPED TESTS CHECKERS                        ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function _checkEnableAirdropTestSkipped() internal returns (bool skipped) {
        if (gasAirdropAmount != 0) {
            emit log_string("Skipping: airdrop already enabled");
            skipped = true;
        } else if (isMainnet) {
            emit log_string("Skipping: no airdrop on mainnet");
            skipped = true;
        }
    }

    function _checkSimpleTestSkipped(IERC20 _token) internal returns (bool skipped) {
        if (address(_token) == ZERO) {
            emit log_string(string.concat("Skipping: no token configured"));
            skipped = true;
        }
    }

    function _checkRemoveTestSkipped() internal returns (bool skipped) {
        if (!isMainnet) {
            emit log_string(string.concat("Skipping: remove tests are Mainnet-only"));
            skipped = true;
        } else if (swaps.length == 0) {
            emit log_string("Skipping: no pools configured");
            skipped = true;
        }
    }

    function _checkSwapTestSkipped() internal returns (bool skipped) {
        if (isMainnet) {
            emit log_string("Skipping: no swap tests on Mainnet");
            skipped = true;
        } else if (swaps.length == 0) {
            emit log_string("Skipping: no pools configured");
            skipped = true;
        }
    }

    function _checkWrongIndexTestSkipped() internal returns (bool skipped) {
        if (!WRONG_INDEX_TEST_ENABLED) {
            emit log_string("Skipping: wrong indices tests not enabled yet");
            skipped = true;
        }
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                          VIRTUAL FUNCTIONS                           ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function _initSwapArrays() internal virtual;
}
