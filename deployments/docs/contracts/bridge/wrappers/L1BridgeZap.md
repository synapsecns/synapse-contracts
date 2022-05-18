# L1BridgeZap



> L1BridgeZap

This contract is responsible for handling user Zaps into the SynapseBridge contract, through the Synapse Swap contracts. It does so It does so by combining the action of addLiquidity() to the base swap pool, and then calling either deposit() or depositAndSwap() on the bridge. This is done in hopes of automating portions of the bridge user experience to users, while keeping the SynapseBridge contract logic small.

*This contract should be deployed with a base Swap.sol address and a SynapseBridge.sol address, otherwise, it will not function.*

## Methods

### WETH_ADDRESS

```solidity
function WETH_ADDRESS() external view returns (address payable)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address payable | undefined |

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

### calculateRemoveLiquidityOneToken

```solidity
function calculateRemoveLiquidityOneToken(uint256 tokenAmount, uint8 tokenIndex) external view returns (uint256 availableTokenAmount)
```

Calculate the amount of underlying token available to withdraw when withdrawing via only single token



#### Parameters

| Name | Type | Description |
|---|---|---|
| tokenAmount | uint256 | the amount of LP token to burn |
| tokenIndex | uint8 | index of which token will be withdrawn |

#### Returns

| Name | Type | Description |
|---|---|---|
| availableTokenAmount | uint256 | calculated amount of underlying token available to withdraw |

### calculateTokenAmount

```solidity
function calculateTokenAmount(uint256[] amounts, bool deposit) external view returns (uint256)
```

A simple method to calculate prices from deposits or withdrawals, excluding fees but including slippage. This is helpful as an input into the various &quot;min&quot; parameters on calls to fight front-running

*This shouldn&#39;t be used outside frontends for user estimates.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| amounts | uint256[] | an array of token amounts to deposit or withdrawal, corresponding to pooledTokens. The amount should be in each pooled token&#39;s native precision. |
| deposit | bool | whether this is a deposit or a withdrawal |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | token amount the user will receive |

### deposit

```solidity
function deposit(address to, uint256 chainId, contract IERC20 token, uint256 amount) external nonpayable
```

Wraps SynapseBridge deposit() function



#### Parameters

| Name | Type | Description |
|---|---|---|
| to | address | address on other chain to bridge assets to |
| chainId | uint256 | which chain to bridge assets onto |
| token | contract IERC20 | ERC20 compatible token to deposit into the bridge |
| amount | uint256 | Amount in native token decimals to transfer cross-chain pre-fees* |

### depositAndSwap

```solidity
function depositAndSwap(address to, uint256 chainId, contract IERC20 token, uint256 amount, uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 minDy, uint256 deadline) external nonpayable
```

Wraps SynapseBridge depositAndSwap() function



#### Parameters

| Name | Type | Description |
|---|---|---|
| to | address | address on other chain to bridge assets to |
| chainId | uint256 | which chain to bridge assets onto |
| token | contract IERC20 | ERC20 compatible token to deposit into the bridge |
| amount | uint256 | Amount in native token decimals to transfer cross-chain pre-fees |
| tokenIndexFrom | uint8 | the token the user wants to swap from |
| tokenIndexTo | uint8 | the token the user wants to swap to |
| minDy | uint256 | the min amount the user would like to receive, or revert to only minting the SynERC20 token crosschain. |
| deadline | uint256 | latest timestamp to accept this transaction* |

### depositETH

```solidity
function depositETH(address to, uint256 chainId, uint256 amount) external payable
```

Wraps SynapseBridge deposit() function to make it compatible w/ ETH -&gt; WETH conversions



#### Parameters

| Name | Type | Description |
|---|---|---|
| to | address | address on other chain to bridge assets to |
| chainId | uint256 | which chain to bridge assets onto |
| amount | uint256 | Amount in native token decimals to transfer cross-chain pre-fees* |

### depositETHAndSwap

```solidity
function depositETHAndSwap(address to, uint256 chainId, uint256 amount, uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 minDy, uint256 deadline) external payable
```

Wraps SynapseBridge depositAndSwap() function to make it compatible w/ ETH -&gt; WETH conversions



#### Parameters

| Name | Type | Description |
|---|---|---|
| to | address | address on other chain to bridge assets to |
| chainId | uint256 | which chain to bridge assets onto |
| amount | uint256 | Amount in native token decimals to transfer cross-chain pre-fees |
| tokenIndexFrom | uint8 | the token the user wants to swap from |
| tokenIndexTo | uint8 | the token the user wants to swap to |
| minDy | uint256 | the min amount the user would like to receive, or revert to only minting the SynERC20 token crosschain. |
| deadline | uint256 | latest timestamp to accept this transaction* |

### redeem

```solidity
function redeem(address to, uint256 chainId, contract IERC20 token, uint256 amount) external nonpayable
```

Wraps SynapseBridge redeem() function



#### Parameters

| Name | Type | Description |
|---|---|---|
| to | address | address on other chain to bridge assets to |
| chainId | uint256 | which chain to bridge assets onto |
| token | contract IERC20 | ERC20 compatible token to redeem into the bridge |
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

### zapAndDeposit

```solidity
function zapAndDeposit(address to, uint256 chainId, contract IERC20 token, uint256[] liquidityAmounts, uint256 minToMint, uint256 deadline) external nonpayable
```

Combines adding liquidity to the given Swap, and calls deposit() on the bridge using that LP token



#### Parameters

| Name | Type | Description |
|---|---|---|
| to | address | address on other chain to bridge assets to |
| chainId | uint256 | which chain to bridge assets onto |
| token | contract IERC20 | ERC20 compatible token to deposit into the bridge |
| liquidityAmounts | uint256[] | the amounts of each token to add, in their native precision |
| minToMint | uint256 | the minimum LP tokens adding this amount of liquidity should mint, otherwise revert. Handy for front-running mitigation |
| deadline | uint256 | latest timestamp to accept this transaction* |

### zapAndDepositAndSwap

```solidity
function zapAndDepositAndSwap(address to, uint256 chainId, contract IERC20 token, uint256[] liquidityAmounts, uint256 minToMint, uint256 liqDeadline, uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 minDy, uint256 swapDeadline) external nonpayable
```

Combines adding liquidity to the given Swap, and calls depositAndSwap() on the bridge using that LP token



#### Parameters

| Name | Type | Description |
|---|---|---|
| to | address | address on other chain to bridge assets to |
| chainId | uint256 | which chain to bridge assets onto |
| token | contract IERC20 | ERC20 compatible token to deposit into the bridge |
| liquidityAmounts | uint256[] | the amounts of each token to add, in their native precision |
| minToMint | uint256 | the minimum LP tokens adding this amount of liquidity should mint, otherwise revert. Handy for front-running mitigation |
| liqDeadline | uint256 | latest timestamp to accept this transaction |
| tokenIndexFrom | uint8 | the token the user wants to swap from |
| tokenIndexTo | uint8 | the token the user wants to swap to |
| minDy | uint256 | the min amount the user would like to receive, or revert to only minting the SynERC20 token crosschain. |
| swapDeadline | uint256 | latest timestamp to accept this transaction* |




