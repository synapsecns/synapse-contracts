# How to: quote & execute a cross-chain swap via Synapse

## Setup

The first thing that is needed for the accurate quoting, is a map of all tokens, **bridged** by Synapse:Bridge. **Bridged** means a bridging transaction without any swaps on both initial and destination chain.

In other words:

1. Send token X, receive token Y: when doing a _simple_ `Ethereum -> BSC` bridge tx.
2. Send token Y, receive token X: when doing a _simple_ `BSC -> Ethereum` bridge tx.

**Map Example:**

```c
bridgeMap = {
    "nUSD": {
        "bsc": "0x23b891e5C62E0955ae2bD185990103928Ab817b3", // nUSD on BSC
        "ethereum": "0x1B84765dE8B7566e4cEAF4D0fD3c5aF52D3DdE4F", // nUSD on Mainnet
        ...
    },
    "nETH": {
        "arbitrum": "0x3ea9B0ab55F34Fb188824Ee288CeaEfC63cf908e", // nETH on Arbitrum
        "ethereum": "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2", // WETH is used on Mainnet
        ...
    },
    "JEWEL": {
        "avalanche": "0x997Ddaa07d716995DE90577C123Db411584E5E46", // synJEWEL on Avalanche
        "dfk": "0xCCb93dABD71c8Dad03Fc4CE5559dC3D89F67a260", // wJEWEL on DFK
        "harmony": "0x72cb10c6bfa5624dd07ef608027e366bd690048f", // JEWEL on Harmony
        ...
    },
    ...
}
```

Then, you would need addresses for Synapse `BridgeQuoter` contracts on all chains, as well as `BridgeConfig` contract address on Ethereum Mainnet.

## Understanding Quoter output format

```solidity
struct Offers.FormattedOffer{
    uint256[] amounts;
    address[] adapters;
    address[] path;
}
```

`N = adapters.length`: amount of swaps in `FormattedOffer`.

- `amounts[N+1]`: amount of tokens along the swap path. `amount[0]` is amount of staring tokens, `amount[1]` is amount of tokens after first swap, ..., `amount[N]` is amount of final tokens.
- `adapters[N]`: Synapse adapters, that enable the swaps. `adapters[0]` will be used for the first swap, ..., `adapters[N-1]` for the last.
- `path[N+1]`: list of tokens in the swap route. `path[0]` is initial token, `path[1]` is token received after first swap, ..., `path[N]` is final token.

> If `Quoter` fails to find _any path_ between starting and final tokens, it will return **void** `FormattedOffer`:
> `len(amounts) = len(adapters) = len(path) = 0`

## Understanding BridgeQuoter functions

```solidity
function findBestPathInitialChain(
  uint256 amountIn,
  address tokenIn,
  address tokenOut
) external view returns (Offers.FormattedOffer memory bestOffer);

function findBestPathDestinationChain(
  uint256 amountIn,
  address tokenIn,
  address tokenOut
) external view returns (Offers.FormattedOffer memory bestOffer);

```

Both functions will find you the best swap path between `tokenIn` and `tokenOut`, given that you start with exactly `amountIn` tokens. The only difference is the maximum amount of swaps that the `BridgeQuoter` will be using.

- On initial chain, user pays for gas, so higher amount of swaps is allowed.
- On destination chain, the relayer pays for gas, so amount of swaps might be set lower on more expensive chains (Ethereum Mainnet, for example).

> Note, that while you can use `findBestPathInitialChain` to find a more attractive, yet longer, swap on destination chain, it will be automatically rejected by the Bridge contract on destination chain. No cheating allowed!

## Understanding Bridge Swap Parameters

```solidity
struct SwapParams {
  uint256 minAmountOut;
  address[] path;
  address[] adapters;
  uint256 deadline;
}

```

- `minAmountOut`: minimum amount of tokens user is willing to receive after swap is completed, in final token's decimals precision. If swap results in less than `minAmountOut` tokens, it **will fail**.
- `path`: a list of tokens, describing the series of swaps. `path = [A, B, C]` means that two swaps will be made: `A -> B` and `B -> C`.
- `adapters`: a list of Synapse Adapters, that will do the swapping. `adapters = [AB, BC]` means that two adapters will be used: `AB` for `A -> B` swap, and `BC` for `B -> C` swap.
- `deadline`: Unix timestamp representing the deadline for swap to be completed. Swap **will fail**, if too much time passed since the transaction was submitted.

> Failed swap on initial chain this will lead to failed tx, and tokens **not** spent/bridged. On destination chain, however, failed swap will lead to user receiving bridged token, instead of the final token they specified.

### Valid SwapParams

- `swapParams` is considered **_valid_**, if `len(path) == len(adapters) + 1`.

### Empty SwapParams

- When there's no swap required, `SwapParams` should be **_empty_**, i.e.

```solidity
(swapParams.adapters.path == 0) &&
(swapParams.path.length == 1) &&
(swapParams.path[0] == neededToken)
```

> **_Empty_** `SwapParams` should have zero length array for `adapters`, and a single _needed token_ in `path`. For initial chain, that would be the starting token, for destination chain — the final token.

- `minAmountOut` and `deadline` are not checked for **_empty_** `swapParams`, but using following values is recommended for consistency:

```solidity
swapParams.minAmountOut = 0;
swapParams.deadline = type(uint256).max;
```

## Getting a Bridge fee

```solidity
function calculateSwapFee(
    address tokenAddress,
    uint256 chainID,
    uint256 amount,
    bool swapBridgedTokens
)
```

- `tokenAddress`: address of bridged token on destination chain
- `chainID`: ID of destination chain
- `amount`: amount of bridged tokens in token decimal precision on destination chain
- `swapBridgedTokens`: whether or not a token will be swapped on destination chain.
  > Higher minimum fee is present, when bridge transaction includes a swap on destination chain.

## Quoting a pre-set bridge transaction

Imagine, you have most of the parameters for the bridge transaction via Synapse:

1. Starting token `tokenS` on initial chain, and its amount `amountS`.
2. Bridge token `bridgeTokenIC` on initial chain, and its counterpart `bridgeTokenDC` on destination chain.
3. Final token `tokenF` on destination chain.

How much `tokenF` tokens user would have after a `tokenS -> tokenF` cross-chain swap? Consider following pseudo code:

```js
// IC refers to Initial Chain
if (tokenS != bridgeTokenIC) {
  // Ask quoter on initial chain to find the best swap path
  offerIC = BridgeQuoterIC.findBestPathInitialChain(
    (amountIn = amountS),
    (tokenIn = tokenS),
    (tokenOut = bridgeTokenIC),
  )

  if (offerIC.adapters.length == 0) {
    // no swap path was found, do whatever you think is reasonable
    return
  }

  amountOutIC = offerIC.amounts[offerIC.amounts.length - 1]

  swapParams = SwapParams(
    (minAmountOut = applySlippageIC(amountOutIC)),
    (path = offerIC.path),
    (adapters = offerIC.path),
    (deadline = deadlineIC),
  )
} else {
  // tokenS is the bridge token => no swap is required on initial chain
  amountOutIC = amountS

  swapParamsIC = SwapParams(
    (minAmountOut = 0),
    (path = [tokenS]),
    (adapters = []),
    (deadline = type(uint256).max),
  )
}

// DC refers to Destination Chain
// Ask BridgeConfig to calculate the bridge fee
bridgeFee = BridgeConfig.calculateSwapFee(
  (tokenAddress = bridgeTokenDC),
  (chainID = idDC),
  (amount = amountOutIC),
  (swapBridgedTokens = bridgeTokenDC != tokenF),
)

amountInDC = amountOutIC - bridgeFee

if (tokenF != bridgeTokenDC) {
  // Ask quoter on destination chain to find the best swap path
  offerDC = BridgeQuoterDC.findBestPathDestinationChain(
    (amountIn = amountInDC),
    (tokenIn = bridgeTokenDC),
    (tokenOut = tokenF),
  )

  if (offerDC.adapters.length == 0) {
    // no swap path was found, do whatever you think is reasonable
    return
  }

  amountF = offerDC.amounts[offerDC.amounts.length - 1]
  swapParamsDC = SwapParams(
    (minAmountOut = applySlippageDC(amountF)),
    (path = offerDC.path),
    (adapters = offerDC.path),
    (deadline = deadlineDC),
  )
} else {
  // token F is the bridge token => no swap is required on destination chain
  amountF = amountInDC

  swapParamsDC = SwapParams(
    (minAmountOut = 0),
    (path = [tokenF]),
    (adapters = []),
    (deadline = type(uint256).max),
  )
}
```

To submit a **Synapse: Bridge** transaction, consider following pseudo code (assuming you have the params from the previous one):

```js
  // First, approve BridgeRouter to spend starting token on initial chain
  // Use can use infinite approvals, feel free to read through
  // the contract to make sure BridgeRouter can't literally rug you
  tokenS.approve(BridgeRouterIC, amountS)

  // Then, submit a bridge transaction
  BridgeRouterIC.bridgeTokenToEVM(
    amountIn=amountS,
    initialSwapParams=swapParamsIC,
    to=userAddress,
    chainId=idDC,
    destinationSwapParams=swapParamsDC
  )

  // Or, if you start from initial chain gas
  BridgeRouterIC.bridgeGasToEVM{value: amountS}(
    initialSwapParams=swapParamsIC,
    to=userAddress,
    chainId=idDC,
    destinationSwapParams=swapParamsDC
  )
```

## Finding the best quote for Synapse:Bridge swap

Imagine that pseudo code from previous section is wrapped into function:

> `findBestSwap(tokenIn, amountIn, bridgeTokenIC, bridgeTokenDC, tokenOut)`

To find the best quote available, you would have to iterate through all possible bridge tokens, that are present on both initial and destination chain.

```js
  bestAmountF = 0
  // iterate through all bridge tokens
  for (bridgeToken of bridgeMap) {
    // get config for the bridge token
    config = bridgeMap[bridgeToken]

    // consider bridge token, only is it's present on both chains
    if (config.contains(initialChain) && config.contains(destinationChain)) {

      // find best quote for tokenS -> bridgeToken -> tokenF
      (amountF, swapParamsIC, swapParamsDC) = findBestSwap(
        tokenIn=tokenS,
        amountIn=amountS,
        bridgeTokenIC=config[initialChain],
        bridgeTokenDC=config[destinationChain],
        tokenOut=tokenF
      )

      // Save it, if it's better than local maximum
      if (amountF > bestAmountF) {
        bestAmountF = amountF
        bestSwapParamsIC = swapParamsIC,
        bestSwapParamsDC = swapParamsDC
      }
    }
  }
```

> Then, you can use pseudo code from previous section to execute the best found cross-chain swap.
