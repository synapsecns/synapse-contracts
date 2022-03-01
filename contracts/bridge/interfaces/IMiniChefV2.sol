// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {IERC20} from "@boringcrypto/boring-solidity/contracts/libraries/BoringERC20.sol";
import {IRewarder} from "./IRewarder.sol";

interface IMiniChefV2 {
    /// @notice Info of each MCV2 user.
    /// `amount` LP token amount the user has provided.
    /// `rewardDebt` The amount of SYNAPSE entitled to the user.
    struct UserInfo {
        uint256 amount;
        int256 rewardDebt;
    }

    /// @notice Info of each MCV2 pool.
    /// `allocPoint` The amount of allocation points assigned to the pool.
    /// Also known as the amount of SYNAPSE to distribute per block.
    struct PoolInfo {
        uint128 accSynapsePerShare;
        uint64 lastRewardTime;
        uint64 allocPoint;
    }

    function poolInfo(uint256)
        external
        view
        returns (uint128, uint64, uint64);

    function updatePool(uint256 pid)
        external
        returns (PoolInfo memory);

    function lpToken(uint256) external view returns (IERC20);
    function poolLength() external view returns (uint256);

    function rewarder(uint256) external view returns (IRewarder);

    function userInfo(uint256 _pid, address _user)
        external
        view
        returns (uint256, int256);

    function deposit(
        uint256 pid,
        uint256 amount,
        address to
    ) external;

    function withdraw(
        uint256 pid,
        uint256 amount,
        address to
    ) external;

    function harvest(uint256 pid, address to) external;

    function withdrawAndHarvest(
        uint256 pid,
        uint256 amount,
        address to
    ) external;

    function emergencyWithdraw(uint256 pid, address to) external;
}