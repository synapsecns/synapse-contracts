// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import {Utilities} from "../utilities/Utilities.sol";

import {RateLimiter} from "src-bridge/RateLimiter.sol";

import {IERC20} from "@openzeppelin/contracts-4.3.1/token/ERC20/IERC20.sol";

interface IBridge {
    function bridgeVersion() external view returns (uint256);

    function getFeeBalance(address token) external view returns (uint256);

    function kappaExists(bytes32 kappa) external view returns (bool);

    function GOVERNANCE_ROLE() external view returns (bytes32);

    function RATE_LIMITER_ROLE() external view returns (bytes32);

    // Restricted functions: admin

    function grantRole(bytes32 role, address account) external;

    // Restricted functions: governance

    function setRateLimiter(address _rateLimiter) external;

    function setRateLimiterEnabled(bool enabled) external;

    // bridge functions

    function mint(
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
        address pool,
        uint8 swapTokenIndex,
        uint256 swapMinAmount,
        uint256 swapDeadline,
        bytes32 kappa
    ) external;
}

contract RateLimitedBridge is Test {
    address public immutable bridge;

    address public constant NODE_GROUP =
        0x230A1AC45690B9Ae1176389434610B9526d2f21b;

    Utilities internal immutable utils;

    RateLimiter internal immutable rateLimiter;

    address payable public immutable attacker;
    address payable public immutable limiter;
    address payable public immutable user;
    address payable public immutable governance;

    constructor(address _bridge) {
        bridge = _bridge;

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

    function _testUpgrade(bytes32[] memory kappas) internal {
        for (uint256 i = 0; i < kappas.length; ++i) {
            assertTrue(
                IBridge(bridge).kappaExists(kappas[i]),
                "Kappa is missing post-upgrade"
            );
        }

        assertEq(IBridge(bridge).bridgeVersion(), 7, "Bridge not upgraded");
    }

    function _testBridgeFunction(
        uint96 amount,
        IERC20 token,
        bool isWithdraw,
        bool checkBalance,
        bytes4 bridgeSelector,
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
        _checkDelayed(kappa, NODE_GROUP, bridge, bridgeSelector, payload);

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
        _submitBridgeTx(executor, _contract, selector, payload);
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

    function _checkDelayed(
        bytes32 kappa,
        address executor,
        address _contract,
        bytes4 selector,
        bytes memory payload
    ) internal {
        assertTrue(
            !IBridge(bridge).kappaExists(kappa),
            "Kappa exists pre-bridge"
        );
        _submitBridgeTx(executor, _contract, selector, payload);
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

    function _submitBridgeTx(
        address executor,
        address _contract,
        bytes4 selector,
        bytes memory payload
    ) internal {
        hoax(executor);
        (bool success, bytes memory returnData) = _contract.call(
            abi.encodePacked(selector, payload)
        );
        assertTrue(success, _getRevertMsg(returnData));
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
