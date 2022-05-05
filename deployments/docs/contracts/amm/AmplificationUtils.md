# AmplificationUtils



> AmplificationUtils library

A library to calculate and ramp the A parameter of a given `SwapUtils.Swap` struct. This library assumes the struct is fully validated.



## Methods

### A_PRECISION

```solidity
function A_PRECISION() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### MAX_A

```solidity
function MAX_A() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |



## Events

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

### StopRampA

```solidity
event StopRampA(uint256 currentA, uint256 time)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| currentA  | uint256 | undefined |
| time  | uint256 | undefined |



