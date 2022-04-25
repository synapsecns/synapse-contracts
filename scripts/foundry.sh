#!/usr/bin/env bash

# Test contracts ending with exactly "Test" don't require any forking
forge test --match-contract "$1.*Test$" -vvvv

# Test contracts ending with exactly "TestMovr" require Moonriver RPC and block number
forge test --match-contract "$1.*TestMovr$" --fork-url $MOVR_API --fork-block-number 1730000 -vvvv