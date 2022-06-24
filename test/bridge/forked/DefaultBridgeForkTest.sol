// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "forge-std/Test.sol";
import {Utilities} from "../../utils/Utilities.sol";

import {IERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/IERC20.sol";

// solhint-disable func-name-mixedcase
// solhint-disable not-rely-on-time

interface ISwap {
    function calculateSwap(
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx
    ) external view returns (uint256);

    function calculateRemoveLiquidityOneToken(uint256 tokenAmount, uint8 tokenIndex)
        external
        view
        returns (uint256 availableTokenAmount);

    function getToken(uint8 index) external view returns (IERC20);
}

interface IBridge {
    function NODEGROUP_ROLE() external view returns (bytes32);

    function GOVERNANCE_ROLE() external view returns (bytes32);

    function startBlockNumber() external view returns (uint256);

    function bridgeVersion() external view returns (uint256);

    function chainGasAmount() external view returns (uint256);

    function WETH_ADDRESS() external view returns (address payable);

    function getFeeBalance(IERC20 token) external view returns (uint256);

    function kappaExists(bytes32 kappa) external view returns (bool);

    function mint(
        address to,
        IERC20 token,
        uint256 amount,
        uint256 fee,
        bytes32 kappa
    ) external;

    function mintAndSwap(
        address to,
        IERC20 token,
        uint256 amount,
        uint256 fee,
        ISwap pool,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 minDy,
        uint256 deadline,
        bytes32 kappa
    ) external;

    function withdraw(
        address to,
        IERC20 token,
        uint256 amount,
        uint256 fee,
        bytes32 kappa
    ) external;

    function withdrawAndRemove(
        address to,
        IERC20 token,
        uint256 amount,
        uint256 fee,
        ISwap pool,
        uint8 swapTokenIndex,
        uint256 swapMinAmount,
        uint256 swapDeadline,
        bytes32 kappa
    ) external;
}

abstract contract DefaultBridgeForkTest is Test {
    using stdStorage for StdStorage;
    struct BridgeTestSetup {
        address bridge;
        address nethPool;
        address nusdPool;
        address neth;
        address weth;
        address wgas;
        address nusd;
        address syn;
        address originToken;
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
        uint256 feesEth;
        uint256 feesUsd;
        uint256 feesSyn;
    }

    IBridge internal bridge;

    uint256 internal gasAirdropAmount;

    ISwap internal nethPool;
    ISwap internal nusdPool;
    IERC20[] internal nusdPoolTokens;

    // nUSD and nETH behave differently on Mainnet
    bool internal immutable isMainnet;
    // whether ETH is the gas token
    bool internal immutable isGasEth;

    IERC20 internal neth;
    IERC20 internal weth;
    IERC20 internal nusd;

    // for testing withdraw() into native gas on applicable chains
    IERC20 internal wgas;

    // SYN can be minted on every chain
    IERC20 internal syn;

    // Token that's originated on tested chain, i.e. bridged by withdraw()
    IERC20 internal originToken;

    bytes32 private _kappa;
    BridgeState private _bridgeState;
    bytes32[4] private _existingKappas;

    Utilities internal utils;

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
        bool _isGasEth,
        BridgeTestSetup memory _setup,
        bytes32[4] memory _kappas
    ) {
        isMainnet = _isMainnet;
        isGasEth = _isGasEth;

        bridge = IBridge(_setup.bridge);
        nethPool = ISwap(_setup.nethPool);
        nusdPool = ISwap(_setup.nusdPool);
        neth = IERC20(_setup.neth);
        weth = IERC20(_setup.weth);
        nusd = IERC20(_setup.nusd);
        wgas = IERC20(_setup.wgas);
        syn = IERC20(_setup.syn);
        originToken = IERC20(_setup.originToken);

        _existingKappas = _kappas;

        gasAirdropAmount = bridge.chainGasAmount();
        _kappa = keccak256("very real so genuine wow");

        utils = new Utilities();
    }

    function setUp() public {
        if (address(nusdPool) != ZERO) {
            for (uint8 index = 0; ; ++index) {
                try nusdPool.getToken(index) returns (IERC20 token) {
                    nusdPoolTokens.push(token);
                } catch {
                    break;
                }
            }
        }

        _saveBridgeState();
        address bridgeImpl = deployCode("artifacts/SynapseBridge.sol/SynapseBridge.json");
        utils.upgradeTo(address(bridge), bridgeImpl);
    }

    function test_enableAirdrop() public {
        if (gasAirdropAmount != 0) {
            emit log_string("Skipping: airdrop already enabled");
            return;
        }
        gasAirdropAmount = AMOUNT / 10;
        stdstore.target(address(bridge)).sig(IBridge.chainGasAmount.selector).checked_write(gasAirdropAmount);
        require(bridge.chainGasAmount() == gasAirdropAmount, "Failed to set gas airdrop");
        deal(address(bridge), 10 * AMOUNT);

        test_mint();
        test_mintAndSwap_neth();
        test_mintAndSwap_nusd();
        test_withdraw();
        test_withdraw_gas();
    }

    function test_mint() public {
        if (_checkTokenTestSkipped(syn, "mint")) return;
        _test_mint(syn);
    }

    function test_mintAndSwap_neth() public {
        if (_checkPoolSwapTestSkipped(nethPool, "swap_neth")) return;
        uint256 quote = nethPool.calculateSwap(0, 1, AMOUNT);
        if (isGasEth) {
            _test_mintAndSwap(neth, NULL, nethPool, 0, 1, quote, block.timestamp, quote, 0);
        } else {
            _test_mintAndSwap(neth, weth, nethPool, 0, 1, quote, block.timestamp, 0, quote);
        }
    }

    function test_mintAndSwap_neth_amountOutTooLow() public {
        if (_checkPoolSwapTestSkipped(nethPool, "swap_neth")) return;
        uint256 quote = 2 * nethPool.calculateSwap(0, 1, AMOUNT);
        _test_mintAndSwap(neth, neth, nethPool, 0, 1, quote, type(uint256).max, 0, AMOUNT);
    }

    function test_mintAndSwap_neth_deadlineFailed() public {
        if (_checkPoolSwapTestSkipped(nethPool, "swap_neth")) return;
        _test_mintAndSwap(neth, neth, nethPool, 0, 1, 0, block.timestamp - 1, 0, AMOUNT);
    }

    function test_mintAndSwap_neth_wrongIndices() public {
        if (_checkPoolSwapTestSkipped(nethPool, "swap_neth")) return;
        if (_checkWrongIndexTestSkipped()) return;
        for (uint8 indexFrom = 0; indexFrom <= 1; ++indexFrom) {
            _test_mintAndSwap(neth, neth, nethPool, indexFrom, 0, 0, type(uint256).max, 0, AMOUNT);
        }
    }

    function test_mintAndSwap_nusd() public {
        if (_checkPoolSwapTestSkipped(nusdPool, "swap_nusd")) return;
        uint256 amount = nusdPoolTokens.length;
        // start from 1 to skip nUSD
        for (uint8 indexTo = 1; indexTo < amount; ++indexTo) {
            uint256 quote = nusdPool.calculateSwap(0, indexTo, AMOUNT);
            _test_mintAndSwap(nusd, nusdPoolTokens[indexTo], nusdPool, 0, indexTo, quote, block.timestamp, 0, quote);
        }
    }

    function test_mintAndSwap_nusd_amountOutTooLow() public {
        if (_checkPoolSwapTestSkipped(nusdPool, "swap_nusd")) return;
        uint256 amount = nusdPoolTokens.length;
        // start from 1 to skip nUSD
        for (uint8 indexTo = 1; indexTo < amount; ++indexTo) {
            uint256 quote = 2 * nusdPool.calculateSwap(0, indexTo, AMOUNT);
            _test_mintAndSwap(nusd, nusd, nusdPool, 0, indexTo, quote, type(uint256).max, 0, AMOUNT);
        }
    }

    function test_mintAndSwap_nusd_deadlineFailed() public {
        if (_checkPoolSwapTestSkipped(nusdPool, "swap_nusd")) return;
        uint256 amount = nusdPoolTokens.length;
        // start from 1 to skip nUSD
        for (uint8 indexTo = 1; indexTo < amount; ++indexTo) {
            _test_mintAndSwap(nusd, nusd, nusdPool, 0, indexTo, 0, block.timestamp - 1, 0, AMOUNT);
        }
    }

    function test_mintAndSwap_nusd_wrongIndices() public {
        if (_checkPoolSwapTestSkipped(nusdPool, "swap_nusd")) return;
        if (_checkWrongIndexTestSkipped()) return;
        for (uint8 indexFrom = 0; indexFrom < nusdPoolTokens.length; ++indexFrom) {
            _test_mintAndSwap(nusd, nusd, nusdPool, indexFrom, 0, 0, block.timestamp, 0, AMOUNT);
        }
    }

    function test_withdraw() public {
        if (_checkTokenTestSkipped(originToken, "withdraw")) return;
        _test_withdraw(originToken, originToken, 0, AMOUNT);
    }

    function test_withdraw_gas() public {
        if (_checkTokenTestSkipped(wgas, "withdraw_gas")) return;
        _test_withdraw(wgas, NULL, AMOUNT, 0);
    }

    function test_withdrawAndRemove() public {
        if (_checkPoolRemoveTestSkipped(nusdPool, "remove_nusd")) return;
        uint256 amount = nusdPoolTokens.length;
        // nUSD is not in the pool, start from 0
        for (uint8 indexTo = 0; indexTo < amount; ++indexTo) {
            uint256 quote = nusdPool.calculateRemoveLiquidityOneToken(AMOUNT, indexTo);
            _test_withdrawAndRemove(nusdPoolTokens[indexTo], indexTo, quote, block.timestamp, quote);
        }
    }

    function test_withdrawAndRemove_amountOutTooLow() public {
        if (_checkPoolRemoveTestSkipped(nusdPool, "remove_nusd")) return;
        uint256 amount = nusdPoolTokens.length;
        // nUSD is not in the pool, start from 0
        for (uint8 indexTo = 0; indexTo < amount; ++indexTo) {
            uint256 quote = 2 * nusdPool.calculateRemoveLiquidityOneToken(AMOUNT, indexTo);
            _test_withdrawAndRemove(nusd, indexTo, quote, type(uint256).max, AMOUNT);
        }
    }

    function test_withdrawAndRemove_deadlineFailed() public {
        if (_checkPoolRemoveTestSkipped(nusdPool, "remove_nusd")) return;
        uint256 amount = nusdPoolTokens.length;
        // nUSD is not in the pool, start from 0
        for (uint8 indexTo = 0; indexTo < amount; ++indexTo) {
            _test_withdrawAndRemove(nusd, indexTo, 0, block.timestamp - 1, AMOUNT);
        }
    }

    function test_withdrawAndRemove_wrongIndex() public {
        if (_checkPoolRemoveTestSkipped(nusdPool, "remove_nusd")) return;
        if (_checkWrongIndexTestSkipped()) return;
        _test_withdrawAndRemove(nusd, uint8(nusdPoolTokens.length), 0, type(uint256).max, AMOUNT);
    }

    function test_upgrade() public {
        assertEq(_bridgeState.nodeGroupRole, bridge.NODEGROUP_ROLE(), "NODEGROUP_ROLE rekt post-upgrade");
        assertEq(_bridgeState.governanceRole, bridge.GOVERNANCE_ROLE(), "GOVERNANCE_ROLE rekt post-upgrade");
        assertEq(_bridgeState.startBlockNumber, bridge.startBlockNumber(), "startBlockNumber rekt post-upgrade");
        assertEq(_bridgeState.chainGasAmount, bridge.chainGasAmount(), "chainGasAmount rekt post-upgrade");
        assertEq(_bridgeState.wethAddress, bridge.WETH_ADDRESS(), "WETH_ADDRESS rekt post-upgrade");

        if (address(neth) != ZERO) {
            assertEq(bridge.getFeeBalance(neth), _bridgeState.feesEth, "Eth fees rekt post-upgrade");
        } else if (address(weth) != ZERO) {
            assertEq(bridge.getFeeBalance(weth), _bridgeState.feesEth, "Eth fees rekt post-upgrade");
        }

        if (address(nusd) != ZERO) {
            assertEq(bridge.getFeeBalance(nusd), _bridgeState.feesUsd, "Usd fees rekt post-upgrade");
        }

        if (address(syn) != ZERO) {
            assertEq(bridge.getFeeBalance(syn), _bridgeState.feesSyn, "Usd fees rekt post-upgrade");
        }

        for (uint256 i = 0; i < _existingKappas.length; ++i) {
            assertTrue(bridge.kappaExists(_existingKappas[i]), "Kappa is missing post-upgrade");
        }

        assertEq(bridge.bridgeVersion(), 7, "Bridge version not bumped");
    }

    function _assertKappa(bytes32 kappa) internal view {
        assert(bridge.kappaExists(kappa));
    }

    function _checkTokenTestSkipped(IERC20 token, string memory testName) internal returns (bool skipped) {
        if (address(token) == ZERO) {
            emit log_string(string.concat("Skipping ", testName, ": no token configured"));
            skipped = true;
        }
    }

    function _checkPoolSwapTestSkipped(ISwap pool, string memory testName) internal returns (bool skipped) {
        if (isMainnet) {
            emit log_string(string.concat("Skipping ", testName, ": no swap tests on Mainnet"));
            skipped = true;
        } else if (address(pool) == ZERO) {
            emit log_string(string.concat("Skipping ", testName, ": no pool configured"));
            skipped = true;
        }
    }

    function _checkPoolRemoveTestSkipped(ISwap pool, string memory testName) internal returns (bool skipped) {
        if (!isMainnet) {
            emit log_string(string.concat("Skipping ", testName, ": remove tests are Mainnet-only"));
            skipped = true;
        } else if (address(pool) == ZERO) {
            emit log_string(string.concat("Skipping ", testName, ": no pool configured"));
            skipped = true;
        }
    }

    function _checkWrongIndexTestSkipped() internal returns (bool skipped) {
        if (!WRONG_INDEX_TEST_ENABLED) {
            emit log_string("Tests with wrong indices not yet enabled");
            skipped = true;
        }
    }

    function _checkSnapshots(
        Snapshot memory _pre,
        Snapshot memory _post,
        uint256 _expectedGas,
        uint256 _expectedToken
    ) internal {
        require(_post.bridgeTokenFees >= _pre.bridgeTokenFees, "WTF: fees reduced");
        assertEq(_post.bridgeTokenFees - _pre.bridgeTokenFees, FEE, "Incorrect bridgeFee");

        require(_post.userGasBalance >= _pre.userGasBalance, "WFT: user gas balance reduced");
        assertEq(_post.userGasBalance - _pre.userGasBalance, _expectedGas, "Incorrect amount of gas received");

        require(_post.userTokenBalance >= _pre.userTokenBalance, "WFT: user token balance reduced");
        assertEq(_post.userTokenBalance - _pre.userTokenBalance, _expectedToken, "Incorrect amount of tokens received");
    }

    function _makeSnapshot(IERC20 _bridgeToken, IERC20 _testToken) internal view returns (Snapshot memory snapshot) {
        snapshot.bridgeTokenFees = bridge.getFeeBalance(_bridgeToken);
        snapshot.userGasBalance = USER.balance;
        // skip in case received asset is gas
        if (address(_testToken) != ZERO) snapshot.userTokenBalance = _testToken.balanceOf(USER);
    }

    function _nextKappa() internal returns (bytes32 nextKappa) {
        nextKappa = _kappa;
        _kappa = keccak256(abi.encode(nextKappa));
    }

    function _saveBridgeState() private {
        BridgeState memory state;
        state.nodeGroupRole = bridge.NODEGROUP_ROLE();
        state.governanceRole = bridge.GOVERNANCE_ROLE();
        state.startBlockNumber = bridge.startBlockNumber();
        state.chainGasAmount = bridge.chainGasAmount();
        state.wethAddress = bridge.WETH_ADDRESS();

        if (address(neth) != ZERO) {
            state.feesEth = bridge.getFeeBalance(neth);
        } else if (address(weth) != ZERO) {
            state.feesEth = bridge.getFeeBalance(weth);
        }
        if (address(nusd) != ZERO) state.feesUsd = bridge.getFeeBalance(nusd);
        if (address(syn) != ZERO) state.feesSyn = bridge.getFeeBalance(syn);

        for (uint256 i = 0; i < _existingKappas.length; ++i) {
            _assertKappa(_existingKappas[i]);
        }

        _bridgeState = state;
    }

    function _test_mint(IERC20 bridgeToken) internal {
        bytes32 kappa = _nextKappa();
        Snapshot memory pre = _makeSnapshot(bridgeToken, bridgeToken);
        vm.prank(NODE);
        bridge.mint(USER, bridgeToken, AMOUNT_FULL, FEE, kappa);
        Snapshot memory post = _makeSnapshot(bridgeToken, bridgeToken);
        _checkSnapshots(pre, post, gasAirdropAmount, AMOUNT);
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
        uint256 expectedToken
    ) internal {
        bytes32 kappa = _nextKappa();
        Snapshot memory pre = _makeSnapshot(bridgeToken, receivedToken);
        vm.prank(NODE);
        bridge.mintAndSwap(USER, bridgeToken, AMOUNT_FULL, FEE, pool, indexFrom, indexTo, quote, deadline, kappa);
        Snapshot memory post = _makeSnapshot(bridgeToken, receivedToken);
        _checkSnapshots(pre, post, gasAirdropAmount + expectedGas, expectedToken);
        _assertKappa(kappa);
    }

    function _test_withdraw(
        IERC20 bridgeToken,
        IERC20 receivedToken,
        uint256 expectedGas,
        uint256 expectedToken
    ) internal {
        bytes32 kappa = _nextKappa();
        Snapshot memory pre = _makeSnapshot(bridgeToken, receivedToken);
        vm.prank(NODE);
        bridge.withdraw(USER, bridgeToken, AMOUNT_FULL, FEE, kappa);
        Snapshot memory post = _makeSnapshot(bridgeToken, receivedToken);
        _checkSnapshots(pre, post, gasAirdropAmount + expectedGas, expectedToken);
        _assertKappa(kappa);
    }

    function _test_withdrawAndRemove(
        IERC20 receivedToken,
        uint8 indexTo,
        uint256 quote,
        uint256 deadline,
        uint256 expectedToken
    ) internal {
        bytes32 kappa = _nextKappa();
        Snapshot memory pre = _makeSnapshot(nusd, receivedToken);
        vm.prank(NODE);
        bridge.withdrawAndRemove(USER, nusd, AMOUNT_FULL, FEE, nusdPool, indexTo, quote, deadline, kappa);
        Snapshot memory post = _makeSnapshot(nusd, receivedToken);
        _checkSnapshots(pre, post, gasAirdropAmount, expectedToken);
        _assertKappa(kappa);
    }
}
