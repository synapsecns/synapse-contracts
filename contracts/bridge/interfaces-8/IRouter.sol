// SPDX-License-Identifier: MIT 

pragma solidity 0.8.11;

interface IRouter { 
      
  function selfSwap(
        uint256 amountIn,
        uint256 amountOut,
        address[] calldata path,
        address[] calldata adapters,
        address _to,
        uint256 _fee
  ) external;
}