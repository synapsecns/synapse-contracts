// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';

import {ISynapseBridge} from '../interfaces/ISynapseBridge.sol';

import {IFrax} from '../interfaces/IFrax.sol';
import {LibFrax} from '../libraries/LibFrax.sol';

import {L2BridgeZapBase} from '../bases/L2BridgeZapBase.sol';

contract MoonriverBridgeZap is L2BridgeZapBase {
    using SafeERC20 for IERC20;

    IFrax private  constant CANOLICAL_FRAX = IFrax(LibFrax.FRAX);
    IERC20 private constant SYN_FRAX = IERC20(LibFrax.SYNFRAX);

    constructor(
        address payable _wethAddress,
        address _swapOne,
        address tokenOne,
        address _swapTwo,
        address tokenTwo,
        ISynapseBridge _synapseBridge
    ) L2BridgeZapBase(
        _wethAddress,
        _swapOne,
        tokenOne,
        _swapTwo,
        tokenTwo,
        _synapseBridge
    ) {}

    function _redeem(
        address to,
        uint256 chainId,
        IERC20 token,
        uint256 amount
    )
        internal
        override
    {
        token.safeTransferFrom(msg.sender, address(this), amount);

        if (address(token) == LibFrax.FRAX) {
            uint256 swappedAmount = CANOLICAL_FRAX.exchangeCanonicalForOld(LibFrax.SYNFRAX, amount);

            _doRedeem(to, chainId, SYN_FRAX, swappedAmount);
        } else {
            _doRedeem(to, chainId, token, amount);
        }
    }

    function _doRedeem(
        address to,
        uint256 chainId,
        IERC20 token,
        uint256 amount
    )
        internal
    {
        _reapproveMax(token, amount);

        synapseBridge.redeem(to, chainId, token, amount);
    }
}
