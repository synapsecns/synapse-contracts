# PingPong









## Methods

### disable

```solidity
function disable() external nonpayable
```






### executeMessage

```solidity
function executeMessage(bytes32 _srcAddress, uint256 _srcChainId, bytes _message, address _executor) external nonpayable returns (enum ISynMessagingReceiver.MsgExecutionStatus)
```

Called by MessageBus (MessageBusReceiver)



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
| _0 | enum ISynMessagingReceiver.MsgExecutionStatus | undefined |

### maxPings

```solidity
function maxPings() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### messageBus

```solidity
function messageBus() external view returns (contract IMessageBus)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract IMessageBus | undefined |

### numPings

```solidity
function numPings() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### ping

```solidity
function ping(uint256 _dstChainId, address _dstPingPongAddr, uint256 pings) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _dstChainId | uint256 | undefined |
| _dstPingPongAddr | address | undefined |
| pings | uint256 | undefined |

### pingsEnabled

```solidity
function pingsEnabled() external view returns (bool)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |



## Events

### Ping

```solidity
event Ping(uint256 pings)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| pings  | uint256 | undefined |



