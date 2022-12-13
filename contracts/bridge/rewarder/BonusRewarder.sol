// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;
import "../interfaces/IRewarder.sol";
import "@boringcrypto/boring-solidity/contracts/libraries/BoringERC20.sol";
import "@boringcrypto/boring-solidity/contracts/libraries/BoringMath.sol";
import "@boringcrypto/boring-solidity/contracts/BoringOwnable.sol";

/// @author @0xKeno
contract BonusRewarder is IRewarder, BoringOwnable {
    using BoringMath for uint256;
    using BoringMath128 for uint128;
    using BoringERC20 for IERC20;

    /**
     * @notice Info of each BonusRewarder user.
     * @param amount        LP token amount the user has provided.
     * @param rewardDebt    Accumulated rewards at the time of last user interaction.
     * @param unpaidRewards Rolled over amount of rewards that wasn't paid during last interaction.
     */
    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 unpaidRewards;
    }

    /**
     * @notice Info of each BonusRewarder pool.
     * @param accRewardsPerShare    Lifetime rewards per 1 LP token scaled by ACC_TOKEN_PRECISION.
     * @param lastRewardTime        Timestamp when `accRewardsPerShare` was last updated.
     * @param allocPoint            The amount of allocation points assigned to the pool.
     * @param totalLpSupply         Total amount of LP tokens staked in BonusRewarder
     */
    struct BonusPoolInfo {
        uint128 accRewardsPerShare;
        uint64 lastRewardTime;
        uint64 allocPoint;
        uint256 totalLpSupply;
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                        CONSTANTS & IMMUTABLES                        ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @dev Multiplier for storing the accumulated rewards. Increases division precision.
    uint256 internal constant ACC_TOKEN_PRECISION = 1e12;

    /// @notice Address of the MiniChef where the LP tokens are staked
    address public immutable miniChefV2;

    /// @notice Address of the bonus reward token
    IERC20 public immutable rewardToken;

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                               STORAGE                                ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @notice Info of each pool.
    mapping(uint256 => BonusPoolInfo) public poolInfo;
    /// @notice IDs of all pools added to BonusRewarder. Must match with the pool ID in MiniChef.
    uint256[] public poolIds;

    /// @notice Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    /// @notice Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint;
    /// @notice Amount of rewardToken emitted per second
    uint256 public rewardPerSecond;
    /// @notice Timestamp when the bonus rewards will be stopped
    uint256 public rewardDeadline;
    /// @dev Flag indicating that a lock-protected function is entered.
    uint256 internal unlocked;

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                                EVENTS                                ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    event LogOnReward(address indexed user, uint256 indexed pid, uint256 amount, address indexed to);
    event LogPoolAddition(uint256 indexed pid, uint256 allocPoint);
    event LogSetPool(uint256 indexed pid, uint256 allocPoint);
    event LogUpdatePool(uint256 indexed pid, uint64 lastRewardTime, uint256 lpSupply, uint256 accRewardsPerShare);
    event LogRewardPerSecond(uint256 rewardPerSecond);
    event LogRewardDeadline(uint256 rewardDeadline);
    event LogInit();

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                       CONSTRUCTOR & MODIFIERS                        ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    constructor(
        IERC20 _rewardToken,
        uint256 _rewardPerSecond,
        address _miniChefV2
    ) public {
        rewardToken = _rewardToken;
        rewardPerSecond = _rewardPerSecond;
        miniChefV2 = _miniChefV2;
        // Bonus rewards are not time limited by default
        rewardDeadline = type(uint256).max;
        unlocked = 1;
    }

    modifier lock() {
        require(unlocked == 1, "LOCKED");
        unlocked = 2;
        _;
        unlocked = 1;
    }

    modifier onlyMCV2() {
        require(msg.sender == miniChefV2, "Only MCV2 can call this function");
        _;
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                      RESTRICTED: ONLY MINICHEF                       ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /**
     * @notice Triggered whenever user interacts with MiniChefV2. That is:
     * - miniChefV2.deposit()
     * - miniChefV2.withdraw()
     * - miniChefV2.harvest()
     * - miniChefV2.withdrawAndHarvest()
     * - miniChefV2.emergencyWithdraw()
     * @param pid       Pool ID that user interacted with in MiniChefV2
     * @param _user     User address
     * @param to        Address where the rewards should be transferred
     * @param lpToken   Amount of user LP tokens in MiniChefV2 AFTER the interaction
     */
    function onSynapseReward(
        uint256 pid,
        address _user,
        address to,
        uint256,
        uint256 lpToken
    ) external override onlyMCV2 lock {
        BonusPoolInfo memory pool = updatePool(pid);
        UserInfo storage user = userInfo[pid][_user];
        uint256 pending;
        // Calculate pending user bonus token rewards, if user triggered {onSynapseReward} before.
        // Otherwise, this is considered a user "deposit" into BonusRewarder.
        if (user.amount > 0) {
            // First, we calculate total accumulated rewards for `user.amount` LP tokens.
            // Then, we subtract the amount of accumulated rewards at the last user interaction.
            // That gives us the amount of token rewards earned since last interaction.
            // Finally, we add the amount of unpaid rewards at the last interaction.
            pending = (user.amount.mul(pool.accRewardsPerShare) / ACC_TOKEN_PRECISION).sub(user.rewardDebt).add(
                user.unpaidRewards
            );
            uint256 balance = rewardToken.balanceOf(address(this));
            if (pending > balance) {
                // If BonusRewarder doesn't have enough tokens, pay out as much as possible.
                rewardToken.safeTransfer(to, balance);
                // Store the remainder for the next time.
                user.unpaidRewards = pending - balance;
            } else {
                // If BonusRewarder has enough tokens, pay out the rewards fully.
                rewardToken.safeTransfer(to, pending);
                user.unpaidRewards = 0;
            }
        }
        // Update total pool LP supply: subtract previous user balance, add new one
        poolInfo[pid].totalLpSupply = poolInfo[pid].totalLpSupply.sub(user.amount).add(lpToken);
        user.amount = lpToken;
        user.rewardDebt = lpToken.mul(pool.accRewardsPerShare) / ACC_TOKEN_PRECISION;
        emit LogOnReward(_user, pid, pending - user.unpaidRewards, to);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                        RESTRICTED: ONLY OWNER                        ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @notice Add a new LP to the pool. Can only be called by the owner.
    /// DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    /// @param allocPoint AP of the new pool.
    /// @param _pid Pid on MCV2
    function add(uint256 allocPoint, uint256 _pid) external onlyOwner {
        require(poolInfo[_pid].lastRewardTime == 0, "Pool already exists");
        uint256 lastRewardTime = block.timestamp;
        totalAllocPoint = totalAllocPoint.add(allocPoint);

        poolInfo[_pid] = BonusPoolInfo({
            allocPoint: allocPoint.to64(),
            lastRewardTime: lastRewardTime.to64(),
            accRewardsPerShare: 0,
            totalLpSupply: 0
        });
        poolIds.push(_pid);
        emit LogPoolAddition(_pid, allocPoint);
    }

    /// @notice Update the given pool's rewardToken allocation point and `IRewarder` contract. Can only be called by the owner.
    /// @param _pid The index of the pool. See `poolInfo`.
    /// @param _allocPoint New AP of the pool.
    function set(uint256 _pid, uint256 _allocPoint) external onlyOwner {
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint.to64();
        emit LogSetPool(_pid, _allocPoint);
    }

    /// @notice Allows owner to reclaim/withdraw any tokens (including reward tokens) held by this contract
    /// @param token Token to reclaim, use 0x00 for Ethereum
    /// @param amount Amount of tokens to reclaim
    /// @param to Receiver of the tokens, first of his name, rightful heir to the lost tokens,
    /// reightful owner of the extra tokens, and ether, protector of mistaken transfers, mother of token reclaimers,
    /// the Khaleesi of the Great Token Sea, the Unburnt, the Breaker of blockchains.
    function reclaimTokens(
        address token,
        uint256 amount,
        address payable to
    ) external onlyOwner {
        if (token == address(0)) {
            to.transfer(amount);
        } else {
            IERC20(token).safeTransfer(to, amount);
        }
    }

    /// @notice Sets the rewardToken per second to be distributed. Can only be called by the owner.
    /// @param _rewardPerSecond The amount of rewardToken to be distributed per second.
    function setRewardPerSecond(uint256 _rewardPerSecond) external onlyOwner {
        rewardPerSecond = _rewardPerSecond;
        emit LogRewardPerSecond(_rewardPerSecond);
    }

    function setRewardDeadline(uint256 _rewardDeadline) external onlyOwner {
        rewardDeadline = _rewardDeadline;
        emit LogRewardDeadline(_rewardDeadline);
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                        UNPROTECTED FUNCTIONS                         ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    /// @notice Update reward variables for all pools. Be careful of gas spending!
    /// @param pids Pool IDs of all to be updated. Make sure to update all active pools.
    function massUpdatePools(uint256[] calldata pids) external {
        uint256 len = pids.length;
        for (uint256 i = 0; i < len; ++i) {
            updatePool(pids[i]);
        }
    }

    /// @notice Update reward variables of the given pool.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @return pool Returns the pool that was updated.
    function updatePool(uint256 pid) public returns (BonusPoolInfo memory pool) {
        pool = poolInfo[pid];
        if (block.timestamp > pool.lastRewardTime) {
            // Get total amount of pool LP tokens staked in BonusRewarder
            uint256 lpSupply = pool.totalLpSupply;
            if (lpSupply > 0) {
                // How much time passed since last calculation
                uint256 time = block.timestamp.sub(pool.lastRewardTime);
                // Calculate bonus token rewards for the pool for the last period
                uint256 bonusTokenReward = time.mul(rewardPerSecond).mul(pool.allocPoint) / totalAllocPoint;
                // Update total rewards for 1 LP token scaled up by ACC_TOKEN_PRECISION
                pool.accRewardsPerShare = pool.accRewardsPerShare.add(
                    (bonusTokenReward.mul(ACC_TOKEN_PRECISION) / lpSupply).to128()
                );
            }
            pool.lastRewardTime = block.timestamp.to64();
            poolInfo[pid] = pool;
            emit LogUpdatePool(pid, pool.lastRewardTime, lpSupply, pool.accRewardsPerShare);
        }
    }

    /*╔══════════════════════════════════════════════════════════════════════╗*\
    ▏*║                                VIEWS                                 ║*▕
    \*╚══════════════════════════════════════════════════════════════════════╝*/

    function pendingTokens(
        uint256 pid,
        address user,
        uint256
    ) external view override returns (IERC20[] memory rewardTokens, uint256[] memory rewardAmounts) {
        rewardTokens = new IERC20[](1);
        rewardTokens[0] = (rewardToken);
        rewardAmounts = new uint256[](1);
        rewardAmounts[0] = pendingToken(pid, user);
    }

    /// @notice Returns the number of MCV2 pools.
    function poolLength() external view returns (uint256 pools) {
        pools = poolIds.length;
    }

    /// @notice View function to see pending Token
    /// @param _pid The index of the pool. See `poolInfo`.
    /// @param _user Address of user.
    /// @return pending SYNAPSE reward for a given user.
    function pendingToken(uint256 _pid, address _user) public view returns (uint256 pending) {
        BonusPoolInfo memory pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accRewardsPerShare = pool.accRewardsPerShare;
        // Get total amount of pool LP tokens staked in BonusRewarder
        uint256 lpSupply = pool.totalLpSupply;
        if (block.timestamp > pool.lastRewardTime && lpSupply != 0) {
            // How much time passed since last calculation
            uint256 time = block.timestamp.sub(pool.lastRewardTime);
            // Calculate bonus token rewards for the pool for the last period
            uint256 bonusTokenReward = time.mul(rewardPerSecond).mul(pool.allocPoint) / totalAllocPoint;
            // Update total rewards for 1 LP token scaled up by ACC_TOKEN_PRECISION
            accRewardsPerShare = accRewardsPerShare.add(bonusTokenReward.mul(ACC_TOKEN_PRECISION) / lpSupply);
        }
        // First, we calculate total accumulated rewards for `user.amount` LP tokens.
        // Then, we subtract the amount of accumulated rewards at the last user interaction.
        // That gives us the amount of token rewards earned since last interaction.
        // Finally, we add the amount of unpaid rewards at the last interaction.
        pending = (user.amount.mul(accRewardsPerShare) / ACC_TOKEN_PRECISION).sub(user.rewardDebt).add(
            user.unpaidRewards
        );
    }
}
