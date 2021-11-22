// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';

import {ISynapseBridge} from '../interfaces/ISynapseBridge.sol';

import {L2BridgeZapBase} from '../bases/L2BridgeZapBase.sol';

contract L2BridgeZap is L2BridgeZapBase {
    using SafeERC20 for IERC20;

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
        _safeTransferWithReapprove(token, amount);

        synapseBridge.redeem(to, chainId, token, amount);
    }
}
