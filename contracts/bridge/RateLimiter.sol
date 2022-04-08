// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-4.3.1-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-4.3.1-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-4.3.1-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-4.3.1-upgradeable/utils/math/MathUpgradeable.sol";

import "./libraries/EnumerableMapUpgradeable.sol";
import "./interfaces/IRateLimiter.sol";

// @title RateLimiter
// @dev a bridge asset rate limiter based on https://github.com/gnosis/safe-modules/blob/master/allowances/contracts/AlowanceModule.sol
contract RateLimiter is
    Initializable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    IRateLimiter
{
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
    EnumerableMapUpgradeable.Bytes32ToBytesMap private limited;
    // Bridge Address
    address public BRIDGE_ADDRESS;

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
    }

    function setBridgeAddress(address bridge)
        external
        onlyRole(GOVERNANCE_ROLE)
    {
        BRIDGE_ADDRESS = bridge;
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
    ) public onlyRole(LIMITER_ROLE) {
        Allowance memory allowance = getAllowance(token);
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
        updateAllowance(token, allowance);
        emit SetAllowance(token, allowanceAmount, resetTimeMin);
    }

    function updateAllowance(address token, Allowance memory allowance)
        private
    {
        allowances[token] = allowance;
    }

    function getAllowance(address token)
        private
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
        Allowance memory allowance = getAllowance(token);

        // Update state
        // @dev reverts if amount > (2^96 - 1)
        uint96 newSpent = allowance.spent + uint96(amount);

        // Check overflow
        require(
            newSpent > allowance.spent,
            "overflow detected: newSpent > allowance.spent"
        );

        // do not proceed. Store the transaction for later
        if (newSpent >= allowance.amount) {
            return false;
        }

        allowance.spent = newSpent;
        updateAllowance(token, allowance);

        return true;
    }

    function addToRetryQueue(bytes32 kappa, bytes memory rateLimited)
        external
        onlyRole(BRIDGE_ROLE)
    {
        EnumerableMapUpgradeable.set(limited, kappa, rateLimited);
    }

    function retryByKappa(bytes32 kappa) external onlyRole(LIMITER_ROLE) {
        bytes memory toRetry = EnumerableMapUpgradeable.get(limited, kappa);
        (bool success, bytes memory returnData) = BRIDGE_ADDRESS.call(toRetry);
        require(success, "could not call bridge");
        EnumerableMapUpgradeable.remove(limited, kappa);
    }

    function retryCount(uint8 count) external onlyRole(LIMITER_ROLE) {
        // no issues casting to uint8 here. If length is greater then 255, min is always taken
        uint8 attempts = uint8(
            MathUpgradeable.min(
                uint256(count),
                EnumerableMapUpgradeable.length(limited)
            )
        );

        for (uint8 i = 0; i < attempts; i++) {
            (bytes32 kappa, bytes memory toRetry) = EnumerableMapUpgradeable.at(
                limited,
                i
            );
            (bool success, bytes memory returnData) = BRIDGE_ADDRESS.call(
                toRetry
            );
            require(success, "could not call bridge");
            EnumerableMapUpgradeable.remove(limited, kappa);
        }
    }

    function deleteByKappa(bytes32 kappa) external onlyRole(LIMITER_ROLE) {
        EnumerableMapUpgradeable.remove(limited, kappa);
    }

    /**
     * @notice Gets a  list of tokens with allowances
     **/
    function getTokens() public view returns (address[] memory) {
        return tokens;
    }

    function resetAllowance(address token) public onlyRole(LIMITER_ROLE) {
        Allowance memory allowance = getAllowance(token);
        allowance.spent = 0;
        updateAllowance(token, allowance);
        emit ResetAllowance(token);
    }

    function getTokenAllowance(address token)
        public
        view
        returns (uint256[4] memory)
    {
        Allowance memory allowance = getAllowance(token);
        return [
            uint256(allowance.amount),
            uint256(allowance.spent),
            uint256(allowance.resetTimeMin),
            uint256(allowance.lastResetMin)
        ];
    }
}
