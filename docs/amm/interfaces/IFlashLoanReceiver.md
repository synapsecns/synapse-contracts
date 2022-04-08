# IFlashLoanReceiver

*Aave*

> IFlashLoanReceiver interface

Interface for the Nerve fee IFlashLoanReceiver. Modified from Aave&#39;s IFlashLoanReceiver interface. https://github.com/aave/aave-protocol/blob/4b4545fb583fd4f400507b10f3c3114f45b8a037/contracts/flashloan/interfaces/IFlashLoanReceiver.sol

*implement this interface to develop a flashloan-compatible flashLoanReceiver contract**

## Methods

### executeOperation

```solidity
function executeOperation(address pool, address token, uint256 amount, uint256 fee, bytes params) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| pool | address | undefined |
| token | address | undefined |
| amount | uint256 | undefined |
| fee | uint256 | undefined |
| params | bytes | undefined |




