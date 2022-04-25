#!/usr/bin/env bash

forge test --match-contract "TestMovr" --fork-url $MOVR_API --fork-block-number 1730000 -vvvv
forge test --match-contract "Test$" -vvvv