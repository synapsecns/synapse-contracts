// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

interface IERC20Mintable is IERC20 {
    function mint(address to, uint256 amount) external;
}

interface IStakedSYN {
    function distributeSYN() external;
}

contract StakingMinter is Ownable {
    using SafeMath for uint256;

    IERC20Mintable public immutable SYNAPSE;
    address public immutable STAKED_SYN;

    uint256 public synapsePerSecond;

    constructor(IERC20Mintable _synapse, address _sSYN) public {
        SYNAPSE = _synapse;
        STAKED_SYN = _sSYN;
    }

    /// @notice Set up SYN minting rate
    /// @param _rate minting rate, SYN per second
    function setSynapsePerSecond(uint256 _rate) external onlyOwner {
        require(_rate <= 1e18, "Minting rate too high");

        IStakedSYN(STAKED_SYN).distributeSYN();
        synapsePerSecond = _rate;
    }

    /// @notice Mint SYN to sSYN contract. Can only be called by sSYN.
    function stakingMint(uint256 lastMint)
        external
        returns (uint256 mintAmount)
    {
        require(msg.sender == STAKED_SYN, "Not sSYN");

        uint256 secondsElapsed = block.timestamp.sub(lastMint);
        mintAmount = secondsElapsed.mul(synapsePerSecond);

        SYNAPSE.mint(STAKED_SYN, mintAmount);
    }
}
