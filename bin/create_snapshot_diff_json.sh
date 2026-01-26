#!/usr/bin/env bash
set -Eeu

export ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/bin/lib.sh"

KOSLI_HOST="${KOSLI_HOST:-https://app.kosli.com}"
KOSLI_ORG="${KOSLI_ORG:-cyber-dojo}"
KOSLI_API_TOKEN="${KOSLI_API_TOKEN:-read-only-dummy}"
KOSLI_AWS_BETA="${KOSLI_AWS_BETA:-aws-beta}"
KOSLI_AWS_PROD="${KOSLI_AWS_PROD:-aws-prod}"

# NOTE: in a Github Action, stdout and stderr are multiplexed together.
# This means that the output of the $(subshell) is not just stdout, it is stdout+stderr!
# To ensure the Kosli CLI does not print to stderr, we set the --debug=false flag explicitly.

exit_non_zero_unless_installed kosli jq

diff="$(kosli diff snapshots "${KOSLI_AWS_BETA}" "${KOSLI_AWS_PROD}" \
    --host="${KOSLI_HOST}" \
    --org="${KOSLI_ORG}" \
    --api-token="${KOSLI_API_TOKEN}" \
    --debug=false \
    --output=json)"

# Temporary edit till Kosli CLI multi-host mode bug is fixed.
fix="$(echo "${diff}" | sed 1d)"
jq --raw-output . <<< "${fix}"

# Restore this when bug fixed.
# jq --raw-output . <<< "${diff}"

