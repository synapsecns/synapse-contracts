# BonusChef







*How to remove an existing &quot;bonus reward&quot;. Only use for deprecated bonus tokens,      which have been mostly claimed by the users: 1. Wait until the bonus duration is finished. 2. inactivateRewardPool(r) will bonus token (r) from the list of bonus tokens,    also all earned but unclaimed user rewards will become unclaimable,    they can only be rescued by calling rescue(r) now. USE WITH CAUTION. PS. inactivateRewardPool(r) and later addRewardPool(r, TT) is the only way to change     reward duration period (from T to TT).*

## Methods

### DEFAULT_ADMIN_ROLE

```solidity
function DEFAULT_ADMIN_ROLE() external view returns (bytes32)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes32 | undefined |

### GOVERNANCE_ROLE

```solidity
function GOVERNANCE_ROLE() external view returns (bytes32)
```

Account with this role can add reward pools, inactivate reward pools, rescue tokens from inactive reward pools, grant rewardsDistribution role




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes32 | undefined |

### REWARDS_DISTRIBUTION_ROLE

```solidity
function REWARDS_DISTRIBUTION_ROLE() external view returns (bytes32)
```

Account with this role is able to provide rewards, starting (or prolonging) the bonus rewards period




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes32 | undefined |

### activeRewardPools

```solidity
function activeRewardPools(uint256) external view returns (address)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### activeRewardPoolsLength

```solidity
function activeRewardPoolsLength() external view returns (uint256)
```

Get amount of active reward pools. Some of them may be finished or haven&#39;t been started yet though.




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### addRewardPool

```solidity
function addRewardPool(address _rewardToken, uint256 _rewardsDuration) external nonpayable
```

Add new reward pool to list, but do NOT start it.

*This can also be used to add inactive pool, make sure to rescue() all the remaining tokens from previous round beforehand. Otherwise, previously unclaimed rewards can be claimed only after the pool is inactive again.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _rewardToken | address | bonus reward token |
| _rewardsDuration | uint256 | duration of the bonus pool, in seconds |

### addRewardsDistribution

```solidity
function addRewardsDistribution(address _rewardsDistribution) external nonpayable
```

Add the rewards supplier

*Make sure that _rewardsDistribution is vetted While this role can&#39;t claim/drain tokens, it can prolong the pools at will.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _rewardsDistribution | address | new reward supplier |

### balanceOf

```solidity
function balanceOf(address _account) external view returns (uint256)
```

Get user amount of LP tokens locked in the MiniChef pool



#### Parameters

| Name | Type | Description |
|---|---|---|
| _account | address | user address |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### chefPoolID

```solidity
function chefPoolID() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### chefStakingToken

```solidity
function chefStakingToken() external view returns (contract IERC20)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract IERC20 | undefined |

### earned

```solidity
function earned(address _rewardToken, address _account) external view returns (uint256)
```

Get amount of pending user bonus rewards



#### Parameters

| Name | Type | Description |
|---|---|---|
| _rewardToken | address | bonus reward token to check |
| _account | address | user address |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### getRewardForDuration

```solidity
function getRewardForDuration(address _rewardToken) external view returns (uint256)
```

Get total amount of rewards tokens that will be distributed since the last time reward pool was started



#### Parameters

| Name | Type | Description |
|---|---|---|
| _rewardToken | address | bonus reward token to check |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### getRoleAdmin

```solidity
function getRoleAdmin(bytes32 role) external view returns (bytes32)
```



*Returns the admin role that controls `role`. See {grantRole} and {revokeRole}. To change a role&#39;s admin, use {_setRoleAdmin}.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| role | bytes32 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes32 | undefined |

### getRoleMember

```solidity
function getRoleMember(bytes32 role, uint256 index) external view returns (address)
```



*Returns one of the accounts that have `role`. `index` must be a value between 0 and {getRoleMemberCount}, non-inclusive. Role bearers are not sorted in any particular way, and their ordering may change at any point. WARNING: When using {getRoleMember} and {getRoleMemberCount}, make sure you perform all queries on the same block. See the following https://forum.openzeppelin.com/t/iterating-over-elements-on-enumerableset-in-openzeppelin-contracts/2296[forum post] for more information.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| role | bytes32 | undefined |
| index | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### getRoleMemberCount

```solidity
function getRoleMemberCount(bytes32 role) external view returns (uint256)
```



*Returns the number of accounts that have `role`. Can be used together with {getRoleMember} to enumerate all bearers of a role.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| role | bytes32 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### grantRole

```solidity
function grantRole(bytes32 role, address account) external nonpayable
```



*Grants `role` to `account`. If `account` had not been already granted `role`, emits a {RoleGranted} event. Requirements: - the caller must have ``role``&#39;s admin role.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| role | bytes32 | undefined |
| account | address | undefined |

### hasRole

```solidity
function hasRole(bytes32 role, address account) external view returns (bool)
```



*Returns `true` if `account` has been granted `role`.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| role | bytes32 | undefined |
| account | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### inactivateRewardPool

```solidity
function inactivateRewardPool(address _rewardToken) external nonpayable
```

Remove rewards pool from active list

*All rewards from the pool become unclaimable, only rescue() can get them out after that*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _rewardToken | address | bonus reward token to inactivate |

### inactivateRewardPoolByIndex

```solidity
function inactivateRewardPoolByIndex(uint256 _index) external nonpayable
```

Remove rewards pool from active list

*In case the list gets so large and make iteration impossible. All rewards from the pool become unclaimable, only rescue() can get them out after that.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _index | uint256 | index of bonus pool to inactivate |

### lastTimeRewardApplicable

```solidity
function lastTimeRewardApplicable(address _rewardToken) external view returns (uint256)
```

Get timestamp for the current (not yet processed) batch of rewards



#### Parameters

| Name | Type | Description |
|---|---|---|
| _rewardToken | address | bonus reward token to check |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### lastUpdateTime

```solidity
function lastUpdateTime(address _rewardToken) external view returns (uint256)
```

Get timestamp for the last payout in the bonus reward pool



#### Parameters

| Name | Type | Description |
|---|---|---|
| _rewardToken | address | bonus reward token to check |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### miniChef

```solidity
function miniChef() external view returns (contract IMiniChefV2)
```

BonusChef is linked to the specific pool on MiniChef contract Each reward pool specifies a different reward token for THE SAME pool on MiniChef




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract IMiniChefV2 | undefined |

### notifyRewardAmount

```solidity
function notifyRewardAmount(address _rewardToken, uint256 _amount) external nonpayable
```

Provide bonus rewards

*Called by rewardsDistribution AFTER the pool for _rewardToken is set up via addRewardPool(_rewardToken, _rewardsDuration) rewardsDistribution has to approve this contract to spend _rewardToken beforehand If the pool is running: Will add (_amount) to the reward pool and extend its duration by pool.rewardsDuration If the pool is NOT running (finished or hasn&#39;t been started once) Will set (_amount) as the reward pool capacity and start the pool IMMEDIATELY. Pool will be running for pool.rewardsDuration*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _rewardToken | address | reward token to supply |
| _amount | uint256 | amount of reward token to supply |

### onSynapseReward

```solidity
function onSynapseReward(uint256, address _account, address _recipient, uint256 _synapseAmount, uint256 _oldAmount) external nonpayable
```

Callback to distribute user&#39;s bonus rewards

*Called whenever a user interacts with MiniChef*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |
| _account | address | user address |
| _recipient | address | address to sent bonus rewards |
| _synapseAmount | uint256 | undefined |
| _oldAmount | uint256 | user&#39;s LP tokens balance BEFORE the interaction |

### pendingTokens

```solidity
function pendingTokens(uint256, address _account, uint256) external view returns (contract IERC20[], uint256[])
```

Get all pending bonus rewards for user



#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |
| _account | address | user address |
| _2 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract IERC20[] | undefined |
| _1 | uint256[] | undefined |

### periodFinish

```solidity
function periodFinish(address _rewardToken) external view returns (uint256)
```

Get timestamp for bonus rewards to end



#### Parameters

| Name | Type | Description |
|---|---|---|
| _rewardToken | address | bonus reward token to check |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### renounceRole

```solidity
function renounceRole(bytes32 role, address account) external nonpayable
```



*Revokes `role` from the calling account. Roles are often managed via {grantRole} and {revokeRole}: this function&#39;s purpose is to provide a mechanism for accounts to lose their privileges if they are compromised (such as when a trusted device is misplaced). If the calling account had been granted `role`, emits a {RoleRevoked} event. Requirements: - the caller must be `account`.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| role | bytes32 | undefined |
| account | address | undefined |

### rescue

```solidity
function rescue(address _rewardToken) external nonpayable
```

Rescue unclaimed reward tokens from inactive pool

*Only governance can rescue tokens and only from inactive pools*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _rewardToken | address | bonus reward token to rescue |

### revokeRole

```solidity
function revokeRole(bytes32 role, address account) external nonpayable
```



*Revokes `role` from `account`. If `account` had been granted `role`, emits a {RoleRevoked} event. Requirements: - the caller must have ``role``&#39;s admin role.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| role | bytes32 | undefined |
| account | address | undefined |

### rewardPerToken

```solidity
function rewardPerToken(address _rewardToken) external view returns (uint256)
```

Get total amount of bonus rewards per 1 LP token in the MiniChef from the start of bonus pool



#### Parameters

| Name | Type | Description |
|---|---|---|
| _rewardToken | address | bonus reward token to check |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### rewardPerTokenStored

```solidity
function rewardPerTokenStored(address _rewardToken) external view returns (uint256)
```

Get total amount of bonus rewards per 1 LP token in the MiniChef from the start of bonus pool until last update



#### Parameters

| Name | Type | Description |
|---|---|---|
| _rewardToken | address | bonus reward token to check |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### rewardPools

```solidity
function rewardPools(address) external view returns (contract IERC20 rewardToken, uint256 periodFinish, uint256 rewardRate, uint256 rewardsDuration, uint256 lastUpdateTime, uint256 rewardPerTokenStored, bool isActive)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| rewardToken | contract IERC20 | undefined |
| periodFinish | uint256 | undefined |
| rewardRate | uint256 | undefined |
| rewardsDuration | uint256 | undefined |
| lastUpdateTime | uint256 | undefined |
| rewardPerTokenStored | uint256 | undefined |
| isActive | bool | undefined |

### rewardRate

```solidity
function rewardRate(address _rewardToken) external view returns (uint256)
```

Get amount of reward tokens distributed per second

*APR = rewardRate(_rewardToken) * secondsInYear * usdValue(_rewardToken) /  (totalSupply() * usdValue(chefStakingToken))*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _rewardToken | address | bonus reward token to check |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### rewards

```solidity
function rewards(address _rewardToken, address _account) external view returns (uint256)
```

Get last stored amount of user&#39;s unpaid bonus rewards



#### Parameters

| Name | Type | Description |
|---|---|---|
| _rewardToken | address | bonus reward token to check |
| _account | address | user address |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### rewardsDuration

```solidity
function rewardsDuration(address _rewardToken) external view returns (uint256)
```

Get total duration of a bonus reward pool



#### Parameters

| Name | Type | Description |
|---|---|---|
| _rewardToken | address | bonus reward token to check |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### totalSupply

```solidity
function totalSupply() external view returns (uint256)
```

Get total amount of LP tokens locked in the MiniChef pool




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### transferGovernance

```solidity
function transferGovernance(address _governance) external nonpayable
```

Change the governor

*Do not transfer this role to untrusted address, or funds might be SIFUed*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _governance | address | new governor |

### userRewardPerTokenPaid

```solidity
function userRewardPerTokenPaid(address _rewardToken, address _account) external view returns (uint256)
```

Get amount of bonus rewards paid to user per 1 LP token



#### Parameters

| Name | Type | Description |
|---|---|---|
| _rewardToken | address | bonus reward token to check |
| _account | address | user address |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |



## Events

### GovernanceChange

```solidity
event GovernanceChange(address governance)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| governance  | address | undefined |

### RewardAdded

```solidity
event RewardAdded(address indexed rewardToken, uint256 amount)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| rewardToken `indexed` | address | undefined |
| amount  | uint256 | undefined |

### RewardPaid

```solidity
event RewardPaid(address indexed rewardToken, address indexed user, address recipient, uint256 reward)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| rewardToken `indexed` | address | undefined |
| user `indexed` | address | undefined |
| recipient  | address | undefined |
| reward  | uint256 | undefined |

### RoleAdminChanged

```solidity
event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| role `indexed` | bytes32 | undefined |
| previousAdminRole `indexed` | bytes32 | undefined |
| newAdminRole `indexed` | bytes32 | undefined |

### RoleGranted

```solidity
event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| role `indexed` | bytes32 | undefined |
| account `indexed` | address | undefined |
| sender `indexed` | address | undefined |

### RoleRevoked

```solidity
event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| role `indexed` | bytes32 | undefined |
| account `indexed` | address | undefined |
| sender `indexed` | address | undefined |



