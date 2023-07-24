# SynapseRouterV2 workflows

## Bridging

Bridging is exposed using `SynapseRouterV2.bridgeViaSynapse()` method. User can specify the optional swap to be taken on both origin and destination chains.

### Function parameters

| Parameter   | Type      | Description                                                  |
| ----------- | --------- | ------------------------------------------------------------ |
| recipient   | address   | User address on the destination chain                        |
| chainId     | uint256   | Destination chain id                                         |
| token       | address   | Initial token address on the origin chain                    |
| amount      | uint256   | Initial token amount                                         |
| tokenSymbol | string    | Symbol of a token that will be bridged                       |
| originQuery | SwapQuery | Information about the optional swap on the origin chain      |
| destQuery   | SwapQuery | Information about the optional swap on the destination chain |

### `SwapQuery` structure

| Parameter     | Type    | Description                                                          |
| ------------- | ------- | -------------------------------------------------------------------- |
| routerAdapter | address | Address of the router adapter that will perform the swap             |
| tokenOut      | address | Token address that will be received after the swap                   |
| minAmountOut  | uint256 | Minimum amount of the token that will be received, or tx will revert |
| deadline      | uint256 | Deadline for the swap, or tx will revert                             |
| rawParams     | bytes   | Raw bytes parameters that will be passed to the router adapter       |

> For swaps using Default Pools `routerAdapter` is set to `synapseRouterV2` address, which inherits from `DefaultAdapter`. These are whitelisted pools that allow swaps between correlated tokens.
>
> - Alternative adapters can be used to perform complex swaps, but only on the origin chain.
> - Only whitelisted pools are allowed for destination swaps, therefore only `synapseRouterV2` can be used as `routerAdapter` on the destination chain.
> - `routerAdapter` for both `originQuery` and `destQuery` can be set to `address(0)`, which will skip the swap on the given chain.

> Note: `minAmountOut` and `deadline` are used to prevent front-running attacks.
>
> - If swap on origin chain fails, the whole transaction will revert, and no bridging happens.
> - If swap on destination chain fails, user receives the bridged token on destination chain instead of `tokenOut`.

### Bridging workflow

1. User calls `SynapseRouterV2.bridgeViaSynapse()` method on the origin chain.
   > User needs to approve `SynapseRouterV2` for spending `token` before calling this method.
2. Based on the `tokenSymbol` the address of the Bridge Adapter supporting given symbol is determined.
   > - `originQuery.tokenOut` needs to match `tokenSymbol`, or the transaction will revert.
   > - Transaction will also revert, if `tokenSymbol` is not supported by any Bridge Adapter.
3. `(token, amount)` is pulled from the user, and transferred to the `originQuery.routerAdapter`.
4. `originQuery.routerAdapter` is called to perform a swap on the origin chain.
   > - Swap from `token` to `originQuery.tokenOut` will be performed.
5. The Router Adapter performs a swap, and transfers `tokenOut` to the `BridgeAdapter` contract.
   > - Note: if `originQuery.routerAdapter` is empty, steps 3-5 are skipped, and `(token, amount)` is pulled from user to the `BridgeAdapter` contract instead.
6. `BridgeAdapter` is called to initiate the bridging to destination chain.

![Bridging workflow](./bridge.png)
