// SPDX-License-Identifier: ISC

pragma solidity 0.6.12;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import "./BaseRewardV2.sol";
import "./interfaces/IMiniChefV2.sol";
// A farm contract to distribute rewards based on user balance of parent farm.
contract BonusChef is BaseRewardV2 {

    /* ========== STATES ========== */
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
    )
    public
    BaseRewardV2(_rewardsToken, _rewardsDuration)
    {
        parentFarm = _parentFarm;
        parentPoolId = _parentPoolId;
        parentStakingToken = _parentFarm.lpToken(_parentPoolId);
        governance = _governance;
    }

    /* ========== VIEWS ========== */

    function getParentFarm() external view returns(address) {
        return address(parentFarm);
    }

    function getParentPoolId() external view returns(uint) {
        return parentPoolId;
    }

    function getParentStakingToken() external view returns(address) {
        return address(parentStakingToken);
    }

    function totalSupply() public view override returns (uint) {
        return parentStakingToken.balanceOf(address(parentFarm));
    }

    function balanceOf(address _account) public view override returns (uint) {
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

    /* ========== MODIFIERS ========== */

    modifier onlyParentFarm() {
        require(msg.sender == address(parentFarm), "!parent");
        _;
    }

    modifier onlyGov() {
        require(msg.sender == governance, "!governance");
        _;
    }
}