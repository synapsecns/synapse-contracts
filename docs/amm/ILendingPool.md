# ILendingPool









## Methods

### deposit

```solidity
function deposit(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external nonpayable
```



*Deposits an `amount` of underlying asset into the reserve, receiving in return overlying aTokens. - E.g. User deposits 100 USDC and gets in return 100 aUSDC*

#### Parameters

| Name | Type | Description |
|---|---|---|
| asset | address | The address of the underlying asset to deposit |
| amount | uint256 | The amount to be deposited |
| onBehalfOf | address | The address that will receive the aTokens, same as msg.sender if the user   wants to receive them on his own wallet, or a different address if the beneficiary of aTokens   is a different wallet |
| referralCode | uint16 | Code used to register the integrator originating the operation, for potential rewards.   0 if the action is executed directly by the user, without any middle-man* |

### withdraw

```solidity
function withdraw(address asset, uint256 amount, address to) external nonpayable returns (uint256)
```



*Withdraws an `amount` of underlying asset from the reserve, burning the equivalent aTokens owned E.g. User has 100 aUSDC, calls withdraw() and receives 100 USDC, burning the 100 aUSDC*

#### Parameters

| Name | Type | Description |
|---|---|---|
| asset | address | The address of the underlying asset to withdraw |
| amount | uint256 | The underlying amount to be withdrawn   - Send the value type(uint256).max in order to withdraw the whole aToken balance |
| to | address | Address that will receive the underlying, same as msg.sender if the user   wants to receive it on his own wallet, or a different address if the beneficiary is a   different wallet |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | The final amount withdrawn* |




