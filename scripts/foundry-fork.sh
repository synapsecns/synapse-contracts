#!/usr/bin/env bash

# Test contracts ending with exactly "TestFork" read env variables using cheatcodes
forge test --match-contract "$1.*TestFork$" -vvv || exit 1

#TODO: fork tests should read env variables using cheatcodes
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

# Test contracts ending with exactly "TestCanto" require Canto RPC and block number: 2022-12-02
forge test --match-contract "$1.*TestCanto$" --fork-url $CANTO_API --fork-block-number 1894000 -vvv || exit 1