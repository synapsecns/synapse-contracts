// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IBasicRouter} from "./interfaces/IBasicRouter.sol";

import {IERC20} from "@synapseprotocol/sol-lib/contracts/solc8/erc20/IERC20.sol";
import {IWETH9} from "@synapseprotocol/sol-lib/contracts/universal/interfaces/IWETH9.sol";
import {SafeERC20} from "@synapseprotocol/sol-lib/contracts/solc8/erc20/SafeERC20.sol";

import {Ownable} from "@openzeppelin/contracts-4.4.2/access/Ownable.sol";

contract BasicRouter is Ownable, IBasicRouter {
    using SafeERC20 for IERC20;

    /// @dev This is address of contract representing
    /// wrapped ERC20 version of a chain's native currency (ex. WETH, WAVAX, WMOVR)
    address payable public immutable WGAS;

    address[] public trustedAdapters;
    mapping(address => bool) public isTrustedAdapter;

    uint256 internal constant UINT_MAX = type(uint256).max;

    constructor(address[] memory _adapters, address payable _wgas) {
        WGAS = _wgas;
        setAdapters(_adapters);
    }

    // -- FALLBACK --

    receive() external payable {
        // silence linter
        this;
    }

    //  -- VIEWS --

    function getTrustedAdapter(uint256 _index) external view returns (address) {
        require(_index < trustedAdapters.length, "Index out of range");
        return trustedAdapters[_index];
    }

    function trustedAdaptersCount() external view returns (uint256) {
        return trustedAdapters.length;
    }

    // -- RESTRICTED ADAPTER FUNCTIONS --

    function addTrustedAdapter(address _adapter) external onlyOwner {
        trustedAdapters.push(_adapter);
        isTrustedAdapter[_adapter] = true;
        emit AddedTrustedAdapter(_adapter);
    }

    function removeAdapter(address _adapter) external onlyOwner {
        for (uint256 i = 0; i < trustedAdapters.length; i++) {
            if (trustedAdapters[i] == _adapter) {
                _removeAdapterByIndex(i);
                return;
            }
        }
        revert("Adapter not found");
    }

    function removeAdapterByIndex(uint256 _index) external onlyOwner {
        _removeAdapterByIndex(_index);
    }

    function setAdapters(address[] memory _adapters) public onlyOwner {
        emit UpdatedTrustedAdapters(_adapters);
        _saveAdapters(false);
        trustedAdapters = _adapters;
        _saveAdapters(true);
    }

    // -- RESTRICTED RECOVER TOKEN FUNCTIONS --

    function recoverERC20(address _tokenAddress) external onlyOwner {
        uint256 _tokenAmount = IERC20(_tokenAddress).balanceOf(address(this));
        require(_tokenAmount > 0, "Router: Nothing to recover");
        IERC20(_tokenAddress).safeTransfer(msg.sender, _tokenAmount);
        emit Recovered(_tokenAddress, _tokenAmount);
    }

    function recoverGAS() external onlyOwner {
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

    // -- PRIVATE FUNCTIONS

    function _removeAdapterByIndex(uint256 _index) private {
        require(_index < trustedAdapters.length, "Index out of range");
        address _removedAdapter = trustedAdapters[_index];
        emit RemovedAdapter(_removedAdapter);
        // We don't care about adapters order, so we replace the
        // selected adapter with the last one
        trustedAdapters[_index] = trustedAdapters[trustedAdapters.length - 1];
        trustedAdapters.pop();
        // mark removed adapter as non-trusted
        isTrustedAdapter[_removedAdapter] = false;
    }

    function _saveAdapters(bool _status) private {
        for (uint256 i = 0; i < trustedAdapters.length; i++) {
            isTrustedAdapter[trustedAdapters[i]] = _status;
        }
    }
}
