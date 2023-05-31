This directory contains tests that use `UniversalSwap` contracts as the liquidity pools with V1 of `SynapseRouter` and `SwapQuoter` contracts. In other words, the compatibility of `SynapseRouter` and `SwapQuoter` contracts with `UniversalSwap` contracts is tested here.

For this purpose, all existing `SynapseRouter` and `SwapQuoter` tests from parent directory are reused with a modified setup to include `UniversalSwap` contracts.

We're not including GMX and Jewel tests, as `UniversalSwap` contracts are not required for them.