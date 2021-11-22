// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/Initializable.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import {SafeMath} from '@openzeppelin/contracts/math/SafeMath.sol';

import {IERC20Mintable} from './interfaces/IERC20Mintable.sol';
import {IFrax} from './interfaces/IFrax.sol';

import {SynapseBridgeBase} from './bases/SynapseBridgeBase.sol';


contract SynapseBridge is Initializable, SynapseBridgeBase {
  using SafeERC20 for IERC20;
  using SafeERC20 for IERC20Mintable;
  using SafeMath  for uint256;
  
  function initialize() external initializer {
    __SynapseBridgeBase_init();
  }

  address internal constant FRAX    = 0x1A93B23281CC1CDE4C4741353F3064709A16197d;
  address internal constant SYNFRAX = 0xE96AC70907ffF3Efee79f502C985A7A21Bce407d;

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
    (address _tokenAddress, uint256 _amt) = _preOutTxn(token, amount, fee, kappa);

    emit TokenMint(to, token, _amt, fee, kappa);

    token.mint(address(this), amount);

    // checks if synFRAX
    if (_tokenAddress == SYNFRAX)
    {
      token.safeIncreaseAllowance(FRAX, _amt);

      try IFrax(FRAX).exchangeOldForCanonical(_tokenAddress, _amt) returns (uint256 canolical_tokens_out)
      {
        IERC20(FRAX).safeTransfer(to, canolical_tokens_out);
      } catch
      {
        IERC20(token).safeTransfer(to, _amt);
      }
    } else
    {
      IERC20(token).safeTransfer(to, _amt);
    }

    _gasDrop(to);
  }
}
