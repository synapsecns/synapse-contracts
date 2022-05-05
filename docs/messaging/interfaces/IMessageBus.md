# IMessageBus









## Methods

### estimateFee

```solidity
function estimateFee(uint256 _dstChainId, bytes _options) external nonpayable returns (uint256)
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

### executeMessage

```solidity
function executeMessage(uint256 _srcChainId, bytes _srcAddress, address _dstAddress, uint256 _gasLimit, uint256 _nonce, bytes _message, bytes32 _messageId) external nonpayable
```

Relayer executes messages through an authenticated method to the destination receiver based on the originating transaction on source chain



#### Parameters

| Name | Type | Description |
|---|---|---|
| _srcChainId | uint256 | Originating chain ID - typically a standard EVM chain ID, but may refer to a Synapse-specific chain ID on nonEVM chains |
| _srcAddress | bytes | Originating bytes address of the message sender on the srcChain |
| _dstAddress | address | Destination address that the arbitrary message will be passed to |
| _gasLimit | uint256 | Gas limit to be passed alongside the message, depending on the fee paid on srcChain |
| _nonce | uint256 | Nonce from origin chain |
| _message | bytes | Arbitrary message payload to pass to the destination chain receiver |
| _messageId | bytes32 | MessageId for uniqueness of messages (alongisde nonce) |

### sendMessage

```solidity
function sendMessage(bytes32 _receiver, uint256 _dstChainId, bytes _message, bytes _options) external payable
```

Sends a message to a receiving contract address on another chain.  Sender must make sure that the message is unique and not a duplicate message.



#### Parameters

| Name | Type | Description |
|---|---|---|
| _receiver | bytes32 | The bytes32 address of the destination contract to be called |
| _dstChainId | uint256 | The destination chain ID - typically, standard EVM chain ID, but differs on nonEVM chains |
| _message | bytes | The arbitrary payload to pass to the destination chain receiver |
| _options | bytes | Versioned struct used to instruct relayer on how to proceed with gas limits |

### withdrawFee

```solidity
function withdrawFee(address _account) external nonpayable
```

Withdraws message fee in the form of native gas token.



#### Parameters

| Name | Type | Description |
|---|---|---|
| _account | address | The address receiving the fee. |




