#!/usr/bin/env bash

# Build the contracts first
forge build

# Find all test files used for the integration tests.
INTEGRATION_TESTS=$(find test -type f -name "*Integration*.t.sol")
# Print the amount of integration tests found.
echo "Found $(wc -w <<<$INTEGRATION_TESTS) integration tests"

# Track the integration tests for contracts that are not yet deployed.
TESTS_TO_RUN=()

for TEST_FILE in $INTEGRATION_TESTS; do
  # First, get the name of the defined contract in the test file.
  # There should be a single line starting with "contract <CONTRACT_NAME>" in the file.
  COUNT=$(grep -c "^contract" $TEST_FILE)
  if [ $COUNT -ne 1 ]; then
    echo "  Found $COUNT contracts in $TEST_FILE, expected 1"
    exit 1
  fi
  CONTRACT_NAME=$(awk '/^contract/ {print $2}' $TEST_FILE)
  # Then, run the InspectIntegration script to get the chain and contract name.
  # The argument is $TEST_FILE_BASENAME:$CONTRACT_NAME.
  # Extract base name from file path.
  INSPECT_PATH="script/integration/InspectIntegration.s.sol"
  INSPECT_ARGS=$(basename $TEST_FILE):$CONTRACT_NAME
  # Its output is:
  # == Logs ==
  #   $CHAIN_NAME $CONTRACT_NAME
  # We need to extract the chain and contract name from this output.
  TEST_ARGS=$(forge script $INSPECT_PATH --sig "run(string)" $INSPECT_ARGS | awk '/==/ {getline; print}')
  CHAIN_NAME=$(awk '{print $1}' <<<$TEST_ARGS)
  CONTRACT_NAME=$(awk '{print $2}' <<<$TEST_ARGS)
  RUN_IF_DEPLOYED=$(awk '{print $3}' <<<$TEST_ARGS)
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
  DEPLOYMENT_FILE="deployments/${CHAIN_NAME}/${CONTRACT_NAME}.json"
  if [ -f "${DEPLOYMENT_FILE}" ]; then
    if [ "${RUN_IF_DEPLOYED}" -eq 0 ]; then
      echo "  ✅ ${CONTRACT_NAME} on ${CHAIN_NAME}: skipping (already deployed)"
      continue
    fi
    echo "  ❗ ${CONTRACT_NAME} on ${CHAIN_NAME}: testing (deployed)"
  else
    echo "  ❓ ${CONTRACT_NAME} on ${CHAIN_NAME}: testing (not deployed)"
  fi
  # Add the test file to the list of tests to run
  TESTS_TO_RUN+=("${TEST_FILE}")
done

echo "Running ${#TESTS_TO_RUN[@]} integration tests"
# Run integration tests one by one to decrease the amount of rate limit errors.
for TEST_FILE in ${TESTS_TO_RUN[@]}; do
  forge test --match-path $TEST_FILE
  # Sleep for 5 seconds to avoid rate limit errors.
  sleep 5
done
