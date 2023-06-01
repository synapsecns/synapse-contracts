This directory contains tests that use `LinkedPool` contracts as the liquidity pools with V1 of `SynapseRouter` and `SwapQuoter` contracts. In other words, the compatibility of `SynapseRouter` and `SwapQuoter` contracts with `LinkedPool` contracts is tested here.

For this purpose, all existing `SynapseRouter` and `SwapQuoter` tests from parent directory are reused with a modified setup to include `LinkedPool` contracts.

We're not including GMX and Jewel tests, as `LinkedPool` contracts are not required for them.