#!/usr/bin/env bash
set -Eeu

export MY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cat ${MY_DIR}/../tests/expected/2.json |
  docker run --rm -i \
    --volume ${MY_DIR}/promotions.py:/usr/src/myapp/promotions.py \
    --workdir /usr/src/myapp \
    python:alpine ./promotions.py
