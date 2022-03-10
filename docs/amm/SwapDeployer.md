# SwapDeployer









## Methods

### deploy

```solidity
function deploy(address swapAddress, contract IERC20[] _pooledTokens, uint8[] decimals, string lpTokenName, string lpTokenSymbol, uint256 _a, uint256 _fee, uint256 _adminFee, address lpTokenTargetAddress) external nonpayable returns (address)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| swapAddress | address | undefined |
| _pooledTokens | contract IERC20[] | undefined |
| decimals | uint8[] | undefined |
| lpTokenName | string | undefined |
| lpTokenSymbol | string | undefined |
| _a | uint256 | undefined |
| _fee | uint256 | undefined |
| _adminFee | uint256 | undefined |
| lpTokenTargetAddress | address | undefined |

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

### NewSwapPool

```solidity
event NewSwapPool(address indexed deployer, address swapAddress, contract IERC20[] pooledTokens)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| deployer `indexed` | address | undefined |
| swapAddress  | address | undefined |
| pooledTokens  | contract IERC20[] | undefined |

### OwnershipTransferred

```solidity
event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| previousOwner `indexed` | address | undefined |
| newOwner `indexed` | address | undefined |



