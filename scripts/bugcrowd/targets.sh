#! /usr/bin/env bash
set -euo pipefail

export ENDPOINT="/targets"
export DATA_DIR="data${ENDPOINT}"

. ./scripts/bugcrowd/api.sh

export PARAMS=()

setup
fetch_all
concatenate_data
