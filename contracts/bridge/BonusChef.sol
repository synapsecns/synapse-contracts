// SPDX-License-Identifier: ISC

pragma solidity 0.6.12;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import {IERC20, BoringERC20} from "@boringcrypto/boring-solidity/contracts/libraries/BoringERC20.sol";
import {IMiniChefV2} from "./interfaces/IMiniChefV2.sol";
import {IRewarder} from "./interfaces/IRewarder.sol";

// MultiStakingRewards contract that allows stakers to staking a single token and receive various reward tokens.
// Modified from Uniswap staking reward contract at https://etherscan.io/address/0x7FBa4B8Dc5E7616e59622806932DBea72537A56b#code
// with the following changes:
// - Expand from single reward token to a list of reward tokens
// - Allow removing inactive reward pools from list in case list grows above iteration gas limit
// - Allow governance to rescue unclaimed tokens of inactive pools

// Modified from AladdinDAO MultiStakingRewards contract at https://github.com/AladdinDAO/aladdin-contracts/blob/main/contracts/reward/MultiStakingRewards.sol
// with the following changes:
// 1. To ensure compatibility with existing IRewarder interface:
//      a. SafeERC20 -> BoringERC20
//      b. onParentReward() -> onSynapseReward()
//      c. added pendingTokens(), which returns a list of ALL pending rewards for user
// 2. To ensure compatibility with deployed MiniChefV2 contract:
//      a. Sending rewards to custom address is possible to make sure
//         bonus rewards are always transferred to the same address as SYN rewards
// 3. Removed stake and withdraw, as they happen in the MiniChef
// 4. Read staking balance and total supply from MiniChef
// 5. notifyRewardAmount updated to transferFrom(msg.sender) instead of using permissioned distributor
// 6. Added a few sanity checks
contract BonusChef is IRewarder, ReentrancyGuard {
    using SafeMath for uint256;
    using BoringERC20 for IERC20;

    /* ========== STRUCTS ========== */

    // Info of each reward pool.
    struct RewardPool {
        IERC20 rewardToken; // Address of reward token.
        uint256 periodFinish; // timestamp of when this reward pool finishes distribution
        uint256 rewardRate; // amount of rewards distributed per unit of time
        uint256 rewardsDuration; // duration of distribution
        uint256 lastUpdateTime; // timestamp of when reward info was last updated
        uint256 rewardPerTokenStored; // current rewards per token based on total rewards and total staked
        mapping(address => uint256) userRewardPerTokenPaid; // amount of rewards per token already paid out to user
        mapping(address => uint256) rewards; // amount of rewards user has earned
        bool isActive; // mark if the pool is active
    }

    /* ========== STATE VARIABLES ========== */

    address public rewardsDistribution;
    address public governance;

    IMiniChefV2 public immutable miniChef;
    uint256 public immutable chefPoolID;
    IERC20 public immutable chefStakingToken;

    mapping(address => RewardPool) public rewardPools; // reward token to reward pool mapping
    address[] public activeRewardPools; // list of reward tokens that are distributing rewards

    /* ========== CONSTRUCTOR ========== */

    constructor(
        IMiniChefV2 _miniChef,
        uint256 _chefPoolID,
        address _rewardsDistribution
    ) public {
        miniChef = _miniChef;
        chefPoolID = _chefPoolID;
        chefStakingToken = _miniChef.lpToken(_chefPoolID);
        rewardsDistribution = _rewardsDistribution;
        governance = msg.sender;
    }

    /* ========== VIEWS ========== */

    /**
        @notice Get amount of active reward pools.
        Some of them may be finished or haven't been started yet though.
     */
    function activeRewardPoolsLength() external view returns (uint256) {
        return activeRewardPools.length;
    }

    /**
        @notice Get timestamp for the current (not yet processed)
        batch of rewards
        @param _rewardToken bonus reward token to check
     */
    function lastTimeRewardApplicable(address _rewardToken)
        public
        view
        returns (uint256)
    {
        RewardPool storage pool = rewardPools[_rewardToken];
        return Math.min(block.timestamp, pool.periodFinish);
    }

    /**
        @notice Get total amount of bonus rewards per 1 LP token
        in the MiniChef from the start of bonus pool
        @param _rewardToken bonus reward token to check
     */
    function rewardPerToken(address _rewardToken)
        public
        view
        returns (uint256)
    {
        RewardPool storage pool = rewardPools[_rewardToken];
        uint256 _totalSupply = totalSupply();
        if (_totalSupply == 0) {
            return pool.rewardPerTokenStored;
        }
        return
            pool.rewardPerTokenStored.add(
                lastTimeRewardApplicable(_rewardToken)
                    .sub(pool.lastUpdateTime)
                    .mul(pool.rewardRate)
                    .mul(1e18)
                    .div(_totalSupply)
            );
    }

    /**
        @notice Get amount of pending user bonus rewards
        @param _rewardToken bonus reward token to check
        @param _account user address
     */
    function earned(address _rewardToken, address _account)
        external
        view
        returns (uint256)
    {
        return _earned(_rewardToken, _account, balanceOf(_account));
    }

    /**
        @notice Get total amount of LP tokens locked in the MiniChef pool
     */
    function totalSupply() public view returns (uint256) {
        return chefStakingToken.balanceOf(address(miniChef));
    }

    /**
        @notice Get user amount of LP tokens locked in the MiniChef pool
        @param _account user address
     */
    function balanceOf(address _account) public view returns (uint256) {
        (uint256 balance, ) = miniChef.userInfo(chefPoolID, _account);
        return balance;
    }

    /**
        @notice Get total amount of rewards tokens that will be distributed
        since the last time reward pool was started
        @param _rewardToken bonus reward token to check
     */
    function getRewardForDuration(address _rewardToken)
        external
        view
        returns (uint256)
    {
        RewardPool storage pool = rewardPools[_rewardToken];
        return pool.rewardRate.mul(pool.rewardsDuration);
    }

    /**
        @notice Get timestamp for bonus rewards to end
        @param _rewardToken bonus reward token to check
     */
    function periodFinish(address _rewardToken)
        external
        view
        returns (uint256)
    {
        RewardPool storage pool = rewardPools[_rewardToken];
        return pool.periodFinish;
    }

    /**
        @notice Get amount of reward tokens distributed per second
        @dev APR = rewardRate(_rewardToken) * secondsInYear * usdValue(_rewardToken) / 
        (totalSupply() * usdValue(chefStakingToken))
        @param _rewardToken bonus reward token to check
     */
    function rewardRate(address _rewardToken) external view returns (uint256) {
        RewardPool storage pool = rewardPools[_rewardToken];
        return pool.rewardRate;
    }

    /**
        @notice Get total duration of a bonus reward pool
        @param _rewardToken bonus reward token to check
     */
    function rewardsDuration(address _rewardToken)
        external
        view
        returns (uint256)
    {
        RewardPool storage pool = rewardPools[_rewardToken];
        return pool.rewardsDuration;
    }

    /**
        @notice Get timestamp for the last payout in the bonus reward pool
        @param _rewardToken bonus reward token to check
     */
    function lastUpdateTime(address _rewardToken)
        external
        view
        returns (uint256)
    {
        RewardPool storage pool = rewardPools[_rewardToken];
        return pool.lastUpdateTime;
    }

    /**
        @notice Get total amount of bonus rewards per 1 LP token
        in the MiniChef from the start of bonus pool until last update
        @param _rewardToken bonus reward token to check
     */
    function rewardPerTokenStored(address _rewardToken)
        external
        view
        returns (uint256)
    {
        RewardPool storage pool = rewardPools[_rewardToken];
        return pool.rewardPerTokenStored;
    }

    /**
        @notice Get amount of bonus rewards paid to user per 1 LP token
        @param _rewardToken bonus reward token to check
        @param _account user address
     */
    function userRewardPerTokenPaid(address _rewardToken, address _account)
        external
        view
        returns (uint256)
    {
        RewardPool storage pool = rewardPools[_rewardToken];
        return pool.userRewardPerTokenPaid[_account];
    }

    /**
        @notice Get last stored amount of user's unpaid bonus rewards
        @param _rewardToken bonus reward token to check
        @param _account user address
     */
    function rewards(address _rewardToken, address _account)
        external
        view
        returns (uint256)
    {
        RewardPool storage pool = rewardPools[_rewardToken];
        return pool.rewards[_account];
    }

    /**
        @notice Get all pending bonus rewards for user
        @param _account user address
     */
    function pendingTokens(
        uint256,
        address _account,
        uint256
    ) external view override returns (IERC20[] memory, uint256[] memory) {
        uint256 _activePoolsAmount = activeRewardPools.length;
        IERC20[] memory _rewardTokens = new IERC20[](_activePoolsAmount);
        uint256[] memory _rewardAmounts = new uint256[](_activePoolsAmount);
        uint256 _balance = balanceOf(_account);
        for (uint8 i = 0; i < _activePoolsAmount; i++) {
            address _rewardToken = activeRewardPools[i];
            _rewardTokens[i] = IERC20(_rewardToken);
            _rewardAmounts[i] = _earned(
                _rewardToken,
                _account,
                _balance
            );
        }

        return (_rewardTokens, _rewardAmounts);
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    /**
        @notice Callback to distribute user's bonus rewards
        @dev Called whenever a user interacts with MiniChef
        @param _account user address
        @param _recipient address to sent bonus rewards
        @param _oldAmount user's LP tokens balance BEFORE the interaction
     */
    function onSynapseReward(
        uint256,
        address _account,
        address _recipient,
        uint256 _synapseAmount,
        uint256 _oldAmount
    ) external override onlyMiniChef nonReentrant {
        // We check for reentrancy here, as this is the only function
        // that can be called by anyone (interacting with MiniChef)
        _getAllActiveRewardsFor(
            _account,
            _recipient,
            _oldAmount,
            _synapseAmount > 0
        );
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    /**
        @notice Provide bonus rewards
        @dev
        Called by rewardsDistribution AFTER the pool for _rewardToken is
        set up via addRewardPool(_rewardToken, _rewardsDuration)

        rewardsDistribution has to approve this contract
        to spend _rewardToken beforehand
        
        If the pool is running:
            Will add (_amount) to the reward pool
            and extend its duration by pool.rewardsDuration

        If the pool is NOT running (finished or hasn't been started once)
            Will set (_amount) as the reward pool capacity and start the pool
            IMMEDIATELY. Pool will be running for pool.rewardsDuration
        @param _rewardToken reward token to supply
        @param _amount amount of reward token to supply
     */
    function notifyRewardAmount(address _rewardToken, uint256 _amount)
        external
        onlyRewardsDistribution
        updateReward(_rewardToken, address(0), 0)
    {
        require(_amount != 0, "Zero reward provided");
        RewardPool storage pool = rewardPools[_rewardToken];
        require(pool.rewardsDuration != 0, "Pool is not added");

        pool.rewardToken.safeTransferFrom(msg.sender, address(this), _amount);
        if (block.timestamp >= pool.periodFinish) {
            pool.rewardRate = _amount.div(pool.rewardsDuration);
        } else {
            uint256 remaining = pool.periodFinish.sub(block.timestamp);
            uint256 leftover = remaining.mul(pool.rewardRate);
            pool.rewardRate = _amount.add(leftover).div(pool.rewardsDuration);
        }

        // Ensure the provided reward amount is not more than the balance in the contract.
        // This keeps the reward rate in the right range, preventing overflows due to
        // very high values of rewardRate in the earned and rewardsPerToken functions;
        // Reward + leftover must be less than 2^256 / 10^18 to avoid overflow.
        uint256 balance = pool.rewardToken.balanceOf(address(this));
        require(
            pool.rewardRate <= balance.div(pool.rewardsDuration),
            "Provided reward too high"
        );

        pool.lastUpdateTime = block.timestamp;
        pool.periodFinish = block.timestamp.add(pool.rewardsDuration);

        emit RewardAdded(_rewardToken, _amount);
    }

    /**
        @notice Add new reward pool to list, but do NOT start it.
        @dev This can also be used to add inactive pool, make sure
        to rescue() all the remaining tokens from previous round beforehand.
        Otherwise, previously unclaimed rewards can be claimed only after
        the pool is inactive again.
        @param _rewardToken bonus reward token
        @param _rewardsDuration duration of the bonus pool, in seconds
     */
    function addRewardPool(address _rewardToken, uint256 _rewardsDuration)
        external
        onlyGov
    {
        require(
            address(miniChef.rewarder(chefPoolID)) == address(this),
            "MiniChef pool isn't set up"
        );
        require(rewardPools[_rewardToken].isActive == false, "Pool is active");
        require(_rewardsDuration != 0, "Duration is null");
        rewardPools[_rewardToken] = RewardPool({
            rewardToken: IERC20(_rewardToken),
            periodFinish: 0,
            rewardRate: 0,
            rewardsDuration: _rewardsDuration,
            lastUpdateTime: 0,
            rewardPerTokenStored: 0,
            isActive: true
        });
        activeRewardPools.push(_rewardToken);
    }

    /**
        @notice Remove rewards pool from active list
        @dev All rewards from the pool become unclaimable,
        only rescue() can get them out after that
        @param _rewardToken bonus reward token to inactivate
     */
    function inactivateRewardPool(address _rewardToken) external onlyGov {
        // find the index
        uint256 indexToDelete = 0;
        bool found = false;
        for (uint256 i = 0; i < activeRewardPools.length; i++) {
            if (activeRewardPools[i] == _rewardToken) {
                indexToDelete = i;
                found = true;
                break;
            }
        }

        require(found, "Reward pool not found");
        _inactivateRewardPool(indexToDelete);
    }

    /**
        @notice Remove rewards pool from active list
        @dev In case the list gets so large and make iteration impossible.
        All rewards from the pool become unclaimable,
        only rescue() can get them out after that.
        @param _index index of bonus pool to inactivate
     */
    function inactivateRewardPoolByIndex(uint256 _index) external onlyGov {
        _inactivateRewardPool(_index);
    }

    /**
        @notice Internal implementation for removing a reward pool
        @param _index index of bonus pool to inactivate
     */
    function _inactivateRewardPool(uint256 _index) internal {
        RewardPool storage pool = rewardPools[activeRewardPools[_index]];
        pool.isActive = false;
        // we don't care about the ordering of the active reward pool array
        // so we can just swap the element to delete with the last element
        activeRewardPools[_index] = activeRewardPools[
            activeRewardPools.length - 1
        ];
        activeRewardPools.pop();
    }

    /**
        @notice Rescue unclaimed reward tokens from inactive pool
        @dev Only governance can rescue tokens and only from inactive pools
        @param _rewardToken bonus reward token to rescue
     */
    function rescue(address _rewardToken) external onlyGov {
        RewardPool storage pool = rewardPools[_rewardToken];
        require(pool.isActive == false, "Cannot withdraw active reward token");

        uint256 _balance = IERC20(_rewardToken).balanceOf(address(this));
        IERC20(_rewardToken).safeTransfer(governance, _balance);
    }

    /**
        @notice Change the rewards supplier
        @dev Make sure that _rewardsDistribution is vetted
        While this role can't claim/drain tokens, it can prolong the pools at will.
        @param _rewardsDistribution new reward supplier
     */
    function setRewardsDistribution(address _rewardsDistribution)
        external
        onlyGov
    {
        rewardsDistribution = _rewardsDistribution;
    }

    /**
        @notice Change the governor
        @dev Do not transfer this role to untrusted address,
        or funds might be SIFUed
        @param _governance new governor
     */
    function setGovernance(address _governance) external onlyGov {
        emit GovernanceChange(_governance);
        governance = _governance;
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    /**
        @notice Claim all pending bonus rewards for a user
        @dev Called whenever a user interacts with MiniChef
        @param _account user address
        @param _recipient address to sent bonus rewards
        @param _oldAmount user's LP tokens balance BEFORE the interaction
     */
    function _getAllActiveRewardsFor(
        address _account,
        address _recipient,
        uint256 _oldAmount,
        bool _claimRewards
    ) internal updateActiveRewards(_account, _oldAmount) {
        if (_claimRewards) {
            for (uint256 i = 0; i < activeRewardPools.length; i++) {
                _getReward(activeRewardPools[i], _account, _recipient);
            }
        }
    }

    /**
        @notice Claim a pending bonus reward for a user
        @param _rewardToken bonus reward token to claim
        @param _account user address
        @param _recipient address to sent bonus rewards
     */
    function _getReward(
        address _rewardToken,
        address _account,
        address _recipient
    ) internal {
        RewardPool storage pool = rewardPools[_rewardToken];
        require(pool.isActive, "Pool is inactive");

        uint256 reward = pool.rewards[_account];
        if (reward > 0) {
            pool.rewards[_account] = 0;
            pool.rewardToken.safeTransfer(_recipient, reward);
            emit RewardPaid(
                address(pool.rewardToken),
                _account,
                _recipient,
                reward
            );
        }
    }

    /**
        @notice Get pending bonus reward for a user
        @param _rewardToken bonus reward token to claim
        @param _account user address
        @param _oldAmount user balance of LP tokens at the time of last payout
     */
    function _earned(
        address _rewardToken,
        address _account,
        uint256 _oldAmount
    ) internal view returns (uint256) {
        RewardPool storage pool = rewardPools[_rewardToken];
        return
            _oldAmount
                .mul(
                    rewardPerToken(_rewardToken).sub(
                        pool.userRewardPerTokenPaid[_account]
                    )
                )
                .div(1e18)
                .add(pool.rewards[_account]);
    }

    /* ========== MODIFIERS ========== */

    /**
        @notice Update all pools stored info about the rewards, and also 
        update the stored info about user's pending rewards.
        @dev The user update is ignored if address(0) is supplied
        @param _account user address
        @param _oldAmount user balance of LP tokens at the time of last payout
     */
    modifier updateActiveRewards(address _account, uint256 _oldAmount) {
        for (uint256 i = 0; i < activeRewardPools.length; i++) {
            RewardPool storage pool = rewardPools[activeRewardPools[i]];

            pool.rewardPerTokenStored = rewardPerToken(
                address(pool.rewardToken)
            );
            pool.lastUpdateTime = lastTimeRewardApplicable(
                address(pool.rewardToken)
            );
            if (_account != address(0)) {
                pool.rewards[_account] = _earned(
                    address(pool.rewardToken),
                    _account,
                    _oldAmount
                );
                pool.userRewardPerTokenPaid[_account] = pool
                    .rewardPerTokenStored;
            }
        }
        _;
    }

    /**
        @notice Update a single pool stored info about the rewards, and also 
        update the stored info about user's pending rewards.
        @dev The user update is ignored if address(0) is supplied
        @param _rewardToken reward token for a pool to update
        @param _account user address
        @param _oldAmount user balance of LP tokens at the time of last payout
     */
    modifier updateReward(
        address _rewardToken,
        address _account,
        uint256 _oldAmount
    ) {
        RewardPool storage pool = rewardPools[_rewardToken];

        pool.rewardPerTokenStored = rewardPerToken(address(pool.rewardToken));
        pool.lastUpdateTime = lastTimeRewardApplicable(
            address(pool.rewardToken)
        );
        if (_account != address(0)) {
            pool.rewards[_account] = _earned(
                address(pool.rewardToken),
                _account,
                _oldAmount
            );
            pool.userRewardPerTokenPaid[_account] = pool.rewardPerTokenStored;
        }
        _;
    }

    modifier onlyMiniChef() {
        require(msg.sender == address(miniChef), "!parent");
        _;
    }

    modifier onlyGov() {
        require(msg.sender == governance, "!governance");
        _;
    }

    modifier onlyRewardsDistribution() {
        require(msg.sender == rewardsDistribution, "!rewardsDistribution");
        _;
    }

    /* ========== EVENTS ========== */

    event RewardAdded(address indexed rewardToken, uint256 amount);
    event RewardPaid(
        address indexed rewardToken,
        address indexed user,
        address recipient,
        uint256 reward
    );
    event GovernanceChange(address governance);
}
