// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IBasicRouter} from "./interfaces/IBasicRouter.sol";

import {IERC20} from "@synapseprotocol/sol-lib/contracts/solc8/erc20/IERC20.sol";
import {IWETH9} from "@synapseprotocol/sol-lib/contracts/universal/interfaces/IWETH9.sol";
import {SafeERC20} from "@synapseprotocol/sol-lib/contracts/solc8/erc20/SafeERC20.sol";

import {AccessControl} from "@openzeppelin/contracts-4.4.2/access/AccessControl.sol";

contract BasicRouter is AccessControl, IBasicRouter {
    using SafeERC20 for IERC20;

    /// @notice Members of this role can add/remove trusted Adapters
    bytes32 public constant ADAPTERS_STORAGE_ROLE =
        keccak256("ADAPTERS_STORAGE_ROLE");

    /// @notice Members of this role can rescue funds from this contract
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");

    /// @dev This is address of contract representing
    /// wrapped ERC20 version of a chain's native currency (ex. WETH, WAVAX, WMOVR)
    // solhint-disable-next-line
    address payable public immutable WGAS;

    mapping(address => bool) public isTrustedAdapter;

    uint256 internal constant UINT_MAX = type(uint256).max;

    constructor(address payable _wgas) {
        WGAS = _wgas;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(GOVERNANCE_ROLE, msg.sender);
    }

    // -- RECEIVE GAS --

    receive() external payable {
        // silence linter
        this;
    }

    // -- RESTRICTED ADAPTER FUNCTIONS --

    function addTrustedAdapter(address adapter)
        external
        onlyRole(ADAPTERS_STORAGE_ROLE)
    {
        isTrustedAdapter[adapter] = true;
        emit AddedTrustedAdapter(adapter);
    }

    function removeAdapter(address adapter)
        external
        onlyRole(ADAPTERS_STORAGE_ROLE)
    {
        isTrustedAdapter[adapter] = false;
        emit RemovedAdapter(adapter);
    }

    function setAdapters(address[] calldata adapters, bool status)
        external
        onlyRole(ADAPTERS_STORAGE_ROLE)
    {
        for (uint8 i = 0; i < adapters.length; ++i) {
            isTrustedAdapter[adapters[i]] = status;
        }
        emit UpdatedAdapters(adapters, status);
    }

    // -- RESTRICTED RECOVER TOKEN FUNCTIONS --

    function recoverERC20(IERC20 token) external onlyRole(GOVERNANCE_ROLE) {
        uint256 amount = token.balanceOf(address(this));
        require(amount > 0, "Adapter: Nothing to recover");

        emit Recovered(address(token), amount);
        token.safeTransfer(msg.sender, amount);
    }

    function recoverGAS() external onlyRole(GOVERNANCE_ROLE) {
        uint256 amount = address(this).balance;
        require(amount > 0, "Adapter: Nothing to recover");

        emit Recovered(address(0), amount);
        //solhint-disable-next-line
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "GAS transfer failed");
    }

    // -- INTERNAL HELPERS --

    /**
     * @notice Return tokens to user
     *
     * @dev Pass WGAS address to unwrap it and return GAS to user
     *      Make sure to either 
            1. Return WGAS as last operation to avoid reentrancy issues
            2. Add nonReentrant modifier otherwise
     *
     * @param token address
     * @param amount tokens to return
     * @param to address where funds should be sent to
     */
    function _returnTokensTo(
        address to,
        IERC20 token,
        uint256 amount
    ) internal {
        if (address(this) != to) {
            if (address(token) == WGAS) {
                _unwrap(amount);
                // solhint-disable-next-line
                (bool success, ) = to.call{value: amount}("");
                require(success, "GAS transfer failed");
            } else {
                token.safeTransfer(to, amount);
            }
        }
    }

    function _wrap(uint256 amount) internal {
        IWETH9(WGAS).deposit{value: amount}();
    }

    function _unwrap(uint256 amount) internal {
        IWETH9(WGAS).withdraw(amount);
    }
}
