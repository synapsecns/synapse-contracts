# SynapseERC20Factory









## Methods

### deploy

```solidity
function deploy(address synapseERC20Address, string name, string symbol, uint8 decimals, address owner) external nonpayable returns (address)
```

Deploys a new node



#### Parameters

| Name | Type | Description |
|---|---|---|
| synapseERC20Address | address | address of the synapseERC20Address contract to initialize with |
| name | string | Token name |
| symbol | string | Token symbol |
| decimals | uint8 | Token name |
| owner | address | admin address to be initialized with |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | Address of the newest node management contract created* |



## Events

### SynapseERC20Created

```solidity
event SynapseERC20Created(address contractAddress)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| contractAddress  | address | undefined |



