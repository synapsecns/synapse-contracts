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

    IMiniChefV2 private immutable miniChef;
    bool private chefLinked;
    uint256 private chefPoolID;
    IERC20 private chefStakingToken;

    mapping(address => RewardPool) public rewardPools; // reward token to reward pool mapping
    address[] public activeRewardPools; // list of reward tokens that are distributing rewards

    /* ========== CONSTRUCTOR ========== */

    constructor(IMiniChefV2 _miniChef, address _rewardsDistribution) public {
        miniChef = _miniChef;
        rewardsDistribution = _rewardsDistribution;
        governance = msg.sender;
    }

    /* ========== VIEWS ========== */

    function activeRewardPoolsLength() external view returns (uint256) {
        return activeRewardPools.length;
    }

    function lastTimeRewardApplicable(address _rewardToken)
        public
        view
        returns (uint256)
    {
        RewardPool storage pool = rewardPools[_rewardToken];
        return Math.min(block.timestamp, pool.periodFinish);
    }

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

    function earned2(address _rewardToken, address _account)
        public
        view
        returns (uint256)
    {
        return earned(_rewardToken, _account, balanceOf(_account));
    }

    function earned(
        address _rewardToken,
        address _account,
        uint256 _oldAmount
    ) public view returns (uint256) {
        RewardPool storage pool = rewardPools[_rewardToken];
        return
            _oldAmount
                .mul(
                rewardPerToken(_rewardToken).sub(
                    pool.userRewardPerTokenPaid[_account]
                )
            ).div(1e18)
                .add(pool.rewards[_account]);
    }

    function totalSupply() public view returns (uint256) {
        return chefStakingToken.balanceOf(address(miniChef));
    }

    function balanceOf(address _account) public view returns (uint256) {
        (uint256 balance, ) = miniChef.userInfo(chefPoolID, _account);
        return balance;
    }

    function getRewardForDuration(address _rewardToken)
        external
        view
        returns (uint256)
    {
        RewardPool storage pool = rewardPools[_rewardToken];
        return pool.rewardRate.mul(pool.rewardsDuration);
    }

    function periodFinish(address _rewardToken) public view returns (uint256) {
        RewardPool storage pool = rewardPools[_rewardToken];
        return pool.periodFinish;
    }

    function rewardRate(address _rewardToken) public view returns (uint256) {
        RewardPool storage pool = rewardPools[_rewardToken];
        return pool.rewardRate;
    }

    function rewardsDuration(address _rewardToken)
        public
        view
        returns (uint256)
    {
        RewardPool storage pool = rewardPools[_rewardToken];
        return pool.rewardsDuration;
    }

    function lastUpdateTime(address _rewardToken)
        public
        view
        returns (uint256)
    {
        RewardPool storage pool = rewardPools[_rewardToken];
        return pool.lastUpdateTime;
    }

    // useful for UI estimation of pool's APR
    function rewardPerTokenStored(address _rewardToken)
        public
        view
        returns (uint256)
    {
        RewardPool storage pool = rewardPools[_rewardToken];
        return pool.rewardPerTokenStored;
    }

    function userRewardPerTokenPaid(address _rewardToken, address _account)
        public
        view
        returns (uint256)
    {
        RewardPool storage pool = rewardPools[_rewardToken];
        return pool.userRewardPerTokenPaid[_account];
    }

    function rewards(address _rewardToken, address _account)
        public
        view
        returns (uint256)
    {
        RewardPool storage pool = rewardPools[_rewardToken];
        return pool.rewards[_account];
    }

    function pendingTokens(
        uint256,
        address _user,
        uint256
    ) external view override returns (IERC20[] memory, uint256[] memory) {
        uint256 _activePoolsAmount = activeRewardPools.length;
        IERC20[] memory _rewardTokens = new IERC20[](_activePoolsAmount);
        uint256[] memory _rewardAmounts = new uint256[](_activePoolsAmount);
        for (uint8 i = 0; i < _activePoolsAmount; i++) {
            address _rewardToken = activeRewardPools[i];
            _rewardTokens[i] = IERC20(_rewardToken);
            _rewardAmounts[i] = earned(_rewardToken, _user, balanceOf(_user));
        }

        return (_rewardTokens, _rewardAmounts);
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    // Called by MiniChef reward claim
    function onSynapseReward(
        uint256,
        address _user,
        address _recipient,
        uint256,
        uint256 oldAmount
    ) external override onlyMiniChef {
        _getAllActiveRewardsFor(_user, _recipient, oldAmount);
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    // Called by rewardsDistribution AFTER the pool for _rewardToken is
    // set up via addRewardPool(_rewardToken, _rewardsDuration)

    // If the pool is running:
    //      Will add (_amount) to the reward pool
    //      and extend its duration by pool.rewardsDuration

    // If the pool is NOT running:
    //      Will set (_amount) as the reward pool capacity and start the pool,
    //      which will be running for pool.rewardsDuration
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

    // Add new reward pool to list.
    // This can only be done once the Bonus Chef is linked to a pool on MiniChef contract
    // This can also be used to add inactive pool, make sure
    // to rescue() all the remaining tokens from previous round beforehand
    function addRewardPool(address _rewardToken, uint256 _rewardsDuration)
        external
        onlyGov
    {
        require(rewardPools[_rewardToken].isActive == false, "Pool is active");
        require(_rewardsDuration != 0, "Duration is null");
        require(chefLinked, "BonusChef is not linked to any pool");
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

    // Remove rewards pool from active list
    // All rewards from the pool become unclaimable, only rescue() can get them out
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

    // In case the list gets so large and make iteration impossible
    // All rewards from the pool become unclaimable, only rescue() can get them out
    function inactivateRewardPoolByIndex(uint256 _index) external onlyGov {
        _inactivateRewardPool(_index);
    }

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

    // Allow governance to rescue unclaimed inactive rewards
    function rescue(address _rewardToken) external onlyGov {
        RewardPool storage pool = rewardPools[_rewardToken];
        require(pool.isActive == false, "Cannot withdraw active reward token");

        uint256 _balance = IERC20(_rewardToken).balanceOf(address(this));
        IERC20(_rewardToken).safeTransfer(governance, _balance);
    }

    function linkToPool(uint256 _chefPoolID) external onlyGov {
        _setPoolID(_chefPoolID);
    }

    function setRewardsDistribution(address _rewardsDistribution)
        external
        onlyGov
    {
        rewardsDistribution = _rewardsDistribution;
    }

    function setGovernance(address _governance) external onlyGov {
        governance = _governance;
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    function _setPoolID(uint256 _chefPoolID) internal {
        require(!chefLinked, "BonusChef is already linked to pool");
        chefPoolID = _chefPoolID;
        chefStakingToken = miniChef.lpToken(_chefPoolID);
        chefLinked = true;
    }

    // This will do nothing, if no pools are added, so
    // we don't need to check if BonusChef is linked or not
    function _getAllActiveRewardsFor(
        address _account,
        address _recipient,
        uint256 _oldAmount
    ) internal updateActiveRewards(_account, _oldAmount) {
        for (uint256 i = 0; i < activeRewardPools.length; i++) {
            _getReward(activeRewardPools[i], _account, _recipient);
        }
    }

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

    /* ========== MODIFIERS ========== */

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
                pool.rewards[_account] = earned(
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
            pool.rewards[_account] = earned(
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
}
