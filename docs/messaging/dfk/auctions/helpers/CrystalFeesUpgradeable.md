# CrystalFeesUpgradeable

*Frisky Fox - Defi Kingdoms*

> CrystalFees



*Functionality that supports paying fees.*

## Methods

### crystalToken

```solidity
function crystalToken() external view returns (contract IERC20Upgradeable)
```

CONTRACTS ///




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract IERC20Upgradeable | undefined |

### feeAddresses

```solidity
function feeAddresses(uint256) external view returns (address)
```

STATE ///



#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### feePercents

```solidity
function feePercents(uint256) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### setFees

```solidity
function setFees(address[] _feeAddresses, uint256[] _feePercents) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _feeAddresses | address[] | undefined |
| _feePercents | uint256[] | undefined |




