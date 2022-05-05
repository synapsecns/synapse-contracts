# SynMessagingReceiver









## Methods

### executeMessage

```solidity
function executeMessage(bytes32 _srcAddress, uint256 _srcChainId, bytes _message, address _executor) external nonpayable returns (enum ISynMessagingReceiver.MsgExecutionStatus)
```

Executes a message called by MessageBus (MessageBusReceiver)

*Must be called by MessageBug &amp; sent from src chain by a trusted srcApp*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _srcAddress | bytes32 | The bytes32 address of the source app contract |
| _srcChainId | uint256 | The source chain ID where the transfer is originated from |
| _message | bytes | Arbitrary message bytes originated from and encoded by the source app contract |
| _executor | address | Address who called the MessageBus execution function |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | enum ISynMessagingReceiver.MsgExecutionStatus | status Enum containing options of Success, Fail, Retry |

### getTrustedRemote

```solidity
function getTrustedRemote(uint256 _chainId) external view returns (bytes32 trustedRemote)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _chainId | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| trustedRemote | bytes32 | undefined |

### messageBus

```solidity
function messageBus() external view returns (address)
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


### setMessageBus

```solidity
function setMessageBus(address _messageBus) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _messageBus | address | undefined |

### setTrustedRemote

```solidity
function setTrustedRemote(uint256 _srcChainId, bytes32 _srcAddress) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _srcChainId | uint256 | undefined |
| _srcAddress | bytes32 | undefined |

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

### SetTrustedRemote

```solidity
event SetTrustedRemote(uint256 _srcChainId, bytes32 _srcAddress)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _srcChainId  | uint256 | undefined |
| _srcAddress  | bytes32 | undefined |



