// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IUserMock {
    function setStartTime(uint256 _startTime) external;

    function setFinalTime(uint256 _finalTime) external;

    function setRewardRate(uint256 _rewardRate) external;

    function setShare(uint256 _share) external;

    function clearUnclaimed() external;

    function deposit(uint256 pid, uint256 tokenAmount) external;

    function withdraw(uint256 pid, uint256 tokenAmount) external;

    function harvest(uint256 pid) external;

    function withdrawAndHarvest(uint256 pid, uint256 tokenAmount) external;

    function rest(uint256 pid) external;
}
