# MessageBusSender









## Methods

### computeMessageId

```solidity
function computeMessageId(uint256 _srcChainId, address _srcAddress, uint256 _dstChainId, bytes32 _dstAddress, uint256 _srcNonce, bytes _message) external view returns (bytes32)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _srcChainId | uint256 | undefined |
| _srcAddress | address | undefined |
| _dstChainId | uint256 | undefined |
| _dstAddress | bytes32 | undefined |
| _srcNonce | uint256 | undefined |
| _message | bytes | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes32 | undefined |

### estimateFee

```solidity
function estimateFee(uint256 _dstChainId, bytes _options) external nonpayable returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _dstChainId | uint256 | undefined |
| _options | bytes | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### gasFeePricing

```solidity
function gasFeePricing() external view returns (address)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### nonce

```solidity
function nonce() external view returns (uint64)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint64 | undefined |

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


### rescueGas

```solidity
function rescueGas(address payable to) external nonpayable
```

Rescues any gas in contract, aside from fees



#### Parameters

| Name | Type | Description |
|---|---|---|
| to | address payable | Address to which to rescue gas to |

### sendMessage

```solidity
function sendMessage(bytes32 _receiver, uint256 _dstChainId, bytes _message, bytes _options) external payable
```

Sends a message to a receiving contract address on another chain. Sender must make sure that the message is unique and not a duplicate message.



#### Parameters

| Name | Type | Description |
|---|---|---|
| _receiver | bytes32 | The bytes32 address of the destination contract to be called |
| _dstChainId | uint256 | The destination chain ID - typically, standard EVM chain ID, but differs on nonEVM chains |
| _message | bytes | The arbitrary payload to pass to the destination chain receiver |
| _options | bytes | Versioned struct used to instruct relayer on how to proceed with gas limits |

### transferOwnership

```solidity
function transferOwnership(address newOwner) external nonpayable
```



*Transfers ownership of the contract to a new account (`newOwner`). Can only be called by the current owner.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| newOwner | address | undefined |

### updateGasFeePricing

```solidity
function updateGasFeePricing(address _gasFeePricing) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _gasFeePricing | address | undefined |

### withdrawGasFees

```solidity
function withdrawGasFees(address payable to) external nonpayable
```

Withdraws accumulated fees in native gas token, based on fees variable.



#### Parameters

| Name | Type | Description |
|---|---|---|
| to | address payable | Address to withdraw gas fees to, which can be specified in the event owner() can&#39;t receive native gas |



## Events

### MessageSent

```solidity
event MessageSent(address indexed sender, uint256 srcChainID, bytes32 receiver, uint256 indexed dstChainId, bytes message, uint64 nonce, bytes options, uint256 fee, bytes32 indexed messageId)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| sender `indexed` | address | undefined |
| srcChainID  | uint256 | undefined |
| receiver  | bytes32 | undefined |
| dstChainId `indexed` | uint256 | undefined |
| message  | bytes | undefined |
| nonce  | uint64 | undefined |
| options  | bytes | undefined |
| fee  | uint256 | undefined |
| messageId `indexed` | bytes32 | undefined |

### OwnershipTransferred

```solidity
event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| previousOwner `indexed` | address | undefined |
| newOwner `indexed` | address | undefined |



