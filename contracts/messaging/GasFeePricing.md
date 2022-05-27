# Gas Fee Pricing for Message Bridge

## Setup

On every chain `MessageBusUpgradeable` and `GasFeePricingUpgradeable` are deployed. `GasFeePricing` contracts are using `MessageBus` to communicate with each other, so they are set up as the "trusted remote" for one another.

For every chain we're considering following information:

- `gasTokenPrice`: price of chain's gas token (ETH, AVAX, BNB, ...)
- `gasUnitPrice`: price of a single gas unit (usually referred as chain's "gwei gas price")

> Both values are supposed to reflect the latest "average" price.

`GasFeePricing` contract is storing this information both for the local chain, as well as for all known remote chains. Whenever information for a **local chain** is updated on any of the `GasFeePricing` contracts, it sends messages to all the remote `GasFeePricing` contracts, so they can update it as well.

This way, the information about chain's gas token/unit prices is synchronized across all chains.

## Message Passing

Any contract can interact with `MessageBus` to send a message to a remote chain, specifying both a gas airdrop and a gas limit on the remote chain.
Every remote chain has a different setting for the maximum amount of gas available for the airdrop. That way, the airdrop is fully flexible, and can not be taken advantage of by the bad actors. This value (for every remote chain) is also synchronized across all the chains.

## Fee calculation

### Basic calculation

The fee is split into two parts. Both parts are quoted in the local gas token.

- Fee for providing gas airdrop on a remote chain. Assuming dropping `gasDrop` worth of the remote gas token.

```go
feeGasDrop = gasDrop * remoteGasTokenPrice / localGasTokenPrice
```

- Fee for executing message on a remote chain. Assuming providing `gasLimit` gas units on the remote chain.

```go
feeGasUsage = max(
  minRemoteFeeUsd / localGasTokenPrice,
  gasLimit * remoteGasUnitPrice * remoteGasTokenPrice / localGasTokenPrice
)
```

> `minRemoteFeeUsd` is the minimum fee (in $), taken for the gas usage on a remote chain. It is specific to the remote chain, and does not take a local chain into account. `minRemoteFeeUsd` (for every remote chain) is also synchronized across all the chains.

Note that both fees will express the _exact expected costs_ of delivering the message.

### Monetizing the messaging.

Introduce markup. Markup is a value of `0%`, or higher. Markup means how much more is `MessageBus` charging, compared to [expected costs](#basic-calculation).

Markups are separate for the gas airdrop, and the gas usage. This means that the final fee formula is

```go
fee = (100% + markupGasDrop) * feeGasDrop + (100% + markupGasUsage) * feeGasUsage
```

- Markups are specific to a "local chain - remote chain" pair.
- `markupGasUsage` should be set higher for the remote chains, known to have gas spikes (Ethereum, Fantom).
- `markupGasDrop` can be set to 0, when both local and remote chain are using the same gas token.
  > Gas airdrop amount is limited, so it's not possible to bridge gas by sending an empty message with a huge airdrop.
- `markupGasDrop <= markupGasUsage` makes sense, as the price ratio for the gas usage is more volatile, since it's taking into account the gas unit price as well.
- `markupGasDrop` and `markupGasUsage` should be set higher for such a "local chain - remote chain" pair, where gas local token price is less correlated with the remote gas token price.
