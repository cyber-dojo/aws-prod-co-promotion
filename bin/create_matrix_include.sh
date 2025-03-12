#!/usr/bin/env bash
set -Eeu

export ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/bin/lib.sh"
exit_non_zero_unless_installed kosli jq

MATRIX_INCLUDE_FILENAME="${ROOT_DIR}/json/matrix-include.json"

KOSLI_HOST="${KOSLI_HOST:-https://app.kosli.com}"
KOSLI_ORG="${KOSLI_ORG:-cyber-dojo}"
KOSLI_API_TOKEN="${KOSLI_API_TOKEN:-read-only-dummy}"
KOSLI_AWS_BETA="${KOSLI_AWS_BETA:-aws-beta}"
KOSLI_AWS_PROD="${KOSLI_AWS_PROD:-aws-prod}"

# NOTE: in a Github Action, stdout and stderr are multiplexed together.
# This means that the output of the $(subshell) is not just stdout, it is stdout+stderr!
# To ensure the Kosli CLI does not print to stderr, we set the --debug=false flag explicitly.

diff="$(kosli diff snapshots "${KOSLI_AWS_BETA}" "${KOSLI_AWS_PROD}" \
    --host="${KOSLI_HOST}" \
    --org="${KOSLI_ORG}" \
    --api-token="${KOSLI_API_TOKEN}" \
    --debug=false \
    --output=json)"

#TODO: How to add and automate some tests. Use pre-canned files in docs/
#diff="$(cat "${ROOT_DIR}/docs/diff-snapshots-4.json")"
#diff="$(cat "${ROOT_DIR}/docs/diff-snapshots-mid-blue-green.json")"

show_help()
{
    local -r MY_NAME=$(basename "${BASH_SOURCE[0]}")
    cat <<- EOF

    Use: ${MY_NAME}

    Creates the file 'matrix-include.json' ready to be used in a
    Github Action matrix to run a parallel job for each Artifact.
    If a blue-green deployment is in progress for any of the Artifacts
    the script will exit with a non-zero value.

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

excluded()
{
  # Differ still has TF attestations
  # Creator is in Gitlab, not Github

  local -r flow="${1}"
  if [ "${flow}" == "differ-ci" ] || [ "${flow}" == "creator-ci" ]; then
    return 0
  else
    return 1
  fi
}

create_matrix_include()
{
  # The Kosli CLI command is
  #   kosli diff snapshots "${KOSLI_AWS_BETA}" "${KOSLI_AWS_PROD}" ...  --output=json
  # which returns JSON with keys
  #   "snappish1" for Artifacts in KOSLI_AWS_BETA but not KOSLI_AWS_PROD
  #   "snappish2" for Artifacts in KOSLI_AWS_PROD but not KOSLI_AWS_BETA

  local -r artifacts_length=$(echo "${diff}" | jq -r '.snappish1.artifacts | length')
  separator=""
  {
    echo -n '['
    for ((n = 0; n < artifacts_length; n++))
    do
      artifact="$(echo "${diff}" | jq -r ".snappish1.artifacts[$n]")"  # eg {...}
      flow="$(echo "${artifact}" | jq -r '.flow')"                     # eg saver-ci
      if ! excluded "${flow}" ; then
        echo "${separator}"
        echo "  {"
        echo_json_entries "," "incoming" "${artifact}"
        # TODO: outgoing
        # echo_json_entries "" "outgoing" "${artifact}"
        echo "  }"
        separator=","
      fi
    done
    echo
    echo ']'
  } > "${MATRIX_INCLUDE_FILENAME}"

  jq . "${MATRIX_INCLUDE_FILENAME}"
}

echo_json_entries()
{
  local -r separator="${1}"
  local -r kind="${2}"                                             # incoming | outgoing
  local -r artifact="${3}"                                         # {...}
  commit_url="$(echo "${artifact}" | jq -r '.commit_url')"         # eg https://github.com/cyber-dojo/saver/commit/6e191a0a86cf3d264955c4910bc3b9df518c4bcd
  image_name="$(echo "${artifact}" | jq -r '.name')"               # eg 244531986313.dkr.ecr.eu-central-1.amazonaws.com/saver:6e191a0@sha256:b3237b0e615e7041c23433faeee0bacd6ec893e89ae8899536433e4d27a5b6ef
  fingerprint="$(echo "${artifact}" | jq -r '.fingerprint')"       # eg b3237b0e615e7041c23433faeee0bacd6ec893e89ae8899536433e4d27a5b6ef
  flow="$(echo "${artifact}" | jq -r '.flow')"                     # eg saver-ci
  commit_sha="${commit_url:(-40)}"                                 # eg 6e191a0a86cf3d264955c4910bc3b9df518c4bcd
  repo_url="${commit_url:0:(-48)}"                                 # eg https://github.com/cyber-dojo/saver
  repo_name="${repo_url##*/}"                                      # eg saver

  cat << EOF
      "${kind}_image_name": "${image_name}",
      "${kind}_fingerprint": "${fingerprint}",
      "${kind}_repo_url": "${repo_url}",
      "${kind}_repo_name": "${repo_name}",
      "${kind}_commit_sha": "${commit_sha}",
      "${kind}_flow": "${flow}"${separator}
EOF
}

exit_non_zero_if_mid_blue_green_deployment()
{
  local -r raw="$(jq -r '.. | .incoming_flow? | select(length > 0)' "${MATRIX_INCLUDE_FILENAME}" | sort)"
  local -r cooked="$(echo "${raw}" | uniq)"
  if [ "${raw}" != "${cooked}" ]; then
    stderr Duplicate flow names in:
    stderr "  $(echo "${raw}" | tr '\n' ' ')"
    stderr This indicates a blue-green deployment is in progress
    exit 42
  fi
}

check_args "$@"
create_matrix_include "$@"
exit_non_zero_if_mid_blue_green_deployment
