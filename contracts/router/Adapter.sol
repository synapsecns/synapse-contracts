// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IAdapter} from "./interfaces/IAdapter.sol";

import {IERC20} from "@synapseprotocol/sol-lib/contracts/solc8/erc20/IERC20.sol";
import {IWETH9} from "@synapseprotocol/sol-lib/contracts/universal/interfaces/IWETH9.sol";
import {SafeERC20} from "@synapseprotocol/sol-lib/contracts/solc8/erc20/SafeERC20.sol";

import {Ownable} from "@openzeppelin/contracts-4.4.2/access/Ownable.sol";

abstract contract Adapter is Ownable, IAdapter {
    using SafeERC20 for IERC20;

    string public name;
    uint256 public swapGasEstimate;

    uint256 internal constant UINT_MAX = type(uint256).max;

    constructor(string memory _name, uint256 _swapGasEstimate) {
        name = _name;
        setSwapGasEstimate(_swapGasEstimate);
    }

    /**
     * @notice Fallback function
     * @dev use recoverGAS() to recover GAS sent to this contract
     */
    receive() external payable {
        // silence the linter
        this;
    }

    /// @dev this is estimated amount of gas that's used by swap() implementation
    function setSwapGasEstimate(uint256 _estimate) public onlyOwner {
        swapGasEstimate = _estimate;
        emit UpdatedGasEstimate(address(this), _estimate);
    }

    /**
     * @notice Revoke token allowance
     *
     * @param _token address
     * @param _spender address
     */
    function revokeAllowance(address _token, address _spender)
        external
        onlyOwner
    {
        IERC20 _t = IERC20(_token);
        _t.safeApprove(_spender, 0);
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

    /**
     * @return Address to transfer tokens in order for swap() to work
     */

    function depositAddress(address _tokenIn, address _tokenOut)
        external
        view
        returns (address)
    {
        return _depositAddress(_tokenIn, _tokenOut);
    }

    /**
     * @notice Get query for a swap through this adapter
     *
     * @param _amountIn input amount in starting token
     * @param _tokenIn ERC20 token being sold
     * @param _tokenOut ERC20 token being bought
     */
    function query(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut
    ) external view returns (uint256) {
        if (_amountIn == 0 || !_checkTokens(_tokenIn, _tokenOut)) {
            return 0;
        }
        return _query(_amountIn, _tokenIn, _tokenOut);
    }

    /**
     * @notice Execute a swap with given input amount of tokens from tokenIn to tokenOut,
     *         assuming input tokens were transferred to depositAddress(_tokenIn, _tokenOut)
     *
     * @param _amountIn input amount in starting token
     * @param _tokenIn ERC20 token being sold
     * @param _tokenOut ERC20 token being bought
     * @param _to address where swapped funds should be sent to
     *
     * @return _amountOut amount of _tokenOut tokens received in swap
     */
    function swap(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut,
        address _to
    ) external returns (uint256 _amountOut) {
        require(_amountIn != 0, "Adapter: Insufficient input amount");
        require(_to != address(0), "Adapter: Null address receiver");
        require(_checkTokens(_tokenIn, _tokenOut), "Adapter: unknown tokens");
        _approveIfNeeded(_tokenIn, _amountIn);
        _amountOut = _swap(_amountIn, _tokenIn, _tokenOut, _to);
        emit AdapterSwap(_tokenIn, _tokenOut, _amountIn, _amountOut);
    }

    // -- INTERNAL FUNCTIONS

    /**
     * @notice Return expected funds to user
     *
     * @dev this will do nothing, if funds need to stay in this contract
     *
     * @param _token address
     * @param _amount tokens to return
     * @param _to address where funds should be sent to
     */
    function _returnTo(
        address _token,
        uint256 _amount,
        address _to
    ) internal {
        if (address(this) != _to) {
            IERC20(_token).safeTransfer(_to, _amount);
        }
    }

    /**
     * @notice Check allowance, and update if it is not big enough
     *
     * @param _token token to check
     * @param _amount minimum allowance that we need
     * @param _spender address that will be given allowance
     */
    function _checkAllowance(
        IERC20 _token,
        uint256 _amount,
        address _spender
    ) internal {
        uint256 _allowance = _token.allowance(address(this), _spender);
        if (_allowance < _amount) {
            // safeApprove should only be called when setting an initial allowance,
            // or when resetting it to zero. (c) openzeppelin
            if (_allowance != 0) {
                _token.safeApprove(_spender, 0);
            }
            _token.safeApprove(_spender, UINT_MAX);
        }
    }

    // -- INTERNAL VIRTUAL FUNCTIONS

    /**
     * @notice Approves token for the underneath swapper to use
     *
     * @dev Implement via _checkAllowance(_tokenIn, _amount, POOL)
     *
     * @param _tokenIn ERC20 token to approve
     * @param _amount token amount to approve
     */
    function _approveIfNeeded(address _tokenIn, uint256 _amount)
        internal
        virtual;

    /**
     * @notice Checks if a swap between two tokens is supported by adapter
     * @param _tokenIn ERC20 token to check
     * @param _tokenOut ERC20 token to check
     */
    function _checkTokens(address _tokenIn, address _tokenOut)
        internal
        view
        virtual
        returns (bool);

    /**
     * @notice Internal implementation for depositAddress
     *
     * @dev This aims to reduce the amount of extra token transfers:
     *      some (1) of underneath swappers will have the ability to receive tokens and then swap,
     *      while some (2) will only be able to pull tokens while swapping.
     *      Use swapper address for (1) and Adapter address for (2)
     */
    function _depositAddress(address _tokenIn, address _tokenOut)
        internal
        view
        virtual
        returns (address);

    /**
     * @notice Internal implementation of a swap
     *
     * @dev 1. All variables are already checked
     *      2. Use _returnTo(_tokenOut, _amountOut, _to) to return tokens, only if
     *         underneath swapper can't send swapped tokens to arbitrary address.
     *      3. Wrapping is handled external to this function
     *
     * @param _amountIn amount being sold
     * @param _tokenIn ERC20 token being sold
     * @param _tokenOut ERC20 token being bought
     * @param _to Where received tokens are sent to
     *
     * @return Amount of _tokenOut tokens received in swap
     */
    function _swap(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut,
        address _to
    ) internal virtual returns (uint256);

    /**
     * @notice Internal implementation of query
     *
     * @dev All variables are already checked.
     *      This should ALWAYS return _amountOut such as: the swapper underneath
     *      is able to produce AT LEAST _amountOut in exchange for EXACTLY _amountIn
     *      For efficiency reasons, returning the exact quote is preferable,
     *      however, if the swapper doesn't have a reliable quoting method,
     *      it's safe to underquote the swapped amount
     *
     * @param _amountIn input amount in starting token
     * @param _tokenIn ERC20 token being sold
     * @param _tokenOut ERC20 token being bought
     */
    function _query(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut
    ) internal view virtual returns (uint256);
}
