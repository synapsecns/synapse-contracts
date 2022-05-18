# ERC20Migrator









## Methods

### legacyToken

```solidity
function legacyToken() external view returns (contract IERC20)
```



*Returns the legacy token that is being migrated.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract IERC20 | undefined |

### migrate

```solidity
function migrate(uint256 amount) external nonpayable
```



*Transfers part of an account&#39;s balance in the old token to this contract, and mints the same amount of new tokens for that account.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| amount | uint256 | amount of tokens to be migrated |

### newToken

```solidity
function newToken() external view returns (contract IERC20)
```



*Returns the new token to which we are migrating.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract IERC20 | undefined |




