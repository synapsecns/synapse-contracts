// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";

import {Utilities} from "../utilities/Utilities.sol";

import {RateLimiter} from "src-bridge/RateLimiter.sol";

import {IERC20} from "@openzeppelin/contracts-4.5.0/token/ERC20/IERC20.sol";
import {StringsUpgradeable} from "@openzeppelin/contracts-4.5.0-upgradeable/utils/StringsUpgradeable.sol";

interface IBridge {
    function NODEGROUP_ROLE() external view returns (bytes32);

    function GOVERNANCE_ROLE() external view returns (bytes32);

    function startBlockNumber() external view returns (uint256);

    function bridgeVersion() external view returns (uint256);

    function chainGasAmount() external view returns (uint256);

    function WETH_ADDRESS() external view returns (address payable);

    function getFeeBalance(address token) external view returns (uint256);

    function kappaExists(bytes32 kappa) external view returns (bool);

    function RATE_LIMITER_ROLE() external view returns (bytes32);

    // Restricted functions: initializer

    function initialize() external;

    // Restricted functions: admin

    function setWethAddress(address payable _wethAddress) external;

    function grantRole(bytes32 role, address account) external;

    // Restricted functions: governance

    function addKappas(bytes32[] calldata kappas) external;

    function withdrawFees(IERC20 token, address to) external;

    function setChainGasAmount(uint256 amount) external;

    function setRateLimiter(address _rateLimiter) external;

    function setRateLimiterEnabled(bool enabled) external;

    function pause() external;

    function unpause() external;

    // bridge functions

    function mint(
        address payable to,
        address token,
        uint256 amount,
        uint256 fee,
        bytes32 kappa
    ) external;

    function retryMint(
        address payable to,
        address token,
        uint256 amount,
        uint256 fee,
        bytes32 kappa
    ) external;

    function mintAndSwap(
        address payable to,
        address token,
        uint256 amount,
        uint256 fee,
        address pool,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 minDy,
        uint256 deadline,
        bytes32 kappa
    ) external;

    function retryMintAndSwap(
        address payable to,
        address token,
        uint256 amount,
        uint256 fee,
        address pool,
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

    function retryWithdraw(
        address to,
        IERC20 token,
        uint256 amount,
        uint256 fee,
        bytes32 kappa
    ) external;

    function retryWithdrawAndRemove(
        address to,
        IERC20 token,
        uint256 amount,
        uint256 fee,
        address pool,
        uint8 swapTokenIndex,
        uint256 swapMinAmount,
        uint256 swapDeadline,
        bytes32 kappa
    ) external;

    function withdrawAndRemove(
        address to,
        IERC20 token,
        uint256 amount,
        uint256 fee,
        address pool,
        uint8 swapTokenIndex,
        uint256 swapMinAmount,
        uint256 swapDeadline,
        bytes32 kappa
    ) external;
}

interface ISynapseERC20 {
    function MINTER_ROLE() external view returns (bytes32);

    function grantRole(bytes32 role, address account) external;

    function revokeRole(bytes32 role, address account) external;
}

contract RateLimitedBridge is Test {
    struct BridgeState {
        bytes32 nodeGroupRole;
        bytes32 governanceRole;
        uint256 startBlockNumber;
        uint256 chainGasAmount;
        address payable wethAddress;
        address[2] tokens;
        uint256[] fees;
    }

    address public immutable bridge;

    BridgeState public state;

    address public constant NODE_GROUP =
        0x230A1AC45690B9Ae1176389434610B9526d2f21b;

    Utilities internal immutable utils;

    RateLimiter internal immutable rateLimiter;

    address payable public immutable attacker;
    address payable public immutable limiter;
    address payable public immutable user;
    address payable public immutable governance;

    constructor(address _bridge, address[2] memory tokens) {
        bridge = _bridge;

        _saveState(tokens);

        utils = new Utilities();
        address impl = deployCode(
            "./artifacts/SynapseBridge.sol/SynapseBridge.json"
        );
        utils.upgradeTo(_bridge, impl);

        rateLimiter = new RateLimiter();
        rateLimiter.initialize();

        address payable[] memory users = utils.createUsers(10);
        attacker = users[0];
        limiter = users[1];
        user = users[2];
        governance = users[3];
    }

    function _saveState(address[2] memory tokens) internal {
        uint256[] memory fees = new uint256[](tokens.length);
        for (uint256 i = 0; i < fees.length; i++) {
            fees[i] = IBridge(bridge).getFeeBalance(tokens[i]);
        }

        state = BridgeState({
            nodeGroupRole: IBridge(bridge).NODEGROUP_ROLE(),
            governanceRole: IBridge(bridge).GOVERNANCE_ROLE(),
            startBlockNumber: IBridge(bridge).startBlockNumber(),
            chainGasAmount: IBridge(bridge).chainGasAmount(),
            wethAddress: IBridge(bridge).WETH_ADDRESS(),
            tokens: tokens,
            fees: fees
        });
    }

    function setUp() public {
        // Grant RateLimiter roles
        rateLimiter.grantRole(rateLimiter.LIMITER_ROLE(), limiter);
        rateLimiter.grantRole(rateLimiter.BRIDGE_ROLE(), bridge);
        rateLimiter.grantRole(rateLimiter.GOVERNANCE_ROLE(), governance);

        // Set RateLimiter address in Bridge
        bytes32 role = IBridge(bridge).GOVERNANCE_ROLE();
        startHoax(utils.getRoleMember(bridge, role));
        IBridge(bridge).setRateLimiter(address(rateLimiter));
        IBridge(bridge).setRateLimiterEnabled(true);
        vm.stopPrank();

        // Grant RateLimiter needed Bridge role
        role = IBridge(bridge).RATE_LIMITER_ROLE();
        hoax(utils.getRoleMember(bridge, 0x00));
        IBridge(bridge).grantRole(role, address(rateLimiter));

        // Set Bridge address in RateLimiter
        hoax(governance);
        rateLimiter.setBridgeAddress(bridge);
    }

    /**
     * @dev Checks that kappaMap isn't rekt by the implementation upgrade,
     * also checks that bridgeVersion is updated
     */
    function _testUpgrade(bytes32[] memory kappas) internal {
        for (uint256 i = 0; i < kappas.length; ++i) {
            assertTrue(
                IBridge(bridge).kappaExists(kappas[i]),
                "Kappa is missing post-upgrade"
            );
        }

        assertEq(
            state.nodeGroupRole,
            IBridge(bridge).NODEGROUP_ROLE(),
            "NODEGROUP_ROLE rekt post-upgrade"
        );
        assertEq(
            state.governanceRole,
            IBridge(bridge).GOVERNANCE_ROLE(),
            "GOVERNANCE_ROLE rekt post-upgrade"
        );
        assertEq(
            state.startBlockNumber,
            IBridge(bridge).startBlockNumber(),
            "startBlockNumber rekt post-upgrade"
        );
        assertEq(
            state.chainGasAmount,
            IBridge(bridge).chainGasAmount(),
            "chainGasAmount rekt post-upgrade"
        );
        assertEq(
            state.wethAddress,
            IBridge(bridge).WETH_ADDRESS(),
            "WETH_ADDRESS rekt post-upgrade"
        );

        uint256 length = state.tokens.length;
        for (uint256 i = 0; i < length; ++i) {
            assertEq(
                state.fees[i],
                IBridge(bridge).getFeeBalance(state.tokens[i]),
                "fees rekt post-upgrade"
            );
        }

        assertEq(IBridge(bridge).bridgeVersion(), 7, "Bridge not upgraded");
    }

    /**
     * @dev Does two transactions:
     * 1. amountFirst < allowance => should be processed
     * 2. Second tx is exactly (allowance - amountFirst + 1) => should be rate limited
     * Limiter then tries to push transaction through.
     *
     * Also checks if attacker can call bridge using bridge function, or retry bridge function
     */
    function _testBridgeFunction(
        uint96 amount,
        IERC20 token,
        bool isWithdraw,
        bool checkBalance,
        bytes4 bridgeSelector,
        bytes4 retrySelector,
        bytes memory extraParams
    ) internal {
        vm.assume(amount >= 3);
        if (isWithdraw) {
            vm.assume(amount <= _getBridgeBalance(token));
        } else {
            vm.assume(amount < type(uint96).max);
        }

        _setAllowance(token, amount);

        uint96 amountBridged = amount / 3;

        bytes32 kappa = utils.getNextKappa();

        bytes memory payload = _getPayload(
            token,
            amountBridged,
            0,
            extraParams,
            kappa
        );

        _checkAccess(
            bridge,
            bridgeSelector,
            payload,
            "Caller is not a node group"
        );
        _checkAccess(
            bridge,
            retrySelector,
            payload,
            "Caller is not rate limiter"
        );

        _checkCompleted(
            token,
            amountBridged,
            0,
            kappa,
            NODE_GROUP,
            bridge,
            bridgeSelector,
            payload,
            checkBalance
        );

        amountBridged = amount - amountBridged + 1;
        kappa = utils.getNextKappa();
        payload = _getPayload(token, amountBridged, 0, extraParams, kappa);
        // This should be rate limited
        _checkDelayed(kappa, NODE_GROUP, bridge, bridgeSelector, payload, true);

        // Limiter should be able to push tx through
        _checkCompleted(
            token,
            amountBridged,
            0,
            kappa,
            limiter,
            address(rateLimiter),
            rateLimiter.retryByKappa.selector,
            abi.encode(kappa),
            checkBalance
        );
    }

    /**
     * @dev gets payload for arbitrary bridge function
     */
    function _getPayload(
        IERC20 token,
        uint256 amount,
        uint256 fee,
        bytes memory extraParams,
        bytes32 kappa
    ) internal view returns (bytes memory payload) {
        payload = abi.encodePacked(
            abi.encode(user, token, amount, fee),
            extraParams,
            kappa
        );
    }

    function _checkAccess(
        address _contract,
        bytes4 selector,
        bytes memory payload,
        string memory revertMsg
    ) internal {
        hoax(attacker);
        (bool success, bytes memory returnData) = _contract.call(
            abi.encodePacked(selector, payload)
        );
        assertTrue(!success, "Attacker gained access");
        string memory _revertMsg = _getRevertMsg(returnData);
        assertEq(revertMsg, _revertMsg, "Unexpected revert message");
    }

    function _checkAccessControl(
        address _contract,
        bytes4 selector,
        bytes memory payload,
        bytes32 neededRole
    ) internal {
        _checkAccess(
            _contract,
            selector,
            payload,
            _getAccessControlRevertMsg(neededRole, attacker)
        );
    }

    function _getAccessControlRevertMsg(bytes32 role, address account)
        internal
        pure
        returns (string memory revertMsg)
    {
        revertMsg = string(
            abi.encodePacked(
                "AccessControl: account ",
                StringsUpgradeable.toHexString(uint160(account), 20),
                " is missing role ",
                StringsUpgradeable.toHexString(uint256(role), 32)
            )
        );
    }

    /**
     * @dev submits a bridge transaction and checks that it's completed
     * @param checkBalance whether user balance needs to be checked (turn off for *AndSwap, *AndRemove functions)
     */
    function _checkCompleted(
        IERC20 token,
        uint256 amount,
        uint256 fee,
        bytes32 kappa,
        address executor,
        address _contract,
        bytes4 selector,
        bytes memory payload,
        bool checkBalance
    ) internal {
        uint256 pre = token.balanceOf(user);

        assertTrue(
            !IBridge(bridge).kappaExists(kappa),
            "Kappa exists pre-bridge"
        );
        _submitBridgeTx(executor, _contract, selector, payload, true);
        assertTrue(
            IBridge(bridge).kappaExists(kappa),
            "Kappa doesn't exist post-bridge"
        );

        if (checkBalance) {
            uint256 post = token.balanceOf(user);
            assertTrue(pre != post, "User hasn't received anything");
            assertEq(
                pre + amount - fee,
                post,
                "User hasn't received full amount"
            );
        }
    }

    /**
     * @dev submits a bridge transaction and checks that it's rate limited
     */
    function _checkDelayed(
        bytes32 kappa,
        address executor,
        address _contract,
        bytes4 selector,
        bytes memory payload,
        bool callSuccess
    ) internal {
        assertTrue(
            !IBridge(bridge).kappaExists(kappa),
            "Kappa exists pre-bridge"
        );
        _submitBridgeTx(executor, _contract, selector, payload, callSuccess);
        assertTrue(
            !IBridge(bridge).kappaExists(kappa),
            "Transaction wasn't delayed"
        );
    }

    function _getBridgeBalance(IERC20 token) internal view returns (uint256) {
        return
            token.balanceOf(bridge) -
            IBridge(bridge).getFeeBalance(address(token));
    }

    /**
     * @dev submits bridge transaction. Can be used for both "bridge IN" (tx submitted by validator)
     * or "retry bridge IN" (tx submitted by limiter).
     */
    function _submitBridgeTx(
        address executor,
        address _contract,
        bytes4 selector,
        bytes memory payload,
        bool callSuccess
    ) internal {
        hoax(executor);
        (bool success, bytes memory returnData) = _contract.call(
            abi.encodePacked(selector, payload)
        );
        if (callSuccess) {
            assertTrue(success, _getRevertMsg(returnData));
        } else {
            assertTrue(!success, "Transaction should have reverted");
        }
    }

    function _setAllowance(IERC20 token, uint96 amount) internal {
        hoax(limiter);
        rateLimiter.setAllowance(
            address(token),
            amount,
            60,
            uint32(block.timestamp / 60)
        );
    }

    function _getRevertMsg(bytes memory _returnData)
        internal
        pure
        returns (string memory)
    {
        // If the _res length is less than 68, then the transaction failed silently (without a revert message)
        if (_returnData.length < 68) return "Transaction reverted silently";

        assembly {
            // Slice the sighash.
            _returnData := add(_returnData, 0x04)
        }
        return abi.decode(_returnData, (string)); // All that remains is the revert string
    }
}
