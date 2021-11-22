// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/Initializable.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import {SafeMath} from '@openzeppelin/contracts/math/SafeMath.sol';

import {IERC20Mintable} from './interfaces/IERC20Mintable.sol';

import {SynapseBridgeBase} from './bases/SynapseBridgeBase.sol';

contract SynapseBridge is Initializable, SynapseBridgeBase {
  using SafeERC20 for IERC20;
  using SafeERC20 for IERC20Mintable;
  using SafeMath  for uint256;
  
  function initialize() external initializer {
    __SynapseBridgeBase_init();
  }

  function _mint(
    address payable to,
    IERC20Mintable token,
    uint256 amount,
    uint256 fee,
    bytes32 kappa
  )
    internal
    override
  {
    _validateOutTxn(amount, fee, kappa);
    (,uint256 _amt) = _preOutTxn(token, amount, fee, kappa);

    emit TokenMint(to, token, _amt, fee, kappa);

    token.mint(address(this), amount);

    IERC20(token).safeTransfer(to, _amt);

    _gasDrop(to);
  }
}
