# Bridge Out Functions

## Naming

All functions allowing to bridge funds have the same naming convention: `[bridgeToken|bridgeGas][EVM|nonEVM]`.

- `[bridgeToken|bridgeGas]` specifies whether a ERC20 token, or native chain GAS needs bo be bridged.
- `[EVM|nonEVM]` specifies whether the destination chain is EVM-compatible or not. If chain is EVM-compatible, there's an additional parameter passed: `swapParams`, containing information about the swap that needs to be made the destination chain (can be left [empty](#empty-swapparams), if no swap in needed).

## SwapParams

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

## Modifiers

The only modifier present is `payable` for `swapGas<...>()`, to enable paying with native GAS for such transactions.

### Functions

```solidity
function bridgeTokenToEVM(
  uint256 amountIn,
  IBridge.SwapParams calldata initialSwapParams,
  address to,
  uint256 chainId,
  IBridge.SwapParams calldata destinationSwapParams
) external returns (uint256 amountBridged);

function bridgeTokenToNonEVM(
  uint256 amountIn,
  IBridge.SwapParams calldata initialSwapParams,
  bytes32 to,
  uint256 chainId
) external returns (uint256 amountBridged);

function bridgeGasToEVM(
  IBridge.SwapParams calldata initialSwapParams,
  address to,
  uint256 chainId,
  IBridge.SwapParams calldata destinationSwapParams
) external payable returns (uint256 amountBridged);

function bridgeGasToNonEVM(
  IBridge.SwapParams calldata initialSwapParams,
  bytes32 to,
  uint256 chainId
) external payable returns (uint256 amountBridged);

```

- `amountIn`: amount of tokens to bridge, in `tokenIn` decimals precision.
  > `msg.value` is used as amount of GAS user is willing to bridge for `bridgeGas<...>()`
- `initialSwapParams`: [valid](#valid-swapparams) parameters for swapping token into bridge token on **initial chain**, if needed. Otherwise, it's [empty](#empty-swapparams).
  - `minAmountOut`: minimum amount of bridge token to receive after swap on **initial chain**, otherwise the transaction **will be reverted**.
  - `path`: list of tokens, specifying the swap route on **initial chain**.
    - `path[0]`: starting token that will be pulled from user (`WGAS` for `bridgeGAS<...>()`).
    - `path[1]`: token received after the first swap of the route.
    - `...`
    - `path[path.length-1]`: token that will be used for bridging on **initial chain**.
  - `adapters`: list of Synapse adapters, that will be used for swaps on **initial chain**.
  - `deadline`: deadline for swap on **initial chain**. If deadline check is failed, the transaction **will be reverted**.
- `to`: address that will receive the tokens on destination chain. Unless user specified a different address, this should be user's address.
  > UI should have a warning, that is another address is specified for receiving tokens on destination chain, that it should always be the non-custodial wallet, otherwise the funds might be lost (especially when bridging into destination chain's GAS).
- `chainId`: destination chain's ID.
- `destinationSwapParams`: [valid](#valid-swapparams) parameters for swapping token into bridge token on **destination chain**, if needed. Otherwise, it's [empty](#empty-swapparams).
  - `minAmountOut`: minimum amount of bridge token to receive after swap on **initial chain**, otherwise the transaction **will be reverted**.
  - `path`: list of tokens, specifying the swap route on **destination chain**.
    - `path[0]`: token that will be used for bridging on **destination chain**.
    - `path[1]`: token received after the first swap of the route.
    - `...`
    - `path[path.length-1]`: token that user will receive on **destination chain**.
      > If final token is `WGAS`, it will be automatically unwrapped and sent as native chain `GAS`.
  - `adapters`: list of Synapse adapters, that will be used for swaps on **initial chain**.
  - `deadline`: deadline for swap on **destination chain**. If deadline check is failed, user **will receive bridge token**.
    > If bridge token on **destination chain** is `WGAS`, it will be automatically unwrapped and sent as native chain `GAS`.
- `amountBridged`: function returns amount of tokens bridged, in bridge token decimals precision.

> `initialSwapParams.path[N-1]` and `destinationSwapParams.path[0]` are two counterparts of the bridge token, representing its addresses on initial and destination chain respectively.

> Some tokens are not directly compatible with the bridge, and require a `Bridge Wrapper` contract for actual bridging. This concept is abstracted away from user/UI. `initialSwapParams.path[N-1]` and `destinationSwapParams.path[0]` **are always** the tokens, that are actually used/traded on their respective chains.
