# ISynMessagingReceiver









## Methods

### executeMessage

```solidity
function executeMessage(bytes32 _srcAddress, uint256 _srcChainId, bytes _message, address _executor) external nonpayable returns (enum ISynMessagingReceiver.MsgExecutionStatus)
```

Called by MessageBus 

*MUST be permissioned to trusted source apps via trustedRemote*

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




