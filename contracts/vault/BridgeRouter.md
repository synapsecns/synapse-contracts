# Bridge Out Functions

## Naming

All functions allowing to bridge funds have the same naming convention: `[bridgeToken|bridgeGas][EVM|nonEVM]`.

1. `[bridgeToken|bridgeGas]` specifies whether a ERC20 token, or native chain GAS needs bo be bridged.
2. `[EVM|nonEVM]` specifies whether the destination chain is EVM-compatible or not. If chain is EVM-compatible, there's an additional parameter passed: `swapParams`,
   containing information about the swap that needs to be made on the destination chain (can be left empty, if no swap in needed).

## Modifiers

The only modifier present is `payable` for `swapGasAndBridgeTo[EVM|nonEVM]`, to enable paying with native GAS for such transactions.

## Parameters

### SwapParams

```solidity
struct IBridge.SwapParams {
    uint256 minAmountOut;
    address[] path;
    address[] adapters;
    uint256 deadline;
}
```

1. `minAmountOut` minimum amount of tokens user is willing to receive after swap is completed, in final token's decimals precision. If swap results in less than `minAmountOut` tokens, it will fail. On initial chain this will lead to failed tx, and tokens spent/bridged. On destination chain, however, failed swap will lead to user receiving bridged token, instead of the final token they specified.
2. `path` is a list of tokens, describing the series of swaps. `path = [A, B, C]` means that two swaps will be made: `A -> B` and `B -> C`.
3. `adapters` is a list of Synapse Adapters, that will do the swapping. `adapters = [AB, BC]` means that two adapters will be used: `AB` for `A -> B` swap, and `BC` for `B -> C` swap.
4. `deadline` is unix timestamp representing the deadline for swap to be completed. Swap will fail, if too much time passed since the transaction was submitted. See (1) for initial/destination chain failed swap description.

When there's no swap required, `SwapParams` should be empty, i.e.

```solidity
(swapParams.path.length == 0) && (swapParams.adapters.path == 0)
```

`minAmountOut` and `deadline` are not checked for empty `swapParam`, but using following values is recommended for consistency:

```solidity
swapParams.minAmountOut = 0;
swapParams.deadline = type(uint256).max;
```

### Functions

```solidity
function bridgeTokenToEVM(
  IERC20 tokenIn,
  uint256 amountIn,
  IBridge.SwapParams calldata initialSwapParams,
  address to,
  uint256 chainId,
  IBridge.SwapParams calldata bridgedSwapParams
) external returns (uint256 amountBridged);

function bridgeTokenToNonEVM(
  IERC20 tokenIn,
  uint256 amountIn,
  IBridge.SwapParams calldata initialSwapParams,
  bytes32 to,
  uint256 chainId
) external returns (uint256 amountBridged);

```

1. `tokenIn` is the token that user wants to bridge. if there's no swap on initial chain, in most cases this is also the bridge token, but some tokens are not directly compatible with the bridge, and require a `Bridge Wrapper` contract for actual bridging. This concept is abstracted away from user/UI. `tokenIn` is **always** the token that will be pulled from user for bridging.
2. `amountIn` is amount of tokens to bridge, in `tokenIn` decimals precision.
3. `initialSwapParams` specifies specifies the parameters for swapping token into bridge token on initial chain, if needed. Otherwise, it's empty (see `SwapParams` section above). Just like in (1), the `Bridge Wrapper` concept is abstracted away, use actual (underlying) token as `initialSwapParams.path[N-1]`, no need to worry about if token is supported natively by the **Synapse:Bridge** or not.
4. `to` is address that will receive the tokens on destination chain. Unless user specified a different address, this should be user's address. UI should have a warning, that is another address is specified for receiving tokens on destination chain, that it should always be the non-custodial wallet, otherwise the funds might be lost (especially when bridging into destination chain's GAS).
5. `chainId` specifies the destination chain's ID.
6. `bridgedSwapParams` specifies specifies the parameters for swapping bridged token, if needed. Otherwise, it's empty (see `SwapParams` section above).
7. `amountBridged`: function returns amount of tokens bridged, in bridge token decimals precision.

```solidity
function bridgeGasToEVM(
  IBridge.SwapParams calldata initialSwapParams,
  address to,
  uint256 chainId,
  IBridge.SwapParams calldata bridgedSwapParams
) external returns (uint256 amountBridged);

function bridgeGasToNonEVM(
  IBridge.SwapParams calldata initialSwapParams,
  bytes32 to,
  uint256 chainId
) external payable returns (uint256 amountBridged);

```

1. `msg.value` is used as amount of GAS user is willing to bridge.
2. `initialSwapParams` specifies specifies the parameters for swapping token into bridge token on initial chain, if needed. Otherwise, it's empty (see `SwapParams` section above). Just like in `bridgeTokenToEVM`, the `Bridge Wrapper` concept is abstracted away, use actual (underlying) token as `initialSwapParams.path[N-1]`, no need to worry about if token is supported natively by the **Synapse:Bridge** or not.
3. `to` is address that will receive the tokens on destination chain. Unless user specified a different address, this should be user's address. UI should have a warning, that is another address is specified for receiving tokens on destination chain, that it should always be the non-custodial wallet, otherwise the funds might be lost (especially when bridging into destination chain's GAS).
4. `chainId` specifies the destination chain's ID.
5. `bridgedSwapParams` specifies specifies the parameters for swapping bridged token, if needed. Otherwise, it's empty (see `SwapParams` section above).
6. `amountBridged`: function returns amount of tokens bridged, in bridge token decimals precision.
