#!/usr/bin/env bash

# Test contracts ending with exactly "TestFork" read env variables using cheatcodes
forge test --match-contract "$1.*TestFork$" -vvv || exit 1