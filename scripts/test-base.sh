#!/usr/bin/env bash

(set -a; source .env; set +a; ./scripts/foundry-base.sh $1)