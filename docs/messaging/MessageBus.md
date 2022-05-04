# MessageBus









## Methods

### authVerifier

```solidity
function authVerifier() external view returns (address)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### computeMessageId

```solidity
function computeMessageId(uint256 _srcChainId, bytes32 _srcAddress, address _dstAddress, uint256 _nonce, bytes _message) external view returns (bytes32)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _srcChainId | uint256 | undefined |
| _srcAddress | bytes32 | undefined |
| _dstAddress | address | undefined |
| _nonce | uint256 | undefined |
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

### executeMessage

```solidity
function executeMessage(uint256 _srcChainId, bytes32 _srcAddress, address _dstAddress, uint256 _gasLimit, uint256 _nonce, bytes _message, bytes32 _messageId) external nonpayable
```

Relayer executes messages through an authenticated method to the destination receiver based on the originating transaction on source chain



#### Parameters

| Name | Type | Description |
|---|---|---|
| _srcChainId | uint256 | Originating chain ID - typically a standard EVM chain ID, but may refer to a Synapse-specific chain ID on nonEVM chains |
| _srcAddress | bytes32 | Originating bytes32 address of the message sender on the srcChain |
| _dstAddress | address | Destination address that the arbitrary message will be passed to |
| _gasLimit | uint256 | Gas limit to be passed alongside the message, depending on the fee paid on srcChain |
| _nonce | uint256 | undefined |
| _message | bytes | Arbitrary message payload to pass to the destination chain receiver |
| _messageId | bytes32 | undefined |

### gasFeePricing

```solidity
function gasFeePricing() external view returns (address)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### getExecutedMessage

```solidity
function getExecutedMessage(bytes32 _messageId) external view returns (enum MessageBusReceiver.TxStatus)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _messageId | bytes32 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | enum MessageBusReceiver.TxStatus | undefined |

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

### updateAuthVerifier

```solidity
function updateAuthVerifier(address _authVerifier) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _authVerifier | address | undefined |

### updateGasFeePricing

```solidity
function updateGasFeePricing(address _gasFeePricing) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _gasFeePricing | address | undefined |

### updateMessageStatus

```solidity
function updateMessageStatus(bytes32 _messageId, enum MessageBusReceiver.TxStatus _status) external nonpayable
```

CONTRACT CONFIG 



#### Parameters

| Name | Type | Description |
|---|---|---|
| _messageId | bytes32 | undefined |
| _status | enum MessageBusReceiver.TxStatus | undefined |

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

### CallReverted

```solidity
event CallReverted(string reason)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| reason  | string | undefined |

### Executed

```solidity
event Executed(bytes32 msgId, enum MessageBusReceiver.TxStatus status, address indexed _dstAddress, uint64 srcChainId, uint64 srcNonce)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| msgId  | bytes32 | undefined |
| status  | enum MessageBusReceiver.TxStatus | undefined |
| _dstAddress `indexed` | address | undefined |
| srcChainId  | uint64 | undefined |
| srcNonce  | uint64 | undefined |

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



