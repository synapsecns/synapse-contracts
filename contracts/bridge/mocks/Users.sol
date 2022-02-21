// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import {IMiniChefV2} from "../interfaces/IMiniChefV2.sol";
import {IUserMock} from "./interfaces/IUserMock.sol";
import "@boringcrypto/boring-solidity/contracts/libraries/BoringERC20.sol";

import "hardhat/console.sol";

contract Users {
    IUserMock[] public users;
    uint256[] public balances;
    uint256 public userAmount;

    uint256 public constant SHARE_MAX = 10**18;

    uint256 public constant DEPOSIT = 0;
    uint256 public constant WITHDRAW = 1;
    uint256 public constant HARVEST = 2;
    uint256 public constant WITHDRAW_HARVEST = 3;
    uint256 public constant REST = 4;

    constructor(IUserMock[] memory _users) public {
        userAmount = _users.length;
        users = _users;
        balances = new uint256[](userAmount);
    }

    function setData(
        uint256 _startTime,
        uint256 _finalTime,
        uint256 _rewardRate
    ) external {
        for (uint256 i = 0; i < userAmount; ++i) {
            users[i].setStartTime(_startTime);
            users[i].setFinalTime(_finalTime);
            users[i].setRewardRate(_rewardRate);
        }
    }

    function makeActions(
        uint256 pid,
        uint256[] calldata actions,
        uint256[] calldata amounts
    ) external {
        require(actions.length == userAmount, "Wrong amount of users");
        bool failed = false;
        for (uint256 i = 0; i < userAmount; ++i) {
            uint256 action = actions[i];
            uint256 amount = amounts[i];
            IUserMock user = users[i];
            if (action == DEPOSIT) {
                try user.deposit(pid, amount) {
                    balances[i] += amount;
                } catch {
                    failed = true;
                }
            } else if (action == WITHDRAW) {
                try user.withdraw(pid, amount) {
                    balances[i] -= amount;
                } catch {
                    failed = true;
                }
            } else if (action == HARVEST) {
                try user.harvest(pid) {} catch {
                    failed = true;
                }
            } else if (action == WITHDRAW_HARVEST) {
                try user.withdrawAndHarvest(pid, amount) {
                    balances[i] -= amount;
                } catch {
                    failed = true;
                }
            } else if (action == REST) {
                try user.rest(pid) {} catch {
                    failed = true;
                }
            } else {
                console.log("WTF action: %d -> %d", i, action);
                revert("Unknown action");
            }
        }
        require(!failed, "One of interactions failed");
        _updateShares();
    }

    function _updateShares() internal {
        uint256 totalBalance = 0;
        for (uint256 i = 0; i < userAmount; ++i) {
            totalBalance += balances[i];
        }

        for (uint256 i = 0; i < userAmount; ++i) {
            uint256 share = totalBalance != 0
                ? (balances[i] * SHARE_MAX) / totalBalance
                : 0;
            users[i].setShare(share);
        }
    }
}
