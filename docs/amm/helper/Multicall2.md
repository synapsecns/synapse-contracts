# Multicall2

*Michael Elliot &lt;mike@makerdao.com&gt;Joshua Levine &lt;joshua@makerdao.com&gt;Nick Johnson &lt;arachnid@notdot.net&gt;*

> Multicall2 - Aggregate results from multiple read-only function calls





## Methods

### aggregate

```solidity
function aggregate(Multicall2.Call[] calls) external nonpayable returns (uint256 blockNumber, bytes[] returnData)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| calls | Multicall2.Call[] | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| blockNumber | uint256 | undefined |
| returnData | bytes[] | undefined |

### blockAndAggregate

```solidity
function blockAndAggregate(Multicall2.Call[] calls) external nonpayable returns (uint256 blockNumber, bytes32 blockHash, struct Multicall2.Result[] returnData)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| calls | Multicall2.Call[] | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| blockNumber | uint256 | undefined |
| blockHash | bytes32 | undefined |
| returnData | Multicall2.Result[] | undefined |

### getBlockHash

```solidity
function getBlockHash(uint256 blockNumber) external view returns (bytes32 blockHash)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| blockNumber | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| blockHash | bytes32 | undefined |

### getBlockNumber

```solidity
function getBlockNumber() external view returns (uint256 blockNumber)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| blockNumber | uint256 | undefined |

### getCurrentBlockCoinbase

```solidity
function getCurrentBlockCoinbase() external view returns (address coinbase)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| coinbase | address | undefined |

### getCurrentBlockDifficulty

```solidity
function getCurrentBlockDifficulty() external view returns (uint256 difficulty)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| difficulty | uint256 | undefined |

### getCurrentBlockGasLimit

```solidity
function getCurrentBlockGasLimit() external view returns (uint256 gaslimit)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| gaslimit | uint256 | undefined |

### getCurrentBlockTimestamp

```solidity
function getCurrentBlockTimestamp() external view returns (uint256 timestamp)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| timestamp | uint256 | undefined |

### getEthBalance

```solidity
function getEthBalance(address addr) external view returns (uint256 balance)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| addr | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| balance | uint256 | undefined |

### getLastBlockHash

```solidity
function getLastBlockHash() external view returns (bytes32 blockHash)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| blockHash | bytes32 | undefined |

### tryAggregate

```solidity
function tryAggregate(bool requireSuccess, Multicall2.Call[] calls) external nonpayable returns (struct Multicall2.Result[] returnData)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| requireSuccess | bool | undefined |
| calls | Multicall2.Call[] | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| returnData | Multicall2.Result[] | undefined |

### tryBlockAndAggregate

```solidity
function tryBlockAndAggregate(bool requireSuccess, Multicall2.Call[] calls) external nonpayable returns (uint256 blockNumber, bytes32 blockHash, struct Multicall2.Result[] returnData)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| requireSuccess | bool | undefined |
| calls | Multicall2.Call[] | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| blockNumber | uint256 | undefined |
| blockHash | bytes32 | undefined |
| returnData | Multicall2.Result[] | undefined |




