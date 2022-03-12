# IMiniChefV2









## Methods

### deposit

```solidity
function deposit(uint256 pid, uint256 amount, address to) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| pid | uint256 | undefined |
| amount | uint256 | undefined |
| to | address | undefined |

### emergencyWithdraw

```solidity
function emergencyWithdraw(uint256 pid, address to) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| pid | uint256 | undefined |
| to | address | undefined |

### harvest

```solidity
function harvest(uint256 pid, address to) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| pid | uint256 | undefined |
| to | address | undefined |

### lpToken

```solidity
function lpToken(uint256) external view returns (contract IERC20)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract IERC20 | undefined |

### poolInfo

```solidity
function poolInfo(uint256) external view returns (uint128, uint64, uint64)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint128 | undefined |
| _1 | uint64 | undefined |
| _2 | uint64 | undefined |

### poolLength

```solidity
function poolLength() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### rewarder

```solidity
function rewarder(uint256) external view returns (contract IRewarder)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract IRewarder | undefined |

### updatePool

```solidity
function updatePool(uint256 pid) external nonpayable returns (struct IMiniChefV2.PoolInfo)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| pid | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | IMiniChefV2.PoolInfo | undefined |

### userInfo

```solidity
function userInfo(uint256 _pid, address _user) external view returns (uint256, int256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _pid | uint256 | undefined |
| _user | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |
| _1 | int256 | undefined |

### withdraw

```solidity
function withdraw(uint256 pid, uint256 amount, address to) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| pid | uint256 | undefined |
| amount | uint256 | undefined |
| to | address | undefined |

### withdrawAndHarvest

```solidity
function withdrawAndHarvest(uint256 pid, uint256 amount, address to) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| pid | uint256 | undefined |
| amount | uint256 | undefined |
| to | address | undefined |




