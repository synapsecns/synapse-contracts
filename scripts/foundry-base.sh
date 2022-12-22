#!/usr/bin/env bash

# Test contracts ending with exactly "Test" don't require any forking
forge test --match-contract "$1.*Test$" -vvv || exit 1