#!/usr/bin/env bash

# Build the contracts first
forge build

# Find all test files used for the integration tests.
INTEGRATION_TESTS=$(find test -type f -name "*Integration*.t.sol")
# Print the amount of integration tests found.
echo "Found $(echo $INTEGRATION_TESTS | wc -w) integration tests"

# Track the integration tests for contracts that are not yet deployed.
NOT_DEPLOYED_TESTS=()

for TEST_FILE in $INTEGRATION_TESTS; do
  # First, get the name of the defined contract in the test file.
  # There should be a single line starting with "contract <CONTRACT_NAME>" in the file.
  COUNT=$(grep -c "^contract" $TEST_FILE)
  if [ $COUNT -ne 1 ]; then
    echo "  Found $COUNT contracts in $TEST_FILE, expected 1"
    exit 1
  fi
  CONTRACT_NAME=$(grep "^contract" $TEST_FILE | awk '{print $2}')
  # Then, run the InspectIntegration script to get the chain and contract name. 
  # The argument is $TEST_FILE_BASENAME:$CONTRACT_NAME.
  # Extract base name from file path.
  INSPECT_PATH="script/integration/InspectIntegration.s.sol"
  INSPECT_ARGS=$(basename $TEST_FILE):$CONTRACT_NAME
  # Its output is:
  # == Logs ==
  #   $CHAIN_NAME $CONTRACT_NAME
  # We need to extract the chain and contract name from this output.
  TEST_ARGS=$(forge script $INSPECT_PATH --sig "run(string)" $INSPECT_ARGS | grep "==" -A1 | tail -n 1)
  CHAIN_NAME=$(echo $TEST_ARGS | awk '{print $1}')
  CONTRACT_NAME=$(echo $TEST_ARGS | awk '{print $2}')
  # Check that both the chain and contract name are not empty.
  if [ -z "$CHAIN_NAME" ] || [ -z "$CONTRACT_NAME" ]; then
    echo "  [CHAIN_NAME=$CHAIN_NAME] [CONTRACT_NAME=$CONTRACT_NAME]"
    echo "  Could not extract chain and contract name from test file $TEST_FILE"
    exit 1
  fi
  # Check that the chain name is valid: deployments/$CHAIN_NAME must exist.
  if [ ! -d "deployments/$CHAIN_NAME" ]; then
    echo "  Chain $CHAIN_NAME does not exist"
    exit 1
  fi
  # Check if the deployment for the tested contract already exists.
  DEPLOYMENT_FILE="deployments/$CHAIN_NAME/$CONTRACT_NAME.json"
  if [ -f $DEPLOYMENT_FILE ]; then
    echo "  ✅ $CONTRACT_NAME on $CHAIN_NAME: skipping (already deployed)"
  else
    echo "  ❓ $CONTRACT_NAME on $CHAIN_NAME: testing (not deployed)"
    NOT_DEPLOYED_TESTS+=($TEST_FILE)
  fi
done

echo "Running $(echo ${NOT_DEPLOYED_TESTS[@]} | wc -w) integration tests"
for TEST_FILE in ${NOT_DEPLOYED_TESTS[@]}; do
  forge test -vvv --match-path $TEST_FILE
done
