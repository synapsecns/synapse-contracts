// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-4.5.0-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-4.5.0-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-4.5.0-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-4.5.0-upgradeable/utils/math/MathUpgradeable.sol";

import "./libraries/EnumerableQueueUpgradeable.sol";
import "./interfaces/IRateLimiter.sol";

import {StringsUpgradeable} from "@openzeppelin/contracts-4.5.0-upgradeable/utils/StringsUpgradeable.sol";

// solhint-disable not-rely-on-time

interface IBridge {
    function kappaExists(bytes32 kappa) external view returns (bool);
}

// @title RateLimiter
// @dev a bridge asset rate limiter based on https://github.com/gnosis/safe-modules/blob/master/allowances/contracts/AlowanceModule.sol
contract RateLimiter is
    Initializable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    IRateLimiter
{
    using EnumerableQueueUpgradeable for EnumerableQueueUpgradeable.KappaQueue;
    /*** STATE ***/

    string public constant NAME = "Rate Limiter";
    string public constant VERSION = "0.1.0";

    // roles
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bytes32 public constant LIMITER_ROLE = keccak256("LIMITER_ROLE");
    bytes32 public constant BRIDGE_ROLE = keccak256("BRIDGE_ROLE");

    // Token -> Allowance
    mapping(address => Allowance) public allowances;
    // Kappa->Retry Selector
    EnumerableQueueUpgradeable.KappaQueue private rateLimitedQueue;
    mapping(bytes32 => bytes) private failedRetries;
    // Bridge Address
    address public BRIDGE_ADDRESS;
    // Time period after anyone can retry a rate limited tx
    uint32 public retryTimeout;
    uint32 public constant MIN_RETRY_TIMEOUT = 10;

    // List of tokens
    address[] public tokens;

    /*** EVENTS ***/

    event SetAllowance(
        address indexed token,
        uint96 allowanceAmount,
        uint16 resetTime
    );
    event ResetAllowance(address indexed token);

    /*** STRUCTS ***/

    // The allowance info is optimized to fit into one word of storage.
    struct Allowance {
        uint96 amount;
        uint96 spent;
        uint16 resetTimeMin; // Maximum reset time span is 65k minutes
        uint32 lastResetMin; // epoch/60
        bool initialized;
    }

    /*** FUNCTIONS ***/

    function initialize() external initializer {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        __AccessControl_init();
        retryTimeout = MIN_RETRY_TIMEOUT;
    }

    /*** VIEWS ***/

    function getTokenAllowance(address token)
        external
        view
        returns (uint256[4] memory)
    {
        Allowance memory allowance = _getAllowance(token);
        return [
            uint256(allowance.amount),
            uint256(allowance.spent),
            uint256(allowance.resetTimeMin),
            uint256(allowance.lastResetMin)
        ];
    }

    /**
     * @notice Gets a  list of tokens with allowances
     **/
    function getTokens() external view returns (address[] memory) {
        return tokens;
    }

    function retryQueueLength() external view returns (uint256 length) {
        length = rateLimitedQueue.length();
    }

    /*** RESTRICTED: GOVERNANCE ***/

    function setBridgeAddress(address bridge)
        external
        onlyRole(GOVERNANCE_ROLE)
    {
        BRIDGE_ADDRESS = bridge;
    }

    function setRetryTimeout(uint32 _retryTimeout)
        external
        onlyRole(GOVERNANCE_ROLE)
    {
        require(_retryTimeout >= MIN_RETRY_TIMEOUT, "Timeout too short");
        retryTimeout = _retryTimeout;
    }

    /*** RESTRICTED: LIMITER ***/

    function deleteByKappa(bytes32 kappa) external onlyRole(LIMITER_ROLE) {
        rateLimitedQueue.deleteKey(kappa);
    }

    function resetAllowance(address token) external onlyRole(LIMITER_ROLE) {
        Allowance memory allowance = _getAllowance(token);
        allowance.spent = 0;
        _updateAllowance(token, allowance);
        emit ResetAllowance(token);
    }

    /**
     * @notice Updates the allowance for a given token
     * @param token to update the allowance for
     * @param allowanceAmount for the token
     * @param resetTimeMin minimum reset time (amount goes to 0 after this)
     * @param resetBaseMin amount Amount in native token decimals to transfer cross-chain pre-fees
     **/
    function setAllowance(
        address token,
        uint96 allowanceAmount,
        uint16 resetTimeMin,
        uint32 resetBaseMin
    ) external onlyRole(LIMITER_ROLE) {
        Allowance memory allowance = _getAllowance(token);
        if (!allowance.initialized) {
            // New token
            allowance.initialized = true;
            tokens.push(token);
        }
        // Divide by 60 to get current time in minutes
        // solium-disable-next-line security/no-block-members
        uint32 currentMin = uint32(block.timestamp / 60);
        if (resetBaseMin > 0) {
            require(resetBaseMin <= currentMin, "resetBaseMin <= currentMin");
            allowance.lastResetMin =
                currentMin -
                ((currentMin - resetBaseMin) % resetTimeMin);
        } else if (allowance.lastResetMin == 0) {
            allowance.lastResetMin = currentMin;
        }
        allowance.resetTimeMin = resetTimeMin;
        allowance.amount = allowanceAmount;
        _updateAllowance(token, allowance);
        emit SetAllowance(token, allowanceAmount, resetTimeMin);
    }

    /*** RESTRICTED: BRIDGE ***/

    function addToRetryQueue(bytes32 kappa, bytes memory toRetry)
        external
        onlyRole(BRIDGE_ROLE)
    {
        rateLimitedQueue.add(kappa, toRetry);
    }

    /**
     * @notice Checks the allowance for a given token. If the new amount exceeds the allowance, it is not updated and false is returned
     * otherwise true is returned and the transaction can proceed
     * @param amount to transfer
     **/
    function checkAndUpdateAllowance(address token, uint256 amount)
        external
        nonReentrant
        onlyRole(BRIDGE_ROLE)
        returns (bool)
    {
        Allowance memory allowance = _getAllowance(token);

        // Update state
        // @dev reverts if amount > (2^96 - 1)
        uint96 newSpent = allowance.spent + uint96(amount);

        // do not proceed. Store the transaction for later
        if (newSpent > allowance.amount) {
            return false;
        }

        allowance.spent = newSpent;
        _updateAllowance(token, allowance);

        return true;
    }

    /*** INTERNAL: ALLOWANCE ***/

    function _getAllowance(address token)
        internal
        view
        returns (Allowance memory allowance)
    {
        allowance = allowances[token];
        // solium-disable-next-line security/no-block-members
        uint32 currentMin = uint32(block.timestamp / 60);
        // Check if we should reset the time. We do this on load to minimize storage read/ writes
        if (
            allowance.resetTimeMin > 0 &&
            allowance.lastResetMin <= currentMin - allowance.resetTimeMin
        ) {
            allowance.spent = 0;
            // Resets happen in regular intervals and `lastResetMin` should be aligned to that
            allowance.lastResetMin =
                currentMin -
                ((currentMin - allowance.lastResetMin) %
                    allowance.resetTimeMin);
        }
        return allowance;
    }

    function _updateAllowance(address token, Allowance memory allowance)
        internal
    {
        allowances[token] = allowance;
    }

    /*** RETRY FUNCTIONS ***/

    function retryByKappa(bytes32 kappa) external {
        (bytes memory toRetry, uint32 storedAtMin) = rateLimitedQueue.get(
            kappa
        );
        if (toRetry.length > 0) {
            if (!hasRole(LIMITER_ROLE, msg.sender)) {
                // Permissionless retry is only available once timeout is finished
                uint32 currentMin = uint32(block.timestamp / 60);
                require(
                    currentMin >= storedAtMin + retryTimeout,
                    "Retry timeout not finished"
                );
            }
            rateLimitedQueue.deleteKey(kappa);
            _retry(kappa, toRetry);
        } else {
            // Try looking up in the failed txs:
            // anyone should be able to do so, with no timeout
            _retryFailed(kappa);
        }
    }

    function retryCount(uint8 count) external onlyRole(LIMITER_ROLE) {
        // no issues casting to uint8 here. If length is greater then 255, min is always taken
        uint8 attempts = uint8(
            MathUpgradeable.min(uint256(count), rateLimitedQueue.length())
        );

        for (uint8 i = 0; i < attempts; i++) {
            // check out the first element
            (bytes32 kappa, bytes memory toRetry, ) = rateLimitedQueue
            .pop_front();

            if (toRetry.length > 0) {
                _retry(kappa, toRetry);
            }
        }
    }

    function _retry(bytes32 kappa, bytes memory toRetry) internal {
        (bool success, ) = BRIDGE_ADDRESS.call(toRetry);
        if (!success && !IBridge(BRIDGE_ADDRESS).kappaExists(kappa)) {
            // save payload for failed transactions
            // that haven't been processed by Bridge yet
            failedRetries[kappa] = toRetry;
        }
    }

    function _retryFailed(bytes32 kappa) internal {
        bytes memory toRetry = failedRetries[kappa];
        if (toRetry.length > 0) {
            failedRetries[kappa] = bytes("");
            (bool success, bytes memory returnData) = BRIDGE_ADDRESS.call(
                toRetry
            );
            require(
                success,
                string(
                    abi.encodePacked(
                        "Could not call bridge for kappa: ",
                        StringsUpgradeable.toHexString(uint256(kappa), 32),
                        " reverted with: ",
                        _getRevertMsg(returnData)
                    )
                )
            );
        }
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
