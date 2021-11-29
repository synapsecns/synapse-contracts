// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

interface IMinter {
    function stakingMint(uint256 lastMint) external returns(uint256);
}

contract StakedSYN is Ownable, ERC20("Staked Synapse", "sSYN") {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    IERC20 public synapse;
    IMinter public STAKING_MINTER;
    // Tracks actively staked sSYN. This amounts to totalSupply() - requested unstake total
    uint256 internal activeStaked;
    // Tracks active delegated SYN backing sSYN
    uint256 internal activeSYN;

    // Last timestamp of SYN distributed to contract
    uint256 internal lastSynMint;
    
    // Tracks when SYN can be unstaked, along with amounts at time of launch
    mapping(address => uint256) public undelegateTimestamps;
    mapping(address => uint256) public undelegateUnderlyingAmounts;

    // Define the Synapse token contract
    constructor(IERC20 _synapse, uint256 _stakingStart) public {
        synapse = _synapse;
        lastSynMint = _stakingStart;
    } 

    /*** RESTRICTED FUNCTIONS ***/

    function setStakingMinter(address _minter) external onlyOwner {
        STAKING_MINTER = IMinter(_minter);
    }

    /*** VIEW FUNCTIONS ***/

    function undelegatedSynapse(address user) external view returns(uint256 amount, uint256 timestamp) {
        return (undelegateUnderlyingAmounts[user], undelegateTimestamps[user]);
    }

    function underlyingBalanceOf(address user) external view returns(uint256) {
        if (undelegateTimestamps[user] != 0) {
            return undelegateUnderlyingAmounts[user];
        } else {
            return balanceOf(user).mul(activeSYN).div(totalSupply());
        }
    }

    function distribute() public {
        uint256 lastMint = lastSynMint;
        if (block.timestamp >= lastMint.add(1 hours)) {
            lastSynMint = block.timestamp;
            uint256 mintAmount = STAKING_MINTER.stakingMint(lastMint);
            activeSYN = activeSYN.add(mintAmount);
        }
    }

    // Enter the bar. Give some SYN. Get some sSYN.
    // Locks Synapse and mints sSYN
    function stake(uint256 _amount) external {
        // Catch up on 
        distribute();

        uint256 totalStaked = totalSupply();
        // If no sSYN exists, mint it 1:1 to the amount put in
        if (totalStaked == 0 || activeSYN == 0) {
            _mint(msg.sender, _amount);
        } 
        // Calculate and mint the amount of sSYN the SYN is worth. The ratio will change overtime, as sSYN is burned/minted and more SYN is added.
        else {
            uint256 stakedAmount = _amount.mul(totalStaked).div(activeSYN);
            _mint(msg.sender, stakedAmount);
        }
        // Lock the sSYN in the contract
        activeSYN = activeSYN.add(_amount);
        synapse.safeTransferFrom(msg.sender, address(this), _amount);        
    }

    // Initiate 7d undelegation period, locks amount of SYN at time of undelegatation request, burn sSYN
    function undelegate(uint256 _amount) external {
        require(balanceOf(msg.sender) >= _amount, "Balance not met");
        distribute();
        // Undelegate 
        undelegateTimestamps[msg.sender] = block.timestamp.add(7 days);
        // Calculates the amount of SYN the sSYN is worth at the time of undelegate
        uint256 totalStaked = totalSupply();
        uint256 underlyingUnderlyingAmount = _amount.mul(activeSYN).div(totalStaked);
        // If undelegate was called previously within past 7days, add amount to previous. Replace timestap fully.
        undelegateUnderlyingAmounts[msg.sender] += underlyingUnderlyingAmount;
        // locks SYN for given undelegated amount, reduces active staking
        activeSYN = activeSYN.sub(underlyingUnderlyingAmount);
        // burns sSYN shares
        _burn(msg.sender, _amount);
    }

    // Unlocks SYN after 7d undelegate period, and burns sSYN
    function unstake() external {
        distribute();
        require(block.timestamp > undelegateTimestamps[msg.sender], 'Undelegate period not reached');
        uint256 undelegateUnderlyingAmount = undelegateUnderlyingAmounts[msg.sender];
        // resets undelegate state
        undelegateTimestamps[msg.sender] = 0;
        undelegateUnderlyingAmounts[msg.sender] = 0;
        // transfer underlying SYN from time of undelegate
        synapse.safeTransfer(msg.sender, undelegateUnderlyingAmount);
    }
}