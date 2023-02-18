#!/usr/bin/env bash
# This script will deploy SynapseRouter and its auxilary contracts on the given chain.
# Deployment address on every chain will depend on the deployer address initial nonce.
# Existing deployments will be reused rather than overwritten.

# Usage: ./script/sh/router-deploy.sh <chainName> eip-1559|legacy true|false

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# First argument is the chain name
if [ -z "$1" ]; then
  echo -e "${RED}Error: Please provide a chain name as the first argument.${NC}"
  exit 1
elif [ ! -e "deployments/$1/.chainId" ]; then
  echo -e "${RED}Error: '$1' is not a valid chain name${NC}"
  exit 1
elif [ ! -e "script/configs/$1/SynapseRouter.dc.json" ]; then
  echo -e "${RED}Config doesn't exist for $1${NC}"
  exit 1
fi
forgeArgs="-f $1 --slow"
# Second argument is whether the chain supports EIP-1559
case $2 in
"eip-1559") ;;

"legacy" | "")
  forgeArgs=$forgeArgs" --legacy"
  ;;
*)
  echo -e "${RED}Unknown second paratemer: '$2'${NC}"
  exit 1
  ;;
esac
# Third argument is whether tx needs to be broadcasted
case $3 in
"true")
  echo -e "${YELLOW}Deploy tx WILL be broadcasted on $1${NC}"
  forgeArgs=$forgeArgs" --broadcast --verify"
  ;;
"false" | "")
  echo -e "${YELLOW}Deploy tx WILL NOT be broadcasted on $1${NC}"
  forgeArgs=$forgeArgs" --sig 'runDry()'"
  ;;
*)
  echo -e "${RED}Unknown third paratemer: '$3'${NC}"
  exit 1
  ;;
esac

# Special logic for some of the chains
case $1 in
"boba" | "klatyn")
  # Skip simulation if this is the deployment
  if [ "$3" == "true" ]; then
    forgeArgs=$forgeArgs" --skip-simulation"
  fi
  ;;
esac

bash -x -c "forge script $forgeArgs script/router/DeployRouter.s.sol"
# Check if deployment went fine
if [ $? -ne 0 ]; then
  echo -e "${RED}There was an error during deployment on $1${NC}"
  # Trim deployments if tx was broadcasted
  if [ "$3" == "true" ]; then
    echo -e "${YELLOW}Trimming deployments: SynapseRouter${NC}"
    forge script -f $1 script/utils/TrimDeployment.s.sol --sig "trim(string)" SynapseRouter
    echo -e "${YELLOW}Trimming deployments: SwapQuoter${NC}"
    forge script -f $1 script/utils/TrimDeployment.s.sol --sig "trim(string)" SwapQuoter
  fi
  exit 1
else
  echo -e "${GREEN}Deployed successfully on $1${NC}"
fi
# Verify deployed contracts if tx was broadcasted
if [ "$3" == "true" ]; then
  echo -e "${YELLOW}Verifying deployed contracts on $1${NC}"
  ./script/sh/verify-contract.sh $1 SynapseRouter
  ./script/sh/verify-contract.sh $1 SwapQuoter
fi
