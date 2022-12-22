#!/usr/bin/env bash

(set -a; source .env; set +a; ./scripts/foundry-fork.sh $1)