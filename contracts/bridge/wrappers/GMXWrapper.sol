// SPDX-License-Identifier: MIT

import '@openzeppelin/contracts/math/SafeMath.sol';

pragma solidity 0.6.12;

interface IGMX {
    function burn(address _account, uint256 _amount) external;
    function balanceOf(address account) external view returns (uint256);
    function mint(address _account, uint256 _amount) external;
}

contract GMXWrapper {
    using SafeMath for uint256;

    address constant public gmx = 0x62edc0692BD897D2295872a9FFCac5425011c661;
    address constant public bridge = 0xC05e61d0E7a63D27546389B7aD62FdFf5A91aACE;

    function transfer(address _recipient, uint256 _amount) external returns (bool) {
        require(msg.sender == bridge);
        _transfer(msg.sender, _recipient, _amount);
        return true;
    }

    function _transfer(address _sender, address _recipient, uint256 _amount) private {
        require(_sender != address(0), "BaseToken: transfer from the zero address");
        require(_recipient != address(0), "BaseToken: transfer to the zero address");
        IGMX(gmx).burn(_sender, _amount);
        IGMX(gmx).mint(_recipient, _amount);
    }

    function mint(address _addr, uint256 _amount) external {
        require(msg.sender == bridge);
        uint256 preMint = IGMX(gmx).balanceOf(_addr);
        IGMX(gmx).mint(_addr, _amount);
        uint256 postMint = IGMX(gmx).balanceOf(_addr);
        require(preMint.add(_amount) == postMint, "Mint incomplete");
    }

    function burnFrom(address _addr, uint256 _amount) external {
        require(msg.sender == bridge);
        uint256 preBurn = IGMX(gmx).balanceOf(_addr);
        IGMX(gmx).burn(_addr, _amount);
        uint256 postBurn = IGMX(gmx).balanceOf(_addr);
        require(postBurn.add(_amount) == preBurn, "Burn incomplete");
    }
}