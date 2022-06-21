// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "forge-std/Test.sol";
import {Utilities} from "../../utils/Utilities.sol";

import {IERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/IERC20.sol";

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
    function chainGasAmount() external view returns (uint256);

    function getFeeBalance(IERC20 token) external view returns (uint256);

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

// solhint-disable func-name-mixedcase

abstract contract DefaultBridgeForkTest is Test {
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

    Utilities internal utils;

    uint256 internal constant AMOUNT = 10**18;
    uint256 internal constant FEE = 10**17;
    uint256 internal constant AMOUNT_FULL = AMOUNT + FEE;

    address internal constant USER = address(1337420);
    address internal constant NODE = 0x230A1AC45690B9Ae1176389434610B9526d2f21b;

    address internal constant ZERO = address(0);
    IERC20 internal constant NULL = IERC20(ZERO);

    constructor(
        bool _isMainnet,
        bool _isGasEth,
        BridgeTestSetup memory _setup
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

        gasAirdropAmount = bridge.chainGasAmount();
        _kappa = keccak256("very real so genuine wow");

        utils = new Utilities();
    }

    function setUp() public {
        uint256 length = 0;
        for (; ; ++length) {
            try nusdPool.getToken(uint8(length)) returns (IERC20 token) {
                nusdPoolTokens.push(token);
            } catch {
                break;
            }
        }

        address bridgeImpl = deployCode("artifacts/SynapseBridge.sol/SynapseBridge.json");
        utils.upgradeTo(address(bridge), bridgeImpl);
        // TODO: verify correct storage behavior post-upgrade
    }

    function test_mint() public {
        bytes32 kappa = _nextKappa();
        Snapshot memory pre = _makeSnapshot(syn, syn);
        vm.prank(NODE);
        bridge.mint(USER, syn, AMOUNT_FULL, FEE, kappa);
        Snapshot memory post = _makeSnapshot(syn, syn);
        _checkSnapshots(pre, post, gasAirdropAmount, AMOUNT);
    }

    function test_mintAndSwap_neth() public {
        if (isMainnet) {
            emit log_string("Skipping mintAndSwap_neth on Mainnet");
            return;
        }
        bytes32 kappa = _nextKappa();
        Snapshot memory pre = isGasEth ? _makeSnapshot(neth, NULL) : _makeSnapshot(neth, weth);
        uint256 expectedSwap = nethPool.calculateSwap(0, 1, AMOUNT);
        vm.prank(NODE);
        bridge.mintAndSwap(USER, neth, AMOUNT_FULL, FEE, nethPool, 0, 1, 0, type(uint256).max, kappa);
        Snapshot memory post = isGasEth ? _makeSnapshot(neth, NULL) : _makeSnapshot(neth, weth);
        _checkSnapshots(pre, post, gasAirdropAmount + (isGasEth ? expectedSwap : 0), (isGasEth ? 0 : expectedSwap));
    }

    function test_mintAndSwap_nusd() public {
        if (isMainnet) {
            emit log_string("Skipping mintAndSwap_nusd on Mainnet");
            return;
        }
        uint256 amount = nusdPoolTokens.length;
        // start from 1 to skip nUSD
        for (uint256 indexTo = 1; indexTo < amount; ++indexTo) {
            IERC20 testToken = nusdPoolTokens[indexTo];
            bytes32 kappa = _nextKappa();
            Snapshot memory pre = _makeSnapshot(nusd, testToken);
            uint256 expectedSwap = nusdPool.calculateSwap(0, uint8(indexTo), AMOUNT);
            vm.prank(NODE);
            bridge.mintAndSwap(USER, nusd, AMOUNT_FULL, FEE, nusdPool, 0, uint8(indexTo), 0, type(uint256).max, kappa);
            Snapshot memory post = _makeSnapshot(nusd, testToken);
            _checkSnapshots(pre, post, gasAirdropAmount, expectedSwap);
        }
    }

    function test_withdraw() public {
        IERC20 testToken = originToken;
        if (address(testToken) == ZERO) {
            emit log_string("Skipping withdraw: no testing token configured");
            return;
        }
        bytes32 kappa = _nextKappa();
        Snapshot memory pre = _makeSnapshot(testToken, testToken);
        vm.prank(NODE);
        bridge.withdraw(USER, testToken, AMOUNT_FULL, FEE, kappa);
        Snapshot memory post = _makeSnapshot(testToken, testToken);
        _checkSnapshots(pre, post, gasAirdropAmount, AMOUNT);
    }

    function test_withdraw_gas() public {
        IERC20 testToken = wgas;
        if (address(testToken) == ZERO) {
            emit log_string("Skipping withdraw_gas: no testing token configured");
            return;
        }
        bytes32 kappa = _nextKappa();
        Snapshot memory pre = _makeSnapshot(testToken, NULL);
        vm.prank(NODE);
        bridge.withdraw(USER, testToken, AMOUNT_FULL, FEE, kappa);
        Snapshot memory post = _makeSnapshot(testToken, NULL);
        _checkSnapshots(pre, post, gasAirdropAmount + AMOUNT, 0);
    }

    function test_withdrawAndRemove() public {
        if (!isMainnet) {
            emit log_string("Skipping withdrawAndRemove: not mainnet");
            return;
        }
        uint256 amount = nusdPoolTokens.length;
        // nUSD is not in the pool, start from 0
        for (uint256 indexTo = 0; indexTo < amount; ++indexTo) {
            IERC20 testToken = nusdPoolTokens[indexTo];
            bytes32 kappa = _nextKappa();
            Snapshot memory pre = _makeSnapshot(nusd, testToken);
            uint256 expectedRemove = nusdPool.calculateRemoveLiquidityOneToken(AMOUNT, uint8(indexTo));
            vm.prank(NODE);
            bridge.withdrawAndRemove(
                USER,
                nusd,
                AMOUNT_FULL,
                FEE,
                nusdPool,
                uint8(indexTo),
                0,
                type(uint256).max,
                kappa
            );
            Snapshot memory post = _makeSnapshot(nusd, testToken);
            _checkSnapshots(pre, post, gasAirdropAmount, expectedRemove);
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
}
