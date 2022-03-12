# TestSwapReturnValues









## Methods

### MAX_INT

```solidity
function MAX_INT() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### lpToken

```solidity
function lpToken() external view returns (contract IERC20)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract IERC20 | undefined |

### n

```solidity
function n() external view returns (uint8)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint8 | undefined |

### swap

```solidity
function swap() external view returns (contract ISwap)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract ISwap | undefined |

### test_addLiquidity

```solidity
function test_addLiquidity(uint256[] amounts, uint256 minToMint) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| amounts | uint256[] | undefined |
| minToMint | uint256 | undefined |

### test_removeLiquidity

```solidity
function test_removeLiquidity(uint256 amount, uint256[] minAmounts) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| amount | uint256 | undefined |
| minAmounts | uint256[] | undefined |

### test_removeLiquidityImbalance

```solidity
function test_removeLiquidityImbalance(uint256[] amounts, uint256 maxBurnAmount) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| amounts | uint256[] | undefined |
| maxBurnAmount | uint256 | undefined |

### test_removeLiquidityOneToken

```solidity
function test_removeLiquidityOneToken(uint256 tokenAmount, uint8 tokenIndex, uint256 minAmount) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| tokenAmount | uint256 | undefined |
| tokenIndex | uint8 | undefined |
| minAmount | uint256 | undefined |

### test_swap

```solidity
function test_swap(uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 dx, uint256 minDy) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| tokenIndexFrom | uint8 | undefined |
| tokenIndexTo | uint8 | undefined |
| dx | uint256 | undefined |
| minDy | uint256 | undefined |




