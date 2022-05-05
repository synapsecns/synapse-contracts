# GasFeePricing









## Methods

### decodeOptions

```solidity
function decodeOptions(bytes _options) external pure returns (uint16, uint256, uint256, bytes32)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _options | bytes | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint16 | undefined |
| _1 | uint256 | undefined |
| _2 | uint256 | undefined |
| _3 | bytes32 | undefined |

### dstGasPriceInWei

```solidity
function dstGasPriceInWei(uint256) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### dstGasTokenRatio

```solidity
function dstGasTokenRatio(uint256) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### encodeOptions

```solidity
function encodeOptions(uint16 txType, uint256 gasLimit) external pure returns (bytes)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| txType | uint16 | undefined |
| gasLimit | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes | undefined |

### encodeOptions

```solidity
function encodeOptions(uint16 txType, uint256 gasLimit, uint256 dstNativeAmt, bytes32 dstAddress) external pure returns (bytes)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| txType | uint16 | undefined |
| gasLimit | uint256 | undefined |
| dstNativeAmt | uint256 | undefined |
| dstAddress | bytes32 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes | undefined |

### estimateGasFee

```solidity
function estimateGasFee(uint256 _dstChainId, bytes _options) external view returns (uint256)
```

Returns srcGasToken fee to charge in wei for the cross-chain message based on the gas limit



#### Parameters

| Name | Type | Description |
|---|---|---|
| _dstChainId | uint256 | undefined |
| _options | bytes | Versioned struct used to instruct relayer on how to proceed with gas limits. Contains data on gas limit to submit tx with. |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

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


### setCostPerChain

```solidity
function setCostPerChain(uint256 _dstChainId, uint256 _gasUnitPrice, uint256 _gasTokenPriceRatio) external nonpayable
```

Permissioned method to allow an off-chain party to set what each dstChain&#39;s gas cost is priced in the srcChain&#39;s native gas currency. Example: call on ETH, setCostPerChain(43114, 30000000000, 25180000000000000) chain ID 43114 Average of 30 gwei cost to transaction on 43114 AVAX/ETH = 0.02518, scaled to gas in wei = 25180000000000000



#### Parameters

| Name | Type | Description |
|---|---|---|
| _dstChainId | uint256 | The destination chain ID - typically, standard EVM chain ID, but differs on nonEVM chains |
| _gasUnitPrice | uint256 | The estimated current gas price in wei of the destination chain |
| _gasTokenPriceRatio | uint256 | USD gas ratio of dstGasToken / srcGasToken |

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



