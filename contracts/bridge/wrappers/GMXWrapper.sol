// SPDX-License-Identifier: MIT

import '@openzeppelin/contracts/math/SafeMath.sol';

pragma solidity 0.6.12;

interface IGMX {
    function burn(address _account, uint256 _amount) external;
    function balanceOf(address account) external view returns (uint256);
}

contract GMXWrapper {
    using SafeMath for uint256;

    address constant gmx = 0x62edc0692BD897D2295872a9FFCac5425011c661;
    address constant bridge = 0xC05e61d0E7a63D27546389B7aD62FdFf5A91aACE;

    function burnFrom(address _addr, uint256 _amount) external {
        require(msg.sender == bridge);
        uint256 preBurn = IGMX(gmx).balanceOf(_addr);
        IGMX(gmx).burn(_addr, _amount);
        uint256 postBurn = IGMX(gmx).balanceOf(_addr);
        require(postBurn.add(_amount) == preBurn, "Burn incomplete");
    }
}