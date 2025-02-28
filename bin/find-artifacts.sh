#!/usr/bin/env bash
set -Eeu

export ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/bin/lib.sh"
exit_non_zero_unless_installed kosli jq

KOSLI_HOST="${KOSLI_HOST:-https://app.kosli.com}"
KOSLI_ORG="${KOSLI_ORG:-cyber-dojo}"
KOSLI_API_TOKEN="${KOSLI_API_TOKEN:-read-only-dummy}"
KOSLI_AWS_BETA="${KOSLI_AWS_BETA:-aws-beta}"
KOSLI_AWS_PROD="${KOSLI_AWS_PROD:-aws-prod}"

#diff="$(kosli diff snapshots "${KOSLI_AWS_BETA}" "${KOSLI_AWS_PROD}" \
#    --host="${KOSLI_HOST}" \
#    --org="${KOSLI_ORG}" \
#    --api-token="${KOSLI_API_TOKEN}" \
#    --output=json)"

diff="$(cat "${ROOT_DIR}/docs/diff-snapshot.json")"

show_help()
{
    local -r MY_NAME=$(basename "${BASH_SOURCE[0]}")
    cat <<- EOF

    Use: ${MY_NAME}

    Uses the Kosli CLI to find which Artifacts are running in cyber-dojo's https://beta.cyber-dojo.org
    AWS staging environment that are NOT also running in cyber-dojo's https://cyber-dojo.org AWS prod environment.
    Creates a json file in the bin/json/ directory for on each Artifact. Viz, the Artifact's
    full name (in its AWS ECR registry), it fingerprint (sha256 digest), and its service-name. Eg

             name: 244531986313.dkr.ecr.eu-central-1.amazonaws.com/saver:6e191a0@sha256:b3237b0...7a5b6ef
      fingerprint: b3237b0e615e7041c23433faeee0bacd6ec893e89ae8899536433e4d27a5b6ef
          service: saver

    Also creates a json file containing the json expression for a Github Action matrix.

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

write_json_files()
{
  from="$(echo "${diff}" | jq -r '.snappish1.snapshot_id')"
  to="$(echo "${diff}" | jq -r '.snappish2.snapshot_id')"

  echo "FROM: ${from}"
  echo "  TO: ${to}"

  local -r artifacts_length=$(echo "${diff}" | jq -r '.snappish1.artifacts | length')
  for ((n=0; n < ${artifacts_length}; n++))
  do
      artifact="$(echo "${diff}" | jq -r ".snappish1.artifacts[$n]")"  # eg {...}
      name="$(echo "${artifact}" | jq -r '.name')"                     # eg 244531986313.dkr.ecr.eu-central-1.amazonaws.com/saver:6e191a0@sha256:b3237b0e615e7041c23433faeee0bacd6ec893e89ae8899536433e4d27a5b6ef
      fingerprint="$(echo "${artifact}" | jq -r '.fingerprint')"       # eg b3237b0e615e7041c23433faeee0bacd6ec893e89ae8899536433e4d27a5b6ef
      flow="$(echo "${artifact}" | jq -r '.flow')"                     # eg saver-ci
      service="${flow::-3}"                                            # eg saver
      filename="${ROOT_DIR}/bin/json/${service}.json"
      {
        echo '{'
        echo "  \"flow\": \"${flow}\","
        echo "  \"service\": \"${service}\","
        echo "  \"fingerprint\": \"${fingerprint}\","
        echo "  \"name\": \"${name}\""
        echo '}'
      } > "${filename}"
  done
}

write_matrix_include_file()
{
  matrix_include_filename="${ROOT_DIR}/bin/json/matrix-include.json"
  {
    separator=""
    echo -n '{"include": ['
    local -r artifacts_length=$(echo "${diff}" | jq -r '.snappish1.artifacts | length')
    for ((n=0; n < ${artifacts_length}; n++))
    do
        echo -n "${separator}"

        separator=","
        artifact="$(echo "${diff}" | jq -r ".snappish1.artifacts[$n]")"  # eg {...}
        name="$(echo "${artifact}" | jq -r '.name')"                     # eg 244531986313.dkr.ecr.eu-central-1.amazonaws.com/saver:6e191a0@sha256:b3237b0e615e7041c23433faeee0bacd6ec893e89ae8899536433e4d27a5b6ef
        fingerprint="$(echo "${artifact}" | jq -r '.fingerprint')"       # eg b3237b0e615e7041c23433faeee0bacd6ec893e89ae8899536433e4d27a5b6ef
        flow="$(echo "${artifact}" | jq -r '.flow')"                     # eg saver-ci
        service="${flow::-3}"                                            # eg saver

        echo -n '{'
        echo -n "  \"flow\": \"${flow}\","
        echo -n "  \"service\": \"${service}\","
        echo -n "  \"fingerprint\": \"${fingerprint}\","
        echo -n "  \"name\": \"${name}\""
        echo -n '}'
    done
    echo -n ']}'
  } > "${matrix_include_filename}"

  echo "matrix-include"
  cat "${matrix_include_filename}" | jq .
}

check_args "$@"
write_json_files "$@"
write_matrix_include_file "$@"
