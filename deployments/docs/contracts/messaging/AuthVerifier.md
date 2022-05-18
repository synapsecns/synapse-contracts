# AuthVerifier









## Methods

### msgAuth

```solidity
function msgAuth(bytes _authData) external view returns (bool authenticated)
```

Authentication library to allow the validator network to execute cross-chain messages.



#### Parameters

| Name | Type | Description |
|---|---|---|
| _authData | bytes | A bytes32 address encoded via abi.encode(address) |

#### Returns

| Name | Type | Description |
|---|---|---|
| authenticated | bool | returns true if bytes data submitted and decoded to the address is correct. Reverts if check fails. |

### nodegroup

```solidity
function nodegroup() external view returns (address)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### owner

```solidity
function owner() external view returns (address)
```



*Returns the address of the current owner.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### renounceOwnership

```solidity
function renounceOwnership() external nonpayable
```



*Leaves the contract without owner. It will not be possible to call `onlyOwner` functions anymore. Can only be called by the current owner. NOTE: Renouncing ownership will leave the contract without an owner, thereby removing any functionality that is only available to the owner.*


### setNodeGroup

```solidity
function setNodeGroup(address _nodegroup) external nonpayable
```

Permissioned method to support upgrades to the library



#### Parameters

| Name | Type | Description |
|---|---|---|
| _nodegroup | address | address which has authentication to execute messages |

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



