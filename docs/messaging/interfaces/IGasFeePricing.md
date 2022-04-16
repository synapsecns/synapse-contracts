# IGasFeePricing









## Methods

### estimateGasFee

```solidity
function estimateGasFee(bytes _options) external nonpayable returns (uint256)
```

Returns srcGasToken fee to charge in wei for the cross-chain message based on the gas limit



#### Parameters

| Name | Type | Description |
|---|---|---|
| _options | bytes | Versioned struct used to instruct relayer on how to proceed with gas limits. Contains data on gas limit to submit tx with. |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### setCostPerChain

```solidity
function setCostPerChain(uint256 _dstChainId, uint256 _gasUnitPrice, uint256 _gasTokenPriceRatio) external nonpayable
```

Permissioned method to allow an off-chain party to set what each dstChain&#39;s gas cost is priced in the srcChain&#39;s native gas currency.  Example: call on ETH, setCostPerChain(43114, 30000000000, 25180000000000000) chain ID 43114 Average of 30 gwei cost to transaction on 43114 AVAX/ETH = 0.02518, scaled to gas in wei = 25180000000000000



#### Parameters

| Name | Type | Description |
|---|---|---|
| _dstChainId | uint256 | The destination chain ID - typically, standard EVM chain ID, but differs on nonEVM chains |
| _gasUnitPrice | uint256 | The estimated current gas price in wei of the destination chain |
| _gasTokenPriceRatio | uint256 | Gas ratio of dstGasToken / srcGasToken |




