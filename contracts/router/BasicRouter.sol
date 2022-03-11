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

    /// @notice Maximum amount of swaps for Bridge&Swap transaction
    /// It is enforced to limit the gas costs for validators on "expensive" chains
    /// There's no extra limitation for Swap&Bridge txs, as the gas is paid by the user
    uint8 public bridgeMaxSwaps;

    mapping(address => bool) public isTrustedAdapter;

    uint256 internal constant UINT_MAX = type(uint256).max;

    constructor(address payable _wgas, uint8 _bridgeMaxSwaps) {
        WGAS = _wgas;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(GOVERNANCE_ROLE, msg.sender);
        setBridgeMaxSwaps(_bridgeMaxSwaps);
    }

    // -- RECEIVE GAS --

    receive() external payable {
        // silence linter
        this;
    }

    // -- RESTRICTED SETTERS --

    function setBridgeMaxSwaps(uint8 _bridgeMaxSwaps)
        public
        onlyRole(GOVERNANCE_ROLE)
    {
        bridgeMaxSwaps = _bridgeMaxSwaps;
    }

    // -- RESTRICTED ADAPTER FUNCTIONS --

    function addTrustedAdapter(address _adapter)
        external
        onlyRole(ADAPTERS_STORAGE_ROLE)
    {
        isTrustedAdapter[_adapter] = true;
        emit AddedTrustedAdapter(_adapter);
    }

    function removeAdapter(address _adapter)
        external
        onlyRole(ADAPTERS_STORAGE_ROLE)
    {
        isTrustedAdapter[_adapter] = false;
        emit RemovedAdapter(_adapter);
    }

    function setAdapters(address[] calldata _adapters, bool _status)
        external
        onlyRole(ADAPTERS_STORAGE_ROLE)
    {
        for (uint8 i = 0; i < _adapters.length; ++i) {
            isTrustedAdapter[_adapters[i]] = _status;
        }
        emit UpdatedAdapters(_adapters, _status);
    }

    // -- RESTRICTED RECOVER TOKEN FUNCTIONS --

    function recoverERC20(address _tokenAddress)
        external
        onlyRole(GOVERNANCE_ROLE)
    {
        uint256 _tokenAmount = IERC20(_tokenAddress).balanceOf(address(this));
        require(_tokenAmount > 0, "Router: Nothing to recover");
        IERC20(_tokenAddress).safeTransfer(msg.sender, _tokenAmount);
        emit Recovered(_tokenAddress, _tokenAmount);
    }

    function recoverGAS() external onlyRole(GOVERNANCE_ROLE) {
        uint256 _amount = address(this).balance;
        require(_amount > 0, "Router: Nothing to recover");
        payable(msg.sender).transfer(_amount);
        emit Recovered(address(0), _amount);
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
     * @param _token address
     * @param _amount tokens to return
     * @param _to address where funds should be sent to
     */
    function _returnTokensTo(
        address _token,
        uint256 _amount,
        address _to
    ) internal {
        if (address(this) != _to) {
            if (_token == WGAS) {
                _unwrap(_amount);
                // solhint-disable-next-line
                (bool success, ) = _to.call{value: _amount}("");
                require(success, "GAS transfer failed");
            } else {
                IERC20(_token).safeTransfer(_to, _amount);
            }
        }
    }

    function _wrap(uint256 _amount) internal {
        IWETH9(WGAS).deposit{value: _amount}();
    }

    function _unwrap(uint256 _amount) internal {
        IWETH9(WGAS).withdraw(_amount);
    }
}
