# SwapEthWrapper

*Jongseung Lim (@weeb_mcgee)*

> SwapEthWrapper

A wrapper contract for Swap contracts that have WETH as one of the pooled tokens.



## Methods

### LP_TOKEN

```solidity
function LP_TOKEN() external view returns (contract LPToken)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract LPToken | undefined |

### OWNER

```solidity
function OWNER() external view returns (address)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### SWAP

```solidity
function SWAP() external view returns (contract Swap)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract Swap | undefined |

### WETH_ADDRESS

```solidity
function WETH_ADDRESS() external view returns (address payable)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address payable | undefined |

### WETH_INDEX

```solidity
function WETH_INDEX() external view returns (uint8)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint8 | undefined |

### addLiquidity

```solidity
function addLiquidity(uint256[] amounts, uint256 minToMint, uint256 deadline) external payable returns (uint256)
```

Add liquidity to the pool with the given amounts of tokens.

*The msg.value of this call should match the value in amounts array in position of WETH9.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| amounts | uint256[] | the amounts of each token to add, in their native precision |
| minToMint | uint256 | the minimum LP tokens adding this amount of liquidity should mint, otherwise revert. Handy for front-running mitigation |
| deadline | uint256 | latest timestamp to accept this transaction |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | amount of LP token user minted and received |

### calculateRemoveLiquidity

```solidity
function calculateRemoveLiquidity(uint256 amount) external view returns (uint256[])
```

A simple method to calculate amount of each underlying tokens that is returned upon burning given amount of LP tokens



#### Parameters

| Name | Type | Description |
|---|---|---|
| amount | uint256 | the amount of LP tokens that would be burned on withdrawal |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256[] | array of token balances that the user will receive |

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
| amounts | uint256[] | an array of token amounts to deposit or withdrawal, corresponding to pooledTokens. The amount should be in each pooled token&#39;s native precision. If a token charges a fee on transfers, use the amount that gets transferred after the fee. |
| deposit | bool | whether this is a deposit or a withdrawal |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | token amount the user will receive |

### pooledTokens

```solidity
function pooledTokens(uint256) external view returns (contract IERC20)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract IERC20 | undefined |

### removeLiquidity

```solidity
function removeLiquidity(uint256 amount, uint256[] minAmounts, uint256 deadline) external nonpayable returns (uint256[])
```

Burn LP tokens to remove liquidity from the pool.

*Liquidity can always be removed, even when the pool is paused. Caller will receive ETH instead of WETH9.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| amount | uint256 | the amount of LP tokens to burn |
| minAmounts | uint256[] | the minimum amounts of each token in the pool        acceptable for this burn. Useful as a front-running mitigation |
| deadline | uint256 | latest timestamp to accept this transaction |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256[] | amounts of tokens user received |

### removeLiquidityImbalance

```solidity
function removeLiquidityImbalance(uint256[] amounts, uint256 maxBurnAmount, uint256 deadline) external nonpayable returns (uint256)
```

Remove liquidity from the pool, weighted differently than the pool&#39;s current balances.

*Caller will receive ETH instead of WETH9.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| amounts | uint256[] | how much of each token to withdraw |
| maxBurnAmount | uint256 | the max LP token provider is willing to pay to remove liquidity. Useful as a front-running mitigation. |
| deadline | uint256 | latest timestamp to accept this transaction |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | amount of LP tokens burned |

### removeLiquidityOneToken

```solidity
function removeLiquidityOneToken(uint256 tokenAmount, uint8 tokenIndex, uint256 minAmount, uint256 deadline) external nonpayable returns (uint256)
```

Remove liquidity from the pool all in one token.

*Caller will receive ETH instead of WETH9.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| tokenAmount | uint256 | the amount of the token you want to receive |
| tokenIndex | uint8 | the index of the token you want to receive |
| minAmount | uint256 | the minimum amount to withdraw, otherwise revert |
| deadline | uint256 | latest timestamp to accept this transaction |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | amount of chosen token user received |

### rescue

```solidity
function rescue() external nonpayable
```

Rescues any of the ETH, the pooled tokens, or the LPToken that may be stuck in this contract. Only the OWNER can call this function.




### swap

```solidity
function swap(uint8 tokenIndexFrom, uint8 tokenIndexTo, uint256 dx, uint256 minDy, uint256 deadline) external payable returns (uint256)
```

Swap two tokens using the underlying pool. If tokenIndexFrom represents WETH9 in the pool, the caller must set msg.value equal to dx. If the user is swapping to WETH9 in the pool, the user will receive ETH instead.



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




