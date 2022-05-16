# SynapseERC20DeterministicFactory









## Methods

### deploy

```solidity
function deploy(address synapseERC20Address, string name, string symbol, uint8 decimals, address owner) external nonpayable returns (address synERC20Clone)
```

Deploys a new SynapseERC20 token



#### Parameters

| Name | Type | Description |
|---|---|---|
| synapseERC20Address | address | address of the synapseERC20Address contract to initialize with |
| name | string | Token name |
| symbol | string | Token symbol |
| decimals | uint8 | Token name |
| owner | address | admin address to be initialized with |

#### Returns

| Name | Type | Description |
|---|---|---|
| synERC20Clone | address | Address of the newest SynapseERC20 token created* |

### deployDeterministic

```solidity
function deployDeterministic(address synapseERC20Address, bytes32 salt, string name, string symbol, uint8 decimals, address owner) external nonpayable returns (address synERC20Clone)
```

Deploys a new SynapseERC20 token

*Use the same salt for the same token on different chains to get the same deployment address.      Requires having SynapseERC20Factory deployed at the same address on different chains as well. NOTE: this function has onlyOwner modifier to prevent bad actors from taking a token&#39;s address on another chain*

#### Parameters

| Name | Type | Description |
|---|---|---|
| synapseERC20Address | address | address of the synapseERC20Address contract to initialize with |
| salt | bytes32 | Salt for creating a clone |
| name | string | Token name |
| symbol | string | Token symbol |
| decimals | uint8 | Token name |
| owner | address | admin address to be initialized with |

#### Returns

| Name | Type | Description |
|---|---|---|
| synERC20Clone | address | Address of the newest SynapseERC20 token created* |

### owner

```solidity
function owner() external view returns (address)
```



*Returns the address of the current owner.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### predictDeterministicAddress

```solidity
function predictDeterministicAddress(address synapseERC20Address, bytes32 salt) external view returns (address)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| synapseERC20Address | address | undefined |
| salt | bytes32 | undefined |

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

### OwnershipTransferred

```solidity
event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| previousOwner `indexed` | address | undefined |
| newOwner `indexed` | address | undefined |

### SynapseERC20Created

```solidity
event SynapseERC20Created(address contractAddress)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| contractAddress  | address | undefined |



