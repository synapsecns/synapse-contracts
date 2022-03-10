# BaseSwapDeposit









## Methods

### baseSwap

```solidity
function baseSwap() external view returns (contract ISwap)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract ISwap | undefined |

### baseTokens

```solidity
function baseTokens(uint256) external view returns (contract IERC20)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract IERC20 | undefined |

### calculateSwap

```solidity
function calculateSwap(uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 dx) external view returns (uint256)
```

Calculate amount of tokens you receive on swap



#### Parameters

| Name | Type | Description |
|---|---|---|
| tokenIndexFrom | uint8 | the token the user wants to sell |
| tokenIndexTo | uint8 | the token the user wants to buy |
| dx | uint256 | the amount of tokens the user wants to sell. If the token charges a fee on transfers, use the amount that gets transferred after the fee. |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | amount of tokens the user will receive |

### getToken

```solidity
function getToken(uint256 index) external view returns (contract IERC20)
```

Returns the address of the pooled token at given index. Reverts if tokenIndex is out of range.



#### Parameters

| Name | Type | Description |
|---|---|---|
| index | uint256 | the index of the token |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract IERC20 | address of the token at given index |

### swap

```solidity
function swap(uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 dx, uint256 minDy, uint256 deadline) external nonpayable returns (uint256)
```

Swap two underlying tokens using the meta pool and the base pool



#### Parameters

| Name | Type | Description |
|---|---|---|
| tokenIndexFrom | uint8 | the token the user wants to swap from |
| tokenIndexTo | uint8 | the token the user wants to swap to |
| dx | uint256 | the amount of tokens the user wants to swap from |
| minDy | uint256 | the min amount the user would like to receive, or revert. |
| deadline | uint256 | latest timestamp to accept this transaction |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |




