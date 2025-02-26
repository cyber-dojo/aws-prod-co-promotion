#!/usr/bin/env bash
set -Eeu

export ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/bin/lib.sh"
exit_non_zero_unless_installed kosli jq

KOSLI_ORG=cyber-dojo
KOSLI_AWS_BETA=aws-beta
KOSLI_AWS_PROD=aws-prod

show_help()
{
    local -r MY_NAME=$(basename "${BASH_SOURCE[0]}")
    cat <<- EOF

    Use: ${MY_NAME}

    Overview:
      TODO

EOF
}

check_args()
{
  case "${1:-}" in
    '-h' | '--help')
      show_help
      exit 0
      ;;
    '')
      return 0
      ;;
    *)
      show_help
      exit 42
      ;;
  esac
}

candidates()
{
  check_args $@
  diff="$(kosli diff snapshots ${KOSLI_AWS_BETA} ${KOSLI_AWS_PROD} --org=${KOSLI_ORG} --api-token=${KOSLI_API_TOKEN:-sdsdf} --output=json)"
  echo "${diff}" | jq .
}

candidates $@
