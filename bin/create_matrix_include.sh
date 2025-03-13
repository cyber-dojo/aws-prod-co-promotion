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

#diff="$(kosli diff snapshots "${KOSLI_AWS_BETA}" "${KOSLI_AWS_PROD}" \
#    --host="${KOSLI_HOST}" \
#    --org="${KOSLI_ORG}" \
#    --api-token="${KOSLI_API_TOKEN}" \
#    --debug=false \
#    --output=json)"

#TODO: How to add and automate some tests. Use pre-canned files in docs/
diff="$(cat "${ROOT_DIR}/docs/diff-snapshots-4.json")"
#diff="$(cat "${ROOT_DIR}/docs/diff-snapshots-mid-blue-green.json")"
#diff="$(cat "${ROOT_DIR}/docs/diff-snapshots-new-flow.json")"

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
  #   "snappish1" for Artifacts in KOSLI_AWS_BETA but not KOSLI_AWS_PROD, these will be deployed
  #   "snappish2" for Artifacts in KOSLI_AWS_PROD but not KOSLI_AWS_BETA, these will be un-deployed

  local -r incoming_artifacts=$(echo "${diff}" | jq -r -c '.snappish1.artifacts')
  local -r outgoing_artifacts=$(echo "${diff}" | jq -r -c '.snappish2.artifacts')
  local -r incoming_length=$(echo "${incoming_artifacts}" | jq -r '. | length')
  separator=""
  {
    echo -n '['
    for ((n = 0; n < incoming_length; n++))
    do
      artifact="$(echo "${incoming_artifacts}" | jq -r -c ".[$n]")"  # eg {...}
      flow="$(echo "${artifact}" | jq -r '.flow')"      # eg saver-ci
      if ! excluded "${flow}" ; then
        echo "${separator}"
        echo "  {"
        echo_json_entry    "incoming" "${artifact}" ","
        echo_json_outgoing "${flow}" "${outgoing_artifacts}"
        echo "  }"
        separator=","
      fi
    done
    echo
    echo ']'
  } > "${MATRIX_INCLUDE_FILENAME}"

  jq . "${MATRIX_INCLUDE_FILENAME}"
}

echo_json_outgoing()
{
  local -r incoming_flow="${1}"
  local -r outgoing_artifacts="${2}"
  local -r outgoing_length=$(echo "${outgoing_artifacts}" | jq -r '. | length')

  for ((n = 0; n < outgoing_length; n++))
  do
    artifact="$(echo "${outgoing_artifacts}" | jq -r ".[$n]")"       # eg {...}
    outgoing_flow="$(echo "${artifact}" | jq -r '.flow')"  # eg saver-ci
    if [ "${outgoing_flow}" == "${incoming_flow}" ]; then
      separator=""
      echo_json_entry "outgoing" "${artifact}" "${separator}"
      return 0
    fi
  done

  local -r kind="outgoing"

# TODO: Create NO_IMAGE here-string
#  cat << EOF
#      "${kind}_image_name": "",
#      "${kind}_fingerprint": "",
#      "${kind}_repo_url": "",
#      "${kind}_repo_name": "",
#      "${kind}_commit_sha": "",
#      "${kind}_flow": ""
#EOF

  local -r no_image="$(jq -r -c . <<< NO_IMAGE)"
  local -r separator=""
  echo_json_entry "${kind}" "${no_image}" "${separator}"
}

echo_json_entry()
{
  local -r kind="${1}"                                        # incoming | outgoing
  local -r artifact="${2}"                                    # {...}
  local -r separator="${3}"                                   # "," or ""

  image_name="$(echo "${artifact}" | jq -r '.name')"          # 244531986313.dkr.ecr.eu-central-1.amazonaws.com/saver:6e191a0@sha256:b3237b0e615e7041c23433faeee0bacd6ec893e89ae8899536433e4d27a5b6ef
  fingerprint="$(echo "${artifact}" | jq -r '.fingerprint')"  # b3237b0e615e7041c23433faeee0bacd6ec893e89ae8899536433e4d27a5b6ef
  flow="$(echo "${artifact}" | jq -r '.flow')"                # saver-ci
  commit_url="$(echo "${artifact}" | jq -r '.commit_url')"    # https://github.com/cyber-dojo/saver/commit/6e191a0a86cf3d264955c4910bc3b9df518c4bcd
  commit_sha="${commit_url:(-40)}"                            # 6e191a0a86cf3d264955c4910bc3b9df518c4bcd
  repo_url="${commit_url:0:(-48)}"                            # https://github.com/cyber-dojo/saver  40+/+commit+/
  repo_name="${repo_url##*/}"                                 # saver

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
