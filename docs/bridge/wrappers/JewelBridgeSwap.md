# JewelBridgeSwap









## Methods

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
| dx | uint256 | the amount of tokens the user wants to swap.  |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | amount of tokens the user will receive |

### getToken

```solidity
function getToken(uint8 index) external view returns (contract IERC20)
```

Return address of the pooled token at given index. Reverts if tokenIndex is out of range.



#### Parameters

| Name | Type | Description |
|---|---|---|
| index | uint8 | the index of the token |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract IERC20 | address of the token at given index |

### getTokenIndex

```solidity
function getTokenIndex(address tokenAddress) external view returns (uint8)
```

Return the index of the given token address. Reverts if no matching token is found.



#### Parameters

| Name | Type | Description |
|---|---|---|
| tokenAddress | address | address of the token |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint8 | the index of the given token address |

### swap

```solidity
function swap(uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 dx, uint256 minDy, uint256 deadline) external nonpayable returns (uint256)
```

Swap two tokens using this pool



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




