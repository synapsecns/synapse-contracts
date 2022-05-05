# IMetaSwapDeposit



> IMetaSwapDeposit interface

Interface for the meta swap contract.

*implement this interface to develop a a factory-patterned ECDSA node management contract**

## Methods

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

### getToken

```solidity
function getToken(uint256 index) external view returns (contract IERC20)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| index | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract IERC20 | undefined |

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




