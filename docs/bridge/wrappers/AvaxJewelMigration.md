# AvaxJewelMigration









## Methods

### LEGACY_TOKEN

```solidity
function LEGACY_TOKEN() external view returns (contract IERC20)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract IERC20 | undefined |

### NEW_TOKEN

```solidity
function NEW_TOKEN() external view returns (contract IERC20Mintable)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract IERC20Mintable | undefined |

### SYNAPSE_BRIDGE

```solidity
function SYNAPSE_BRIDGE() external view returns (contract ISynapseBridge)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract ISynapseBridge | undefined |

### migrate

```solidity
function migrate(uint256 amount) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| amount | uint256 | undefined |

### migrateAndBridge

```solidity
function migrateAndBridge(uint256 amount, address to, uint256 chainId) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| amount | uint256 | undefined |
| to | address | undefined |
| chainId | uint256 | undefined |

### owner

```solidity
function owner() external view returns (address)
```



*Returns the address of the current owner.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### redeemLegacy

```solidity
function redeemLegacy() external nonpayable
```






### renounceOwnership

```solidity
function renounceOwnership() external nonpayable
```



*Leaves the contract without owner. It will not be possible to call `onlyOwner` functions anymore. Can only be called by the current owner. NOTE: Renouncing ownership will leave the contract without an owner, thereby removing any functionality that is only available to the owner.*


### transferOwnership

```solidity
function transferOwnership(address newOwner) external nonpayable
```



*Transfers ownership of the contract to a new account (`newOwner`). Can only be called by the current owner.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| newOwner | address | undefined |



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



