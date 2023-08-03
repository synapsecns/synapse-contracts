This directory contains tests that use `SwapQuoterV2` contracts instead of `SwapQuoter`, as well as `LinkedPool` contracts as the liquidity pools, together with `SynapseRouter`. In other words, the compatibility of `SynapseRouter` with `SwapQuoterV2` + `LinkedPool` is tested here.

For this purpose, all existing `SynapseRouter` and `SwapQuoter` tests from parent directory are reused with a modified setup to deploy `SwapQuoterV2` contracts instead of `SwapQuoter`. Also, `LinkedPool` contracts are used as the whitelisted liquidity pools for all bridge tokens instead of Mainnet (Nexus) nUSD.
