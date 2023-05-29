This directory contains tests that use `SwapQuoterV2` contracts instead of `SwapQuoter`, together with `SynapseRouter` and plain StableSwap pools. In other words, the compatibility of `SynapseRouter` and `SwapQuoterV2` is tested here.

For this purpose, all existing `SynapseRouter` and `SwapQuoter` tests from parent directory are reused with a modified setup to deploy `SwapQuoterV2` contracts instead of `SwapQuoter`.
