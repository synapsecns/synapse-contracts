# ISwap









## Methods

### addLiquidity

```solidity
function addLiquidity(uint256[] amounts, uint256 minToMint, uint256 deadline) external nonpayable returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| amounts | uint256[] | undefined |
| minToMint | uint256 | undefined |
| deadline | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### calculateRemoveLiquidityOneToken

```solidity
function calculateRemoveLiquidityOneToken(uint256 tokenAmount, uint8 tokenIndex) external view returns (uint256 availableTokenAmount)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| tokenAmount | uint256 | undefined |
| tokenIndex | uint8 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| availableTokenAmount | uint256 | undefined |

### calculateSwap

```solidity
function calculateSwap(uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 dx) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| tokenIndexFrom | uint8 | undefined |
| tokenIndexTo | uint8 | undefined |
| dx | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### calculateTokenAmount

```solidity
function calculateTokenAmount(uint256[] amounts, bool deposit) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| amounts | uint256[] | undefined |
| deposit | bool | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### getToken

```solidity
function getToken(uint8 index) external view returns (contract IERC20)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| index | uint8 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract IERC20 | undefined |

### removeLiquidityImbalance

```solidity
function removeLiquidityImbalance(uint256[] amounts, uint256 maxBurnAmount, uint256 deadline) external nonpayable returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| amounts | uint256[] | undefined |
| maxBurnAmount | uint256 | undefined |
| deadline | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### removeLiquidityOneToken

```solidity
function removeLiquidityOneToken(uint256 tokenAmount, uint8 tokenIndex, uint256 minAmount, uint256 deadline) external nonpayable returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| tokenAmount | uint256 | undefined |
| tokenIndex | uint8 | undefined |
| minAmount | uint256 | undefined |
| deadline | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### swap

```solidity
function swap(uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 dx, uint256 minDy, uint256 deadline) external nonpayable returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| tokenIndexFrom | uint8 | undefined |
| tokenIndexTo | uint8 | undefined |
| dx | uint256 | undefined |
| minDy | uint256 | undefined |
| deadline | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |




