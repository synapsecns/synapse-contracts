# HeroBridge



> Core app for handling cross chain messaging passing to bridge Hero NFTs





## Methods

### _createOptions

```solidity
function _createOptions() external nonpayable returns (bytes)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes | undefined |

### assistingAuction

```solidity
function assistingAuction() external view returns (address)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

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

### heroes

```solidity
function heroes() external view returns (address)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### messageBus

```solidity
function messageBus() external view returns (address)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### msgGasLimit

```solidity
function msgGasLimit() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### onERC721Received

```solidity
function onERC721Received(address operator, address from, uint256 tokenId, bytes data) external nonpayable returns (bytes4)
```



*Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom} by `operator` from `from`, this function is called. It must return its Solidity selector to confirm the token transfer. If any other value is returned or the interface is not implemented by the recipient, the transfer will be reverted. The selector can be obtained in Solidity with `onERC721Received.selector`.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| operator | address | undefined |
| from | address | undefined |
| tokenId | uint256 | undefined |
| data | bytes | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes4 | undefined |

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


### sendHero

```solidity
function sendHero(uint256 _heroId, uint256 _dstChainId) external payable
```

User must have an existing hero minted to bridge it.



#### Parameters

| Name | Type | Description |
|---|---|---|
| _heroId | uint256 | specifics which hero msg.sender already holds and will transfer to the bridge contract |
| _dstChainId | uint256 | The destination chain ID - typically, standard EVM chain ID, but differs on nonEVM chains |

### setAssistingAuctionAddress

```solidity
function setAssistingAuctionAddress(address _assistingAuction) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _assistingAuction | address | undefined |

### setMessageBus

```solidity
function setMessageBus(address _messageBus) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _messageBus | address | undefined |

### setMsgGasLimit

```solidity
function setMsgGasLimit(uint256 _msgGasLimit) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _msgGasLimit | uint256 | undefined |

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



