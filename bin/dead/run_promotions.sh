#!/usr/bin/env bash
set -Eeu

export MY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cat ${MY_DIR}/../tests/diff-snapshots/new-flow.json | python3 ${MY_DIR}/promotions.py

