# HarmonyBridgeZap









## Methods

### WETH_ADDRESS

```solidity
function WETH_ADDRESS() external view returns (address payable)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address payable | undefined |

### calculateSwap

```solidity
function calculateSwap(contract IERC20 token, uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 dx) external view returns (uint256)
```

Calculate amount of tokens you receive on swap



#### Parameters

| Name | Type | Description |
|---|---|---|
| token | contract IERC20 | undefined |
| tokenIndexFrom | uint8 | the token the user wants to sell |
| tokenIndexTo | uint8 | the token the user wants to buy |
| dx | uint256 | the amount of tokens the user wants to sell. If the token charges a fee on transfers, use the amount that gets transferred after the fee. |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | amount of tokens the user will receive |

### deposit

```solidity
function deposit(address to, uint256 chainId, contract IERC20 token, uint256 amount) external nonpayable
```

wraps SynapseBridge redeem()



#### Parameters

| Name | Type | Description |
|---|---|---|
| to | address | address on other chain to redeem underlying assets to |
| chainId | uint256 | which underlying chain to bridge assets onto |
| token | contract IERC20 | ERC20 compatible token to deposit into the bridge |
| amount | uint256 | Amount in native token decimals to transfer cross-chain pre-fees* |

### redeem

```solidity
function redeem(address to, uint256 chainId, contract IERC20 token, uint256 amount) external nonpayable
```

wraps SynapseBridge redeem()



#### Parameters

| Name | Type | Description |
|---|---|---|
| to | address | address on other chain to redeem underlying assets to |
| chainId | uint256 | which underlying chain to bridge assets onto |
| token | contract IERC20 | ERC20 compatible token to deposit into the bridge |
| amount | uint256 | Amount in native token decimals to transfer cross-chain pre-fees* |

### redeemAndRemove

```solidity
function redeemAndRemove(address to, uint256 chainId, contract IERC20 token, uint256 amount, uint8 liqTokenIndex, uint256 liqMinAmount, uint256 liqDeadline) external nonpayable
```

Wraps redeemAndRemove on SynapseBridge Relays to nodes that (typically) a wrapped synAsset ERC20 token has been burned and the underlying needs to be redeeemed on the native chain. This function indicates to the nodes that they should attempt to redeem the LP token for the underlying assets (E.g &quot;swap&quot; out of the LP token)



#### Parameters

| Name | Type | Description |
|---|---|---|
| to | address | address on other chain to redeem underlying assets to |
| chainId | uint256 | which underlying chain to bridge assets onto |
| token | contract IERC20 | ERC20 compatible token to deposit into the bridge |
| amount | uint256 | Amount of (typically) LP token to pass to the nodes to attempt to removeLiquidity() with to redeem for the underlying assets of the LP token |
| liqTokenIndex | uint8 | Specifies which of the underlying LP assets the nodes should attempt to redeem for |
| liqMinAmount | uint256 | Specifies the minimum amount of the underlying asset needed for the nodes to execute the redeem/swap |
| liqDeadline | uint256 | Specificies the deadline that the nodes are allowed to try to redeem/swap the LP token* |

### redeemAndSwap

```solidity
function redeemAndSwap(address to, uint256 chainId, contract IERC20 token, uint256 amount, uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 minDy, uint256 deadline) external nonpayable
```

Wraps redeemAndSwap on SynapseBridge.sol Relays to nodes that (typically) a wrapped synAsset ERC20 token has been burned and the underlying needs to be redeeemed on the native chain. This function indicates to the nodes that they should attempt to redeem the LP token for the underlying assets (E.g &quot;swap&quot; out of the LP token)



#### Parameters

| Name | Type | Description |
|---|---|---|
| to | address | address on other chain to redeem underlying assets to |
| chainId | uint256 | which underlying chain to bridge assets onto |
| token | contract IERC20 | ERC20 compatible token to deposit into the bridge |
| amount | uint256 | Amount in native token decimals to transfer cross-chain pre-fees |
| tokenIndexFrom | uint8 | the token the user wants to swap from |
| tokenIndexTo | uint8 | the token the user wants to swap to |
| minDy | uint256 | the min amount the user would like to receive, or revert to only minting the SynERC20 token crosschain. |
| deadline | uint256 | latest timestamp to accept this transaction* |

### redeemv2

```solidity
function redeemv2(bytes32 to, uint256 chainId, contract IERC20 token, uint256 amount) external nonpayable
```

Wraps SynapseBridge redeemv2() function



#### Parameters

| Name | Type | Description |
|---|---|---|
| to | bytes32 | address on other chain to bridge assets to |
| chainId | uint256 | which chain to bridge assets onto |
| token | contract IERC20 | ERC20 compatible token to redeem into the bridge |
| amount | uint256 | Amount in native token decimals to transfer cross-chain pre-fees* |

### swapAndRedeem

```solidity
function swapAndRedeem(address to, uint256 chainId, contract IERC20 token, uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 dx, uint256 minDy, uint256 deadline) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| to | address | undefined |
| chainId | uint256 | undefined |
| token | contract IERC20 | undefined |
| tokenIndexFrom | uint8 | undefined |
| tokenIndexTo | uint8 | undefined |
| dx | uint256 | undefined |
| minDy | uint256 | undefined |
| deadline | uint256 | undefined |

### swapAndRedeemAndRemove

```solidity
function swapAndRedeemAndRemove(address to, uint256 chainId, contract IERC20 token, uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 dx, uint256 minDy, uint256 deadline, uint8 liqTokenIndex, uint256 liqMinAmount, uint256 liqDeadline) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| to | address | undefined |
| chainId | uint256 | undefined |
| token | contract IERC20 | undefined |
| tokenIndexFrom | uint8 | undefined |
| tokenIndexTo | uint8 | undefined |
| dx | uint256 | undefined |
| minDy | uint256 | undefined |
| deadline | uint256 | undefined |
| liqTokenIndex | uint8 | undefined |
| liqMinAmount | uint256 | undefined |
| liqDeadline | uint256 | undefined |

### swapAndRedeemAndSwap

```solidity
function swapAndRedeemAndSwap(address to, uint256 chainId, contract IERC20 token, uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 dx, uint256 minDy, uint256 deadline, uint8 swapTokenIndexFrom, uint8 swapTokenIndexTo, uint256 swapMinDy, uint256 swapDeadline) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| to | address | undefined |
| chainId | uint256 | undefined |
| token | contract IERC20 | undefined |
| tokenIndexFrom | uint8 | undefined |
| tokenIndexTo | uint8 | undefined |
| dx | uint256 | undefined |
| minDy | uint256 | undefined |
| deadline | uint256 | undefined |
| swapTokenIndexFrom | uint8 | undefined |
| swapTokenIndexTo | uint8 | undefined |
| swapMinDy | uint256 | undefined |
| swapDeadline | uint256 | undefined |

### swapETHAndRedeem

```solidity
function swapETHAndRedeem(address to, uint256 chainId, contract IERC20 token, uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 dx, uint256 minDy, uint256 deadline) external payable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| to | address | undefined |
| chainId | uint256 | undefined |
| token | contract IERC20 | undefined |
| tokenIndexFrom | uint8 | undefined |
| tokenIndexTo | uint8 | undefined |
| dx | uint256 | undefined |
| minDy | uint256 | undefined |
| deadline | uint256 | undefined |

### swapMap

```solidity
function swapMap(address) external view returns (address)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### swapTokensMap

```solidity
function swapTokensMap(address, uint256) external view returns (contract IERC20)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |
| _1 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract IERC20 | undefined |




