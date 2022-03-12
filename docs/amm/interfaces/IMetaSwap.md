# IMetaSwap









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

### calculateRemoveLiquidity

```solidity
function calculateRemoveLiquidity(uint256 amount) external view returns (uint256[])
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| amount | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256[] | undefined |

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

### calculateSwapUnderlying

```solidity
function calculateSwapUnderlying(uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 dx) external view returns (uint256)
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

### getA

```solidity
function getA() external view returns (uint256)
```






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

### getTokenBalance

```solidity
function getTokenBalance(uint8 index) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| index | uint8 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### getTokenIndex

```solidity
function getTokenIndex(address tokenAddress) external view returns (uint8)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| tokenAddress | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint8 | undefined |

### getVirtualPrice

```solidity
function getVirtualPrice() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### initializeMetaSwap

```solidity
function initializeMetaSwap(contract IERC20[] pooledTokens, uint8[] decimals, string lpTokenName, string lpTokenSymbol, uint256 a, uint256 fee, uint256 adminFee, address lpTokenTargetAddress, address baseSwap) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| pooledTokens | contract IERC20[] | undefined |
| decimals | uint8[] | undefined |
| lpTokenName | string | undefined |
| lpTokenSymbol | string | undefined |
| a | uint256 | undefined |
| fee | uint256 | undefined |
| adminFee | uint256 | undefined |
| lpTokenTargetAddress | address | undefined |
| baseSwap | address | undefined |

### isGuarded

```solidity
function isGuarded() external view returns (bool)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### removeLiquidity

```solidity
function removeLiquidity(uint256 amount, uint256[] minAmounts, uint256 deadline) external nonpayable returns (uint256[])
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| amount | uint256 | undefined |
| minAmounts | uint256[] | undefined |
| deadline | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256[] | undefined |

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

### swapStorage

```solidity
function swapStorage() external view returns (uint256 initialA, uint256 futureA, uint256 initialATime, uint256 futureATime, uint256 swapFee, uint256 adminFee, address lpToken)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| initialA | uint256 | undefined |
| futureA | uint256 | undefined |
| initialATime | uint256 | undefined |
| futureATime | uint256 | undefined |
| swapFee | uint256 | undefined |
| adminFee | uint256 | undefined |
| lpToken | address | undefined |

### swapUnderlying

```solidity
function swapUnderlying(uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 dx, uint256 minDy, uint256 deadline) external nonpayable returns (uint256)
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




