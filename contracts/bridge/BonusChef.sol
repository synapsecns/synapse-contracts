// SPDX-License-Identifier: ISC

pragma solidity 0.6.12;

import '@openzeppelin/contracts/utils/ReentrancyGuard.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/math/Math.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';
import "./interfaces/IMiniChefV2.sol";

// A farm contract to distribute rewards based on user balance of parent farm.
// Modified from Oolongswap staking reward contract at https://blockexplorer.boba.network/address/0x44c7d93ef2b3d9bbecb944b7a6343f9aed4af09b/contracts
// with the following changes:
// - Made abstract
// - Remove stake and withdraw
// - getReward use input address instead of msg.sender
// - Read staking balance from parent farm
// - notifyRewardAmount updated to transferFrom msg.sender instead of using permissioned distributor
contract BonusChef is ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /* ========== STATE VARIABLES ========== */
    IERC20 public rewardsToken;
    uint256 public periodFinish = 0;
    uint256 public rewardRate = 0;
    uint256 public rewardsDuration;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;


    address public governance;
    IMiniChefV2 private parentFarm;
    uint private parentPoolId;
    IERC20 private parentStakingToken;
    uint public startTime; // only used in UI

    /* ========== CONSTRUCTOR ========== */

    constructor(
        address _rewardsToken,
        uint _rewardsDuration,
        IMiniChefV2 _parentFarm,
        uint _parentPoolId,
        address _governance
    ) public {
        rewardsToken = IERC20(_rewardsToken);
        rewardsDuration = _rewardsDuration;

        parentFarm = _parentFarm;
        parentPoolId = _parentPoolId;
        parentStakingToken = _parentFarm.lpToken(_parentPoolId);
        governance = _governance;
    }

    /* ========== VIEWS ========== */
    function lastTimeRewardApplicable() public view returns (uint256) {
        return Math.min(block.timestamp, periodFinish);
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalSupply() == 0) {
            return rewardPerTokenStored;
        }
        return
        rewardPerTokenStored.add(
            lastTimeRewardApplicable().sub(lastUpdateTime).mul(rewardRate).mul(1e18).div(totalSupply())
        );
    }

    function earned(address _account) public view returns (uint256) {
        return balanceOf(_account).mul(rewardPerToken().sub(userRewardPerTokenPaid[_account])).div(1e18).add(rewards[_account]);
    }

    function getRewardForDuration() external view returns (uint256) {
        return rewardRate.mul(rewardsDuration);
    }

    function getParentFarm() external view returns(address) {
        return address(parentFarm);
    }

    function getParentPoolId() external view returns(uint) {
        return parentPoolId;
    }

    function getParentStakingToken() external view returns(address) {
        return address(parentStakingToken);
    }

    function totalSupply() public view returns (uint) {
        return parentStakingToken.balanceOf(address(parentFarm));
    }

    function balanceOf(address _account) public view returns (uint) {
        (uint balance, ) = parentFarm.userInfo(parentPoolId, _account);
        return balance;
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    // Called by parent farm during reward claim
    function onParentReward(address _account, uint _amount, bool _isDeposit) external onlyParentFarm {
        // avoid warning
        _amount;
        _isDeposit;
        getRewardFor(_account);
    }

    function notifyRewardAmount(uint256 _reward) external updateReward(address(0)) {
        require(_reward > 0, "Cannot provide 0 reward");
        rewardsToken.safeTransferFrom(msg.sender, address(this), _reward);

        if (block.timestamp >= periodFinish) {
            rewardRate = _reward.div(rewardsDuration);
        } else {
            uint256 remaining = periodFinish.sub(block.timestamp);
            uint256 leftover = remaining.mul(rewardRate);
            rewardRate = _reward.add(leftover).div(rewardsDuration);
        }

        // Ensure the provided reward amount is not more than the balance in the contract.
        // This keeps the reward rate in the right range, preventing overflows due to
        // very high values of rewardRate in the earned and rewardsPerToken functions;
        // Reward + leftover must be less than 2^256 / 10^18 to avoid overflow.
        uint balance = rewardsToken.balanceOf(address(this));
        require(rewardRate <= balance.div(rewardsDuration), "Provided reward too high");

        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp.add(rewardsDuration);
        emit RewardAdded(_reward);
    }


    /* ========== RESTRICTED FUNCTIONS ========== */

    // Allow governance to rescue unclaimed reward after the bonus farm has been retired
    function rescue(address _token) external onlyGov {
        uint _balance = IERC20(_token).balanceOf(address(this));
        IERC20(_token).safeTransfer(governance, _balance);
    }

    function setGovernance(address _governance)
    external
    onlyGov
    {
        governance = _governance;
    }

    function setStartTime(uint _startTime) external onlyGov {
        startTime = _startTime;
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    function getRewardFor(address _account) internal nonReentrant updateReward(_account) {
        uint256 reward = rewards[_account];
        if (reward > 0) {
            rewards[_account] = 0;
            rewardsToken.safeTransfer(_account, reward);
            emit RewardPaid(_account, reward);
        }
    }

    /* ========== MODIFIERS ========== */

    modifier onlyParentFarm() {
        require(msg.sender == address(parentFarm), "!parent");
        _;
    }

    modifier onlyGov() {
        require(msg.sender == governance, "!governance");
        _;
    }

    modifier updateReward(address _account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (_account != address(0)) {
            rewards[_account] = earned(_account);
            userRewardPerTokenPaid[_account] = rewardPerTokenStored;
        }
        _;
    }

    /* ========== EVENTS ========== */

    event RewardAdded(uint256 _reward);
    event RewardPaid(address indexed _user, uint256 _reward);

}