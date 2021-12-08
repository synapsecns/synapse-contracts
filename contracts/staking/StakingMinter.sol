// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IERC20Mintable is IERC20 {
  function mint(address to, uint256 amount) external;
}

interface SSYN {
    function distribute() external;
}

contract StakingMinter is Ownable {
    using SafeMath for uint256;
    IERC20Mintable public synapse;
    IERC20 public sSYN;
    uint256 public synapsePerSecond;

    constructor(IERC20Mintable _synapse, IERC20 _sSYN) public {
        synapse = _synapse;
        sSYN = _sSYN;
    }

    function setSynapsePerSecond(uint256 _rate) external onlyOwner {
        SSYN(address(sSYN)).distribute();
        synapsePerSecond = _rate;
    }

    function stakingMint(uint256 lastMint) external returns (uint256) {
        require(msg.sender == address(sSYN), 'not sSYN');
        uint256 secondsElapsed = block.timestamp - lastMint;
        uint256 mintAmount = secondsElapsed.mul(synapsePerSecond);
        synapse.mint(address(sSYN), mintAmount);
        return mintAmount;
    }
}