# BoringOwnable









## Methods

### claimOwnership

```solidity
function claimOwnership() external nonpayable
```






### owner

```solidity
function owner() external view returns (address)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### pendingOwner

```solidity
function pendingOwner() external view returns (address)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### transferOwnership

```solidity
function transferOwnership(address newOwner, bool direct, bool renounce) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| newOwner | address | undefined |
| direct | bool | undefined |
| renounce | bool | undefined |



## Events

### OwnershipTransferred

```solidity
event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| previousOwner `indexed` | address | undefined |
| newOwner `indexed` | address | undefined |



