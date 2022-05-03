# Swap



> Swap - A StableSwap implementation in solidity.

This contract is responsible for custody of closely pegged assets (eg. group of stablecoins) and automatic market making system. Users become an LP (Liquidity Provider) by depositing their tokens in desired ratios for an exchange of the pool token that represents their share of the pool. Users can burn pool tokens and withdraw their share of token(s). Each time a swap between the pooled tokens happens, a set fee incurs which effectively gets distributed to the LPs. In case of emergencies, admin can pause additional deposits, swaps, or single-asset withdraws - which stops the ratio of the tokens in the pool from changing. Users can always withdraw their tokens via multi-asset withdraws.

*Most of the logic is stored as a library `SwapUtils` for the sake of reducing contract&#39;s deployment size.*

## Methods

### addLiquidity

```solidity
function addLiquidity(uint256[] amounts, uint256 minToMint, uint256 deadline) external nonpayable returns (uint256)
```

Add liquidity to the pool with the given amounts of tokens



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
| dx | uint256 | the amount of tokens the user wants to sell. If the token charges a fee on transfers, use the amount that gets transferred after the fee. |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | amount of tokens the user will receive |

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

### getA

```solidity
function getA() external view returns (uint256)
```

Return A, the amplification coefficient * n * (n - 1)

*See the StableSwap paper for details*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | A parameter |

### getAPrecise

```solidity
function getAPrecise() external view returns (uint256)
```

Return A in its raw precision form

*See the StableSwap paper for details*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | A parameter in its raw precision form |

### getAdminBalance

```solidity
function getAdminBalance(uint256 index) external view returns (uint256)
```

This function reads the accumulated amount of admin fees of the token with given index



#### Parameters

| Name | Type | Description |
|---|---|---|
| index | uint256 | Index of the pooled token |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | admin&#39;s token balance in the token&#39;s precision |

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

### getTokenBalance

```solidity
function getTokenBalance(uint8 index) external view returns (uint256)
```

Return current balance of the pooled token at given index



#### Parameters

| Name | Type | Description |
|---|---|---|
| index | uint8 | the index of the token |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | current balance of the pooled token at given index with token&#39;s native precision |

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

### getVirtualPrice

```solidity
function getVirtualPrice() external view returns (uint256)
```

Get the virtual price, to help calculate profit




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | the virtual price, scaled to the POOL_PRECISION_DECIMALS |

### initialize

```solidity
function initialize(contract IERC20[] _pooledTokens, uint8[] decimals, string lpTokenName, string lpTokenSymbol, uint256 _a, uint256 _fee, uint256 _adminFee, address lpTokenTargetAddress) external nonpayable
```

Initializes this Swap contract with the given parameters. This will also clone a LPToken contract that represents users&#39; LP positions. The owner of LPToken will be this contract - which means only this contract is allowed to mint/burn tokens.



#### Parameters

| Name | Type | Description |
|---|---|---|
| _pooledTokens | contract IERC20[] | an array of ERC20s this pool will accept |
| decimals | uint8[] | the decimals to use for each pooled token, eg 8 for WBTC. Cannot be larger than POOL_PRECISION_DECIMALS |
| lpTokenName | string | the long-form name of the token to be deployed |
| lpTokenSymbol | string | the short symbol for the token to be deployed |
| _a | uint256 | the amplification coefficient * n * (n - 1). See the StableSwap paper for details |
| _fee | uint256 | default swap fee to be initialized with |
| _adminFee | uint256 | default adminFee to be initialized with |
| lpTokenTargetAddress | address | the address of an existing LPToken contract to use as a target |

### owner

```solidity
function owner() external view returns (address)
```



*Returns the address of the current owner.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### pause

```solidity
function pause() external nonpayable
```

Pause the contract. Revert if already paused.




### paused

```solidity
function paused() external view returns (bool)
```



*Returns true if the contract is paused, and false otherwise.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### rampA

```solidity
function rampA(uint256 futureA, uint256 futureTime) external nonpayable
```

Start ramping up or down A parameter towards given futureA and futureTime Checks if the change is too rapid, and commits the new A value only when it falls under the limit range.



#### Parameters

| Name | Type | Description |
|---|---|---|
| futureA | uint256 | the new A to ramp towards |
| futureTime | uint256 | timestamp when the new A should be reached |

### removeLiquidity

```solidity
function removeLiquidity(uint256 amount, uint256[] minAmounts, uint256 deadline) external nonpayable returns (uint256[])
```

Burn LP tokens to remove liquidity from the pool. Withdraw fee that decays linearly over period of 4 weeks since last deposit will apply.

*Liquidity can always be removed, even when the pool is paused.*

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

Remove liquidity from the pool, weighted differently than the pool&#39;s current balances. Withdraw fee that decays linearly over period of 4 weeks since last deposit will apply.



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

Remove liquidity from the pool all in one token. Withdraw fee that decays linearly over period of 4 weeks since last deposit will apply.



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

### renounceOwnership

```solidity
function renounceOwnership() external nonpayable
```



*Leaves the contract without owner. It will not be possible to call `onlyOwner` functions anymore. Can only be called by the current owner. NOTE: Renouncing ownership will leave the contract without an owner, thereby removing any functionality that is only available to the owner.*


### setAdminFee

```solidity
function setAdminFee(uint256 newAdminFee) external nonpayable
```

Update the admin fee. Admin fee takes portion of the swap fee.



#### Parameters

| Name | Type | Description |
|---|---|---|
| newAdminFee | uint256 | new admin fee to be applied on future transactions |

### setSwapFee

```solidity
function setSwapFee(uint256 newSwapFee) external nonpayable
```

Update the swap fee to be applied on swaps



#### Parameters

| Name | Type | Description |
|---|---|---|
| newSwapFee | uint256 | new swap fee to be applied on future transactions |

### stopRampA

```solidity
function stopRampA() external nonpayable
```

Stop ramping A immediately. Reverts if ramp A is already stopped.




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

### swapStorage

```solidity
function swapStorage() external view returns (uint256 initialA, uint256 futureA, uint256 initialATime, uint256 futureATime, uint256 swapFee, uint256 adminFee, contract LPToken lpToken)
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
| lpToken | contract LPToken | undefined |

### transferOwnership

```solidity
function transferOwnership(address newOwner) external nonpayable
```



*Transfers ownership of the contract to a new account (`newOwner`). Can only be called by the current owner.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| newOwner | address | undefined |

### unpause

```solidity
function unpause() external nonpayable
```

Unpause the contract. Revert if already unpaused.




### withdrawAdminFees

```solidity
function withdrawAdminFees() external nonpayable
```

Withdraw all admin fees to the contract owner






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

### OwnershipTransferred

```solidity
event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| previousOwner `indexed` | address | undefined |
| newOwner `indexed` | address | undefined |

### Paused

```solidity
event Paused(address account)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| account  | address | undefined |

### RampA

```solidity
event RampA(uint256 oldA, uint256 newA, uint256 initialTime, uint256 futureTime)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| oldA  | uint256 | undefined |
| newA  | uint256 | undefined |
| initialTime  | uint256 | undefined |
| futureTime  | uint256 | undefined |

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

### StopRampA

```solidity
event StopRampA(uint256 currentA, uint256 time)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| currentA  | uint256 | undefined |
| time  | uint256 | undefined |

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

### Unpaused

```solidity
event Unpaused(address account)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| account  | address | undefined |



