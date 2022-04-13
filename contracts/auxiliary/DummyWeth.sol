// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
import "@openzeppelin/contracts/access/Ownable.sol";

interface IWETH9 {
  function name() external view returns (string memory);

  function symbol() external view returns (string memory);

  function decimals() external view returns (uint8);

  function balanceOf(address) external view returns (uint256);

  function allowance(address, address) external view returns (uint256);

  receive() external payable;

  function deposit() external payable;

  function withdraw(uint256 wad) external;

  function totalSupply() external view returns (uint256);

  function approve(address guy, uint256 wad) external returns (bool);

  function transfer(address dst, uint256 wad) external returns (bool);

  function transferFrom(
    address src,
    address dst,
    uint256 wad
  ) external returns (bool);
}

contract DummyWeth is Ownable {
  IWETH9 public WETH;

  function setWETHAddress(address payable _weth) external onlyOwner {
    WETH = IWETH9(_weth);
  }

  function withdrawToSelf(uint256 amount) external {
    WETH.withdraw(amount);
  }

  function rescue(uint256 amount) external onlyOwner {
    WETH.transfer(owner(), amount);
  }

  receive() external payable {}

  fallback() external payable {}
}
