// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';

import {ISwap} from '../interfaces/ISwap.sol';
import {IWETH9} from '../interfaces/IWETH9.sol';

import {ISynapseBridge} from '../interfaces/ISynapseBridge.sol';

contract L2BridgeZapBase {
    using SafeERC20 for IERC20;

    ISynapseBridge synapseBridge;
    address payable public immutable WETH_ADDRESS;

    mapping(address => address) public swapMap;
    mapping(address => IERC20[]) public swapTokensMap;

    uint256 constant MAX_UINT256 = 2**256 - 1;

    constructor(
        address payable _wethAddress,
        address _swapOne,
        address tokenOne,
        address _swapTwo,
        address tokenTwo,
        ISynapseBridge _synapseBridge
    ) {
        WETH_ADDRESS = _wethAddress;
        synapseBridge = _synapseBridge;
        swapMap[tokenOne] = _swapOne;
        swapMap[tokenTwo] = _swapTwo;

        if (address(_swapOne) != address(0)) {
            {
                uint8 i;
                for (; i < 32; i++) {
                    try ISwap(_swapOne).getToken(i) returns (
                        IERC20 token
                    ) {
                        swapTokensMap[_swapOne].push(token);
                        token.safeApprove(address(_swapOne), MAX_UINT256);
                        token.safeApprove(address(synapseBridge), MAX_UINT256);
                    } catch {
                        break;
                    }
                }
                require(i > 1, "swap must have at least 2 tokens");
            }
        }
        if (address(_swapTwo) != address(0)) {
            {
                uint8 i;
                for (; i < 32; i++) {
                    try ISwap(_swapTwo).getToken(i) returns (
                        IERC20 token
                    ) {
                        swapTokensMap[_swapTwo].push(token);
                        token.safeApprove(address(_swapTwo), MAX_UINT256);
                        token.safeApprove(address(synapseBridge), MAX_UINT256);
                    } catch {
                        break;
                    }
                }
                require(i > 1, "swap must have at least 2 tokens");
            }
        }
    }

    /**
     * @notice Calculate amount of tokens you receive on swap
     * @param tokenIndexFrom the token the user wants to sell
     * @param tokenIndexTo the token the user wants to buy
     * @param dx the amount of tokens the user wants to sell. If the token charges
     * a fee on transfers, use the amount that gets transferred after the fee.
     * @return amount of tokens the user will receive
     **/
    function calculateSwap(
        IERC20 token,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx
    )
        external
        virtual
        view
        returns (uint256)
    {
        ISwap swap = ISwap(
            swapMap[address(token)]
        );

        return swap.calculateSwap(tokenIndexFrom, tokenIndexTo, dx);
    }

    function swapAndRedeem(
        address to,
        uint256 chainId,
        IERC20 token,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx,
        uint256 minDy,
        uint256 deadline
    )
        external
    {
        uint256 swappedAmount = _swapOut(
            token,
            tokenIndexFrom,
            tokenIndexTo,
            dx,
            minDy,
            deadline
        );

        synapseBridge.redeem(to, chainId, token, swappedAmount);
    }

    function swapAndRedeemAndSwap(
        address to,
        uint256 chainId,
        IERC20 token,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx,
        uint256 minDy,
        uint256 deadline,
        uint8 swapTokenIndexFrom,
        uint8 swapTokenIndexTo,
        uint256 swapMinDy,
        uint256 swapDeadline
    )
        external
    {
        uint256 swappedAmount = _swapOut(
            token,
            tokenIndexFrom,
            tokenIndexTo,
            dx,
            minDy,
            deadline
        );

        synapseBridge.redeemAndSwap(
            to,
            chainId,
            token,
            swappedAmount,
            swapTokenIndexFrom,
            swapTokenIndexTo,
            swapMinDy,
            swapDeadline
        );
    }

    function swapAndRedeemAndRemove(
        address to,
        uint256 chainId,
        IERC20 token,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx,
        uint256 minDy,
        uint256 deadline,
        uint8 liqTokenIndex,
        uint256 liqMinAmount,
        uint256 liqDeadline
    )
        external
    {
        uint256 swappedAmount = _swapOut(
            token,
            tokenIndexFrom,
            tokenIndexTo,
            dx,
            minDy,
            deadline
        );

        synapseBridge.redeemAndRemove(
            to,
            chainId,
            token,
            swappedAmount,
            liqTokenIndex,
            liqMinAmount,
            liqDeadline
        );
    }

    /**
     * @notice wraps SynapseBridge redeem()
     * @param to address on other chain to redeem underlying assets to
     * @param chainId which underlying chain to bridge assets onto
     * @param token ERC20 compatible token to deposit into the bridge
     * @param amount Amount in native token decimals to transfer cross-chain pre-fees
     **/
    function deposit(
        address to,
        uint256 chainId,
        IERC20 token,
        uint256 amount
    )
        external
    {
        _safeTransferWithReapprove(token, amount);

        synapseBridge.deposit(to, chainId, token, amount);
    }

    function swapETHAndRedeem(
        address to,
        uint256 chainId,
        IERC20 token,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx,
        uint256 minDy,
        uint256 deadline
    )
        external
        payable
    {
        uint256 swappedAmount = _swapETHOut(
            token,
            tokenIndexFrom,
            tokenIndexTo,
            dx,
            minDy,
            deadline
        );

        synapseBridge.redeem(to, chainId, token, swappedAmount);
    }

    function swapETHAndRedeemAndSwap(
        address to,
        uint256 chainId,
        IERC20 token,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx,
        uint256 minDy,
        uint256 deadline,
        uint8 swapTokenIndexFrom,
        uint8 swapTokenIndexTo,
        uint256 swapMinDy,
        uint256 swapDeadline
    )
        external
        payable
    {
        uint256 swappedAmount = _swapETHOut(
            token,
            tokenIndexFrom,
            tokenIndexTo,
            dx,
            minDy,
            deadline
        );

        synapseBridge.redeemAndSwap(
            to,
            chainId,
            token,
            swappedAmount,
            swapTokenIndexFrom,
            swapTokenIndexTo,
            swapMinDy,
            swapDeadline
        );
    }

    /**
     * @notice Wraps redeemAndSwap on SynapseBridge.sol
     * Relays to nodes that (typically) a wrapped synAsset ERC20 token has been burned and the underlying needs to be redeeemed on the native chain. This function indicates to the nodes that they should attempt to redeem the LP token for the underlying assets (E.g "swap" out of the LP token)
     * @param to address on other chain to redeem underlying assets to
     * @param chainId which underlying chain to bridge assets onto
     * @param token ERC20 compatible token to deposit into the bridge
     * @param amount Amount in native token decimals to transfer cross-chain pre-fees
     * @param tokenIndexFrom the token the user wants to swap from
     * @param tokenIndexTo the token the user wants to swap to
     * @param minDy the min amount the user would like to receive, or revert to only minting the SynERC20 token crosschain.
     * @param deadline latest timestamp to accept this transaction
     **/
    function redeemAndSwap(
        address to,
        uint256 chainId,
        IERC20 token,
        uint256 amount,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 minDy,
        uint256 deadline
    )
        external
    {
        _safeTransferWithReapprove(token, amount);

        synapseBridge.redeemAndSwap(
            to,
            chainId,
            token,
            amount,
            tokenIndexFrom,
            tokenIndexTo,
            minDy,
            deadline
        );
    }

    /**
     * @notice Wraps redeemAndRemove on SynapseBridge
     * Relays to nodes that (typically) a wrapped synAsset ERC20 token has been burned and the underlying needs to be redeeemed on the native chain. This function indicates to the nodes that they should attempt to redeem the LP token for the underlying assets (E.g "swap" out of the LP token)
     * @param to address on other chain to redeem underlying assets to
     * @param chainId which underlying chain to bridge assets onto
     * @param token ERC20 compatible token to deposit into the bridge
     * @param amount Amount of (typically) LP token to pass to the nodes to attempt to removeLiquidity() with to redeem for the underlying assets of the LP token
     * @param liqTokenIndex Specifies which of the underlying LP assets the nodes should attempt to redeem for
     * @param liqMinAmount Specifies the minimum amount of the underlying asset needed for the nodes to execute the redeem/swap
     * @param liqDeadline Specificies the deadline that the nodes are allowed to try to redeem/swap the LP token
     **/
    function redeemAndRemove(
        address to,
        uint256 chainId,
        IERC20 token,
        uint256 amount,
        uint8 liqTokenIndex,
        uint256 liqMinAmount,
        uint256 liqDeadline
    )
        external
    {
        _safeTransferWithReapprove(token, amount);

        synapseBridge.redeemAndRemove(
            to,
            chainId,
            token,
            amount,
            liqTokenIndex,
            liqMinAmount,
            liqDeadline
        );
    }

    function _redeem(
        address to,
        uint256 chainId,
        IERC20 token,
        uint256 amount
    ) internal virtual;

    /**
     * @notice wraps SynapseBridge redeem()
     * @param to address on other chain to redeem underlying assets to
     * @param chainId which underlying chain to bridge assets onto
     * @param token ERC20 compatible token to deposit into the bridge
     * @param amount Amount in native token decimals to transfer cross-chain pre-fees
     **/
    function redeem(
        address to,
        uint256 chainId,
        IERC20 token,
        uint256 amount
    )
        external
    {
        _redeem(to, chainId, token, amount);
    }

    function _swapOut(
        IERC20 token,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx,
        uint256 minDy,
        uint256 deadline
    )
        internal
        returns (uint256)
    {
        (address _swapAddress, ISwap swap) = _getSwapFromParams(token);
        IERC20[] memory tokens = swapTokensMap[_swapAddress];

        tokens[tokenIndexFrom].safeTransferFrom(
            msg.sender,
            address(this),
            dx
        );

        uint256 swappedAmount = swap.swap(
            tokenIndexFrom,
            tokenIndexTo,
            dx,
            minDy,
            deadline
        );

        _reapproveMax(token, swappedAmount);

        return swappedAmount;
    }

    function _swapETHOut(
        IERC20 token,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx,
        uint256 minDy,
        uint256 deadline
    )
        internal
    {
        require(
            WETH_ADDRESS != address(0),
            "WETH 0"
        );

        require(
            msg.value > 0 && msg.value == dx,
            "INCORRECT MSG VALUE"
        );

        (,ISwap swap) = _getSwapFromParams(token);

        IWETH9(WETH_ADDRESS).deposit{value: msg.value}();

        // swap
        uint256 swappedAmount = swap.swap(
            tokenIndexFrom,
            tokenIndexTo,
            dx,
            minDy,
            deadline
        );

        return swappedAmount;
    }

    function _safeTransferWithReapprove(
        IERC20 token,
        uint256 amount
    )
        internal
    {
        token.safeTransferFrom(
            msg.sender,
            address(this),
            amount
        );

        _reapproveMax(token, amount);
    }

    function _reapproveMax(IERC20 token, uint256 amount)
        internal
    {
        address _thisAddress  = address(this);
        address _bridgeAddress = address(synapseBridge);

        // deposit into bridge, gets nUSD
        if (token.allowance(_thisAddress, _bridgeAddress) < amount)
        {
            token.safeApprove(_bridgeAddress, MAX_UINT256);
        }
    }

    function _getSwapFromParams(IERC20 token)
        internal
        returns (address, ISwap)
    {
        address _tokenAddress = address(token);
        address _swapAddress = swapMap[_tokenAddress];

        require(_swapAddress != address(0), "Swap is 0x00");

        ISwap swap = ISwap(_swapAddress);

        return (_swapAddress, swap);
    }
}
