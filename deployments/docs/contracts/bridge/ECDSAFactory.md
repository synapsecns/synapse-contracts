# ECDSAFactory









## Methods

### deploy

```solidity
function deploy(address nodeMgmtAddress, address owner, address[] members, uint256 honestThreshold) external nonpayable returns (address)
```

Deploys a new node 



#### Parameters

| Name | Type | Description |
|---|---|---|
| nodeMgmtAddress | address | address of the ECDSANodeManagement contract to initialize with |
| owner | address | Owner of the  ECDSANodeManagement contract who can determine if the node group is closed or active |
| members | address[] | Array of node group members addresses |
| honestThreshold | uint256 | Number of signers to process a transaction  |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | Address of the newest node management contract created* |

### getMembers

```solidity
function getMembers() external view returns (address[])
```

Returns members of the keep.




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address[] | List of the keep members&#39; addresses. |

### latestNodeGroup

```solidity
function latestNodeGroup() external view returns (address keepAddress, address owner, uint256 honestThreshold)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| keepAddress | address | undefined |
| owner | address | undefined |
| honestThreshold | uint256 | undefined |

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

### ECDSANodeGroupCreated

```solidity
event ECDSANodeGroupCreated(address indexed keepAddress, address[] members, address indexed owner, uint256 honestThreshold)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| keepAddress `indexed` | address | undefined |
| members  | address[] | undefined |
| owner `indexed` | address | undefined |
| honestThreshold  | uint256 | undefined |

### OwnershipTransferred

```solidity
event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| previousOwner `indexed` | address | undefined |
| newOwner `indexed` | address | undefined |



