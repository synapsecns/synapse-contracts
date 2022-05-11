# ISynapseBridge









## Methods

### deposit

```solidity
function deposit(address to, uint256 chainId, contract IERC20 token, uint256 amount) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| to | address | undefined |
| chainId | uint256 | undefined |
| token | contract IERC20 | undefined |
| amount | uint256 | undefined |

### depositAndSwap

```solidity
function depositAndSwap(address to, uint256 chainId, contract IERC20 token, uint256 amount, uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 minDy, uint256 deadline) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| to | address | undefined |
| chainId | uint256 | undefined |
| token | contract IERC20 | undefined |
| amount | uint256 | undefined |
| tokenIndexFrom | uint8 | undefined |
| tokenIndexTo | uint8 | undefined |
| minDy | uint256 | undefined |
| deadline | uint256 | undefined |

### redeem

```solidity
function redeem(address to, uint256 chainId, contract IERC20 token, uint256 amount) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| to | address | undefined |
| chainId | uint256 | undefined |
| token | contract IERC20 | undefined |
| amount | uint256 | undefined |

### redeemAndRemove

```solidity
function redeemAndRemove(address to, uint256 chainId, contract IERC20 token, uint256 amount, uint8 liqTokenIndex, uint256 liqMinAmount, uint256 liqDeadline) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| to | address | undefined |
| chainId | uint256 | undefined |
| token | contract IERC20 | undefined |
| amount | uint256 | undefined |
| liqTokenIndex | uint8 | undefined |
| liqMinAmount | uint256 | undefined |
| liqDeadline | uint256 | undefined |

### redeemAndSwap

```solidity
function redeemAndSwap(address to, uint256 chainId, contract IERC20 token, uint256 amount, uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 minDy, uint256 deadline) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| to | address | undefined |
| chainId | uint256 | undefined |
| token | contract IERC20 | undefined |
| amount | uint256 | undefined |
| tokenIndexFrom | uint8 | undefined |
| tokenIndexTo | uint8 | undefined |
| minDy | uint256 | undefined |
| deadline | uint256 | undefined |

### redeemV2

```solidity
function redeemV2(bytes32 to, uint256 chainId, contract IERC20 token, uint256 amount) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| to | bytes32 | undefined |
| chainId | uint256 | undefined |
| token | contract IERC20 | undefined |
| amount | uint256 | undefined |




