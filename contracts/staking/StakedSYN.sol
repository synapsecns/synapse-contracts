// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";

interface IMinter {
    function stakingMint(uint256 lastMint) external returns (uint256);
}

contract StakedSYN is Ownable, ERC20("Staked Synapse", "sSYN") {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 public immutable SYNAPSE;
    IMinter public STAKING_MINTER;

    // Tracks active delegated SYN backing sSYN
    uint256 internal totalActiveSYN;
    // Last timestamp of SYN distributed to contract
    uint256 internal lastSynMint;

    // Tracks when SYN can be unstaked, along with amounts at time of unstake
    mapping(address => uint256) public undelegatedTimestamps;
    mapping(address => uint256) public undelegatedSynapseAmounts;

    // Define the Synapse token contract
    constructor(IERC20 _synapse, uint256 _stakingStart) public {
        SYNAPSE = _synapse;
        lastSynMint = _stakingStart;
    }

    /*** RESTRICTED FUNCTIONS ***/

    function setStakingMinter(address _minter) external onlyOwner {
        STAKING_MINTER = IMinter(_minter);
    }

    /*** VIEW FUNCTIONS ***/

    function getStakedSynapseValue() external view returns (uint256) {
        uint256 totalStaked = totalSupply();
        uint256 precision = 10**18;
        if (totalStaked == 0) {
            return precision;
        } else {
            return precision.mul(totalActiveSYN).div(totalStaked);
        }
    }

    function undelegatedSynapse(address _user)
        external
        view
        returns (uint256 amount, uint256 timestamp)
    {
        return (undelegatedSynapseAmounts[_user], undelegatedTimestamps[_user]);
    }

    function underlyingBalanceOf(address _user)
        external
        view
        returns (uint256)
    {
        return
            _getUnderlyingSynapseAmount(balanceOf(_user)) +
            undelegatedSynapseAmounts[_user];
    }

    function _getUnderlyingSynapseAmount(uint256 _amount)
        internal
        view
        returns (uint256)
    {
        uint256 totalStaked = totalSupply();
        return
            totalStaked > 0 ? _amount.mul(totalActiveSYN).div(totalStaked) : 0;
    }

    /*** STATE CHANGING FUNCTIONS ***/

    function distributeSYN() public {
        if (totalSupply() != 0) {
            uint256 lastMint = lastSynMint;
            if (block.timestamp >= lastMint.add(1 hours)) {
                lastSynMint = block.timestamp;
                uint256 mintAmount = STAKING_MINTER.stakingMint(lastMint);
                totalActiveSYN = totalActiveSYN.add(mintAmount);
            }
        }
    }

    // Enter the bar. Give some SYN. Get some sSYN.
    // Locks Synapse and mints sSYN
    function stake(uint256 _amount) external {
        require(_amount > 0, "Can't stake zero tokens");

        // Pull SYN from caller
        SYNAPSE.safeTransferFrom(msg.sender, address(this), _amount);

        // Catch up on
        distributeSYN();

        // If no sSYN exists, mint it 1:1 to the amount put in
        if (totalActiveSYN == 0) {
            _mint(msg.sender, _amount);
        }
        // Calculate and mint the amount of sSYN the SYN is worth.
        // The ratio will change overtime, as sSYN is burned/minted and more SYN is added.
        else {
            uint256 totalStaked = totalSupply();
            uint256 stakedAmount = _amount.mul(totalStaked).div(totalActiveSYN);
            _mint(msg.sender, stakedAmount);
        }
        // Lock the sSYN in the contract
        totalActiveSYN = totalActiveSYN.add(_amount);
    }

    // Initiate 7d undelegation period, locks amount of SYN at time of undelegation request, burn sSYN
    function undelegate(uint256 _amount) external {
        require(balanceOf(msg.sender) >= _amount, "Balance not met");
        require(_amount > 0, "Can't undelegate zero tokens");

        // Catch up on
        distributeSYN();

        // Undelegate

        // Calculates the amount of SYN the sSYN is worth at the time of undelegate
        uint256 underlyingSynapseAmount = _getUnderlyingSynapseAmount(_amount);
        // If undelegate was called previously within past 7days, add amount to previous. Replace timestamp fully.
        undelegatedSynapseAmounts[msg.sender] = undelegatedSynapseAmounts[
            msg.sender
        ].add(underlyingSynapseAmount);
        undelegatedTimestamps[msg.sender] = block.timestamp.add(7 days);

        // locks SYN for given undelegated amount, reduces active staking
        totalActiveSYN = totalActiveSYN.sub(underlyingSynapseAmount);
        // burns sSYN shares
        _burn(msg.sender, _amount);
    }

    // Unlocks SYN after 7d undelegate period
    function unstake() external {
        require(undelegatedTimestamps[msg.sender] > 0, "Nothing to unstake");
        require(
            block.timestamp > undelegatedTimestamps[msg.sender],
            "Undelegate period not reached"
        );
        // Catch up on
        distributeSYN();

        uint256 undelegatedSynapseAmount = undelegatedSynapseAmounts[
            msg.sender
        ];
        // resets undelegate state
        undelegatedTimestamps[msg.sender] = 0;
        undelegatedSynapseAmounts[msg.sender] = 0;
        // transfer underlying SYN from time of undelegate
        SYNAPSE.safeTransfer(msg.sender, undelegatedSynapseAmount);
    }
}
