// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import {IMiniChefV2} from "../interfaces/IMiniChefV2.sol";
import {IUserMock} from "./interfaces/IUserMock.sol";

import "@boringcrypto/boring-solidity/contracts/libraries/BoringERC20.sol";

import "hardhat/console.sol";

contract UserMock is IUserMock {
    IMiniChefV2 public chef;

    uint256 public constant SHARE_MAX = 10**18;
    uint256 public share;
    uint256 public lastUpdate;
    uint256 public finalTime;
    uint256 public unclaimed;

    uint256 public rewardRate;

    IERC20[] public rewardTokens;

    string public name;

    uint256 public constant MAX_UINT = type(uint256).max;

    constructor(
        IMiniChefV2 _chef,
        IERC20[] memory _rewardTokens,
        string memory _name
    ) public {
        chef = _chef;
        rewardTokens = _rewardTokens;
        name = _name;
    }

    function setStartTime(uint256 _startTime) external override {
        lastUpdate = _startTime;
    }

    function setFinalTime(uint256 _finalTime) external override {
        finalTime = _finalTime;
    }

    function setRewardRate(uint256 _rewardRate) external override {
        rewardRate = _rewardRate;
    }

    function setShare(uint256 _share) external override {
        share = _share;
    }

    function deposit(uint256 pid, uint256 tokenAmount) external override {
        (
            IERC20 token,
            uint256 balanceBefore,
            uint256 expectedReward
        ) = _beforeAction(pid);
        chef.deposit(pid, tokenAmount, address(this));
        _checkRewards("deposit", token, balanceBefore, expectedReward);
    }

    function withdraw(uint256 pid, uint256 tokenAmount) external override {
        (
            IERC20 token,
            uint256 balanceBefore,
            uint256 expectedReward
        ) = _beforeAction(pid);
        chef.withdraw(pid, tokenAmount, address(this));
        _checkRewards("withdraw", token, balanceBefore, expectedReward);
    }

    function harvest(uint256 pid) external override {
        (
            IERC20 token,
            uint256 balanceBefore,
            uint256 expectedReward
        ) = _beforeAction(pid);
        chef.harvest(pid, address(this));
        _checkRewards("harvest", token, balanceBefore, expectedReward);
    }

    function withdrawAndHarvest(uint256 pid, uint256 tokenAmount)
        external
        override
    {
        (
            IERC20 token,
            uint256 balanceBefore,
            uint256 expectedReward
        ) = _beforeAction(pid);
        chef.withdrawAndHarvest(pid, tokenAmount, address(this));
        _checkRewards(
            "withdrawAndHarvest",
            token,
            balanceBefore,
            expectedReward
        );
    }

    function rest(uint256 pid) external override {
        (
            ,
            ,
            uint256 expectedReward
        ) = _beforeAction(pid);
        unclaimed = expectedReward;
    }

    function _beforeAction(uint256 pid)
        internal
        returns (
            IERC20 token,
            uint256 balanceBefore,
            uint256 expectedReward
        )
    {
        token = rewardTokens[pid];
        balanceBefore = token.balanceOf(address(this));
        expectedReward = _update() + unclaimed;
        unclaimed = 0;
        IERC20 lpToken = chef.lpToken(pid);
        if (lpToken.allowance(address(this), address(chef)) != MAX_UINT) {
            lpToken.approve(address(chef), MAX_UINT);
        }
    }

    function _checkRewards(
        string memory action,
        IERC20 token,
        uint256 balanceBefore,
        uint256 expectedReward
    ) internal view {
        uint256 balanceAfter = token.balanceOf(address(this));
        if (balanceAfter != balanceBefore + expectedReward) {
            console.log("%s: %s", action, name);
            console.log("Received: %s", balanceAfter - balanceBefore);
            console.log("Expected: %s", expectedReward);
            revert("Reward mismatch");
        }
    }

    function _update() internal returns (uint256 _amount) {
        if (lastUpdate != 0) {
            uint256 rewardTime = _getRewardTime();
            _amount =
                ((rewardTime - lastUpdate) * rewardRate * share) /
                SHARE_MAX;
            lastUpdate = rewardTime;
        } else {
            _amount = 0;
        }
    }

    function _getRewardTime() internal view returns (uint256) {
        return block.timestamp < finalTime ? block.timestamp : finalTime;
    }
}
