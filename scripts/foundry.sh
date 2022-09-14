#!/usr/bin/env bash

# Test contracts ending with exactly "Test" don't require any forking
forge test --match-contract "$1.*Test$" -vvv || exit 1

# Test contracts ending with exactly "TestAvax" require Avalanche RPC and block number: 2022-04-25
forge test --match-contract "$1.*TestAvax$" --fork-url $AVAX_API --fork-block-number 13897000 -vvv || exit 1

# Test contracts ending with exactly "TestEth" require Ethereum RPC and block number: 2022-04-24
forge test --match-contract "$1.*TestEth$" --fork-url $ALCHEMY_API --fork-block-number 14650000 -vvv || exit 1

# Test contracts ending with exactly "TestArb" require Arbitrum RPC and block number: 2022-04-26
forge test --match-contract "$1.*TestArb$" --fork-url $ARBITRUM_API --fork-block-number 10600000 -vvv || exit 1

# Test contracts ending with exactly "TestOpt" require Optimism RPC and block number: 2022-04-26
forge test --match-contract "$1.*TestOpt$" --fork-url $OPTIMISM_API --fork-block-number 6600000 -vvv || exit 1

# Test contracts ending with exactly "TestMovr" require Moonriver RPC and block number: 2022-04-21
forge test --match-contract "$1.*TestMovr$" --fork-url $MOVR_API --fork-block-number 1730000 -vvv || exit 1

# Test contracts ending with exactly "TestAurora" require Aurora RPC and block number: 2022-06-24
forge test --match-contract "$1.*TestAurora$" --fork-url $AURORA_API --fork-block-number 68400000 -vvv || exit 1

# Test contracts ending with exactly "TestBoba" require Boba RPC and block number: 2022-06-25
forge test --match-contract "$1.*TestBoba$" --fork-url $BOBA_API --fork-block-number 697000 -vvv || exit 1

# Test contracts ending with exactly "TestBSC" require BSC RPC and block number: 2022-06-25
forge test --match-contract "$1.*TestBSC$" --fork-url $BSC_API --fork-block-number 19000000 -vvv || exit 1

# Test contracts ending with exactly "TestKlay" require KLAY RPC and block number: 2022-09-14
forge test --match-contract "$1.*TestKlay$" --fork-url $KLAY_API --fork-block-number 101222300 -vvv || exit 1