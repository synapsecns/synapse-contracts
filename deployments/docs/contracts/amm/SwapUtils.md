# SwapUtils



> SwapUtils library

A library to be used within Swap.sol. Contains functions responsible for custody and AMM functionalities.

*Contracts relying on this library must initialize SwapUtils.Swap struct then use this library for SwapUtils.Swap struct. Note that this library contains both functions called by users and admins. Admin functions should be protected within contracts using this library.*

## Methods

### MAX_ADMIN_FEE

```solidity
function MAX_ADMIN_FEE() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### MAX_SWAP_FEE

```solidity
function MAX_SWAP_FEE() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### POOL_PRECISION_DECIMALS

```solidity
function POOL_PRECISION_DECIMALS() external view returns (uint8)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint8 | undefined |



## Events

### AddLiquidity

```solidity
event AddLiquidity(address indexed provider, uint256[] tokenAmounts, uint256[] fees, uint256 invariant, uint256 lpTokenSupply)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| provider `indexed` | address | undefined |
| tokenAmounts  | uint256[] | undefined |
| fees  | uint256[] | undefined |
| invariant  | uint256 | undefined |
| lpTokenSupply  | uint256 | undefined |

### NewAdminFee

```solidity
event NewAdminFee(uint256 newAdminFee)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| newAdminFee  | uint256 | undefined |

### NewSwapFee

```solidity
event NewSwapFee(uint256 newSwapFee)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| newSwapFee  | uint256 | undefined |

### RemoveLiquidity

```solidity
event RemoveLiquidity(address indexed provider, uint256[] tokenAmounts, uint256 lpTokenSupply)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| provider `indexed` | address | undefined |
| tokenAmounts  | uint256[] | undefined |
| lpTokenSupply  | uint256 | undefined |

### RemoveLiquidityImbalance

```solidity
event RemoveLiquidityImbalance(address indexed provider, uint256[] tokenAmounts, uint256[] fees, uint256 invariant, uint256 lpTokenSupply)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| provider `indexed` | address | undefined |
| tokenAmounts  | uint256[] | undefined |
| fees  | uint256[] | undefined |
| invariant  | uint256 | undefined |
| lpTokenSupply  | uint256 | undefined |

### RemoveLiquidityOne

```solidity
event RemoveLiquidityOne(address indexed provider, uint256 lpTokenAmount, uint256 lpTokenSupply, uint256 boughtId, uint256 tokensBought)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| provider `indexed` | address | undefined |
| lpTokenAmount  | uint256 | undefined |
| lpTokenSupply  | uint256 | undefined |
| boughtId  | uint256 | undefined |
| tokensBought  | uint256 | undefined |

### TokenSwap

```solidity
event TokenSwap(address indexed buyer, uint256 tokensSold, uint256 tokensBought, uint128 soldId, uint128 boughtId)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| buyer `indexed` | address | undefined |
| tokensSold  | uint256 | undefined |
| tokensBought  | uint256 | undefined |
| soldId  | uint128 | undefined |
| boughtId  | uint128 | undefined |



