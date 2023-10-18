#!/usr/bin/env bash

# Build the contracts first
forge build

# Find all test files used for the integration tests.
INTEGRATION_TESTS=$(find test -type f -name "*Integration*.t.sol")
# Print the amount of integration tests found.
echo "Found $(echo $INTEGRATION_TESTS | wc -w) integration tests"

for TEST_FILE in $INTEGRATION_TESTS; do
  # First, run the test as a forge script. This will print the following:
  # == Logs ==
  #   $CHAIN_NAME $CONTRACT_NAME
  # We need to extract the chain and contract name from this output.
  TEST_ARGS=$(forge script $TEST_FILE | grep "==" -A1 | tail -n 1)
  CHAIN_NAME=$(echo $TEST_ARGS | awk '{print $1}')
  CONTRACT_NAME=$(echo $TEST_ARGS | awk '{print $2}')
  # Check if the deployment for the tested contract already exists.
  DEPLOYMENT_FILE="deployments/$CHAIN_NAME/$CONTRACT_NAME.json"
  if [ -f $DEPLOYMENT_FILE ]; then
    echo "  $CONTRACT_NAME already deployed on $CHAIN_NAME: skipping test"
  else
    echo "  $CONTRACT_NAME not yet deployed on $CHAIN_NAME: running test"
    # Run the test and exit if it fails.
    forge test --match-path $TEST_FILE -vvv || exit 1
  fi
done
