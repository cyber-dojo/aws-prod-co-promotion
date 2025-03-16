#!/usr/bin/env bash
set -Eeu

export ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/bin/lib.sh"

show_help()
{
    local -r MY_NAME=$(basename "${BASH_SOURCE[0]}")
    cat <<- EOF

    Use: ${MY_NAME}

    Reads (from stdin) the result of a 'kosli diff snapshots aws-beta aws-prod --org=cyber-dojo ... --output-type=json'.
    Writes (to stdout) a JSON array with one dict for each Artifact to be promoted.
    This JSON can be used in a Github Action matrix to run a parallel job for each Artifact.
    If a blue-green deployment is in progress in aws-beta or aws-prod, the script will exit with a non-zero value.
    Example:

      $ cat docs/diff-snapshots-2.json | ${MY_NAME} | jq .
      [
          {
              "incoming_image_name": "244531986313.dkr.ecr.eu-central-1.amazonaws.com/nginx:fa32058@sha256:0fd1eae4a2ab75d4d08106f86af3945a9e95b60693a4b9e4e44b59cc5887fdd1",
              "incoming_fingerprint": "0fd1eae4a2ab75d4d08106f86af3945a9e95b60693a4b9e4e44b59cc5887fdd1",
              "incoming_repo_url": "https://github.com/cyber-dojo/nginx/",
              "incoming_repo_name": "nginx",
              "incoming_commit_sha": "fa32058a046015786d1589e16af7da0973f2e726",
              "incoming_flow": "nginx-ci",
              "outgoing_image_name": "244531986313.dkr.ecr.eu-central-1.amazonaws.com/nginx:e92d83d@sha256:0f803b05be83006c77e8c371b1f999eaabfb2feca9abef64332633362b36ca94",
              "outgoing_fingerprint": "0f803b05be83006c77e8c371b1f999eaabfb2feca9abef64332633362b36ca94",
              "outgoing_repo_url": "https://github.com/cyber-dojo/nginx",
              "outgoing_repo_name": "nginx",
              "outgoing_commit_sha": "e92d83d1bf0b1de46205d5e19131f1cee2b6b3da",
              "outgoing_flow": "nginx-ci"
          },
          ...
      ]

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

exit_non_zero_if_mid_blue_green_deployment()
{
  local -r snappish="${1}"   # {"snapshot_id":"...", "artifacts":[{"flow":"x",...},{"flow": "y",...},...]}
  local -r artifacts="$(jq -r '.artifacts' <<< "${snappish}")"
  local -r duplicate_flows="$(jq -r '.. | .flow? | select(length > 0)' <<< "${artifacts}" | sort | uniq --repeated)"
  if [ "${duplicate_flows}" != "" ]; then
    local -r env_id="$(jq -r '.snapshot_id' <<< "${snappish}")"
    stderr "Duplicate flow names in ${env_id}"
    stderr "${duplicate_flows}"
    stderr This indicates a blue-green deployment is in progress
    exit 42
  fi
}

echo_inflated_artifacts()
{
  local -r snappish="${1}"
  local -r artifacts=$(jq -r -c '.artifacts' <<< "${snappish}")
  local -r length=$(jq -r '. | length' <<< "${artifacts}")

  separator=""
  echo '['
  local n; for ((n = 0; n < length; n++))
  do
    artifact="$(jq -r -c ".[$n]" <<< "${artifacts}")"  # eg {...}
    echo "${separator}"
    echo '{'
    echo_inflated_artifact "${artifact}"
    echo '}'
    separator=","
  done
  echo
  echo ']'
}

echo_inflated_artifact()
{
  local -r artifact="${1}"

  image_name="$(jq -r '.name' <<< "${artifact}")"          # 244531986313.dkr.ecr.eu-central-1.amazonaws.com/saver:6e191a0@sha256:b3237b0e615e7041c23433faeee0bacd6ec893e89ae8899536433e4d27a5b6ef
  fingerprint="$(jq -r '.fingerprint' <<< "${artifact}")"  # b3237b0e615e7041c23433faeee0bacd6ec893e89ae8899536433e4d27a5b6ef
  flow="$(jq -r '.flow' <<< "${artifact}")"                # saver-ci
  commit_url="$(jq -r '.commit_url' <<< "${artifact}")"    # https://github.com/cyber-dojo/saver/commit/6e191a0a86cf3d264955c4910bc3b9df518c4bcd
  commit_sha="${commit_url:(-40)}"                         # 6e191a0a86cf3d264955c4910bc3b9df518c4bcd
  repo_url="${commit_url:0:(-48)}"                         # https://github.com/cyber-dojo/saver  40+/+commit+/
  repo_name="${repo_url##*/}"                              # saver

  cat << EOF
    "image_name": "${image_name}",
    "fingerprint": "${fingerprint}",
    "repo_url": "${repo_url}",
    "repo_name": "${repo_name}",
    "commit_sha": "${commit_sha}",
    "flow": "${flow}"
EOF
}

excluded()
{
  # Currently, differ still has TF attestations
  # Currently, creator is in Gitlab, not Github

  local -r flow="${1}"
  if [ "${flow}" == "differ-ci" ] || [ "${flow}" == "creator-ci" ]; then
    return 0
  else
    return 1
  fi
}

echo_promotions()
{
  local -r incoming_artifacts="${1}"
  local -r outgoing_artifacts="${2}"
  local -r incoming_length=$(jq -r '. | length' <<< "${incoming_artifacts}")

  separator=""
  echo '['
  local n; for ((n = 0; n < incoming_length; n++))
  do
    incoming_artifact="$(jq -r -c ".[$n]" <<< "${incoming_artifacts}")"  # eg {...}
    incoming_flow="$(jq -r '.flow' <<< "${incoming_artifact}")"          # eg saver-ci
    if ! excluded "${incoming_flow}" ; then
      echo "${separator}"
      echo '{'
      echo_json_entry    "incoming" "${incoming_artifact}" ","
      echo_json_outgoing "${incoming_flow}" "${outgoing_artifacts}"
      echo '}'
      separator=","
    fi
  done
  echo
  echo ']'
}

echo_json_outgoing()
{
  local -r incoming_flow="${1}"
  local -r outgoing_artifacts="${2}"
  local -r outgoing_length=$(jq -r '. | length' <<< "${outgoing_artifacts}")

  local n; for ((n = 0; n < outgoing_length; n++))
  do
    artifact="$(jq -r ".[$n]" <<< "${outgoing_artifacts}")"  # eg {...}
    outgoing_flow="$(jq -r '.flow' <<< "${artifact}")"       # eg saver-ci
    if [ "${outgoing_flow}" == "${incoming_flow}" ]; then
      separator=""
      echo_json_entry "outgoing" "${artifact}" "${separator}"
      return 0
    fi
  done

  local -r kind="outgoing"
  cat << EOF
    "${kind}_image_name": "",
    "${kind}_fingerprint": "",
    "${kind}_repo_url": "",
    "${kind}_repo_name": "",
    "${kind}_commit_sha": "",
    "${kind}_flow": ""
EOF
}

echo_json_entry()
{
  local -r kind="${1}"                                     # incoming | outgoing
  local -r artifact="${2}"                                 # {...}
  local -r separator="${3}"                                # "," or ""

  #  image_name    244531986313.dkr.ecr.eu-central-1.amazonaws.com/saver:6e191a0@sha256:b3237b0e615e7041c23433faeee0bacd6ec893e89ae8899536433e4d27a5b6ef
  #  fingerprint   b3237b0e615e7041c23433faeee0bacd6ec893e89ae8899536433e4d27a5b6ef
  #  flow          saver-ci
  #  commit_url    https://github.com/cyber-dojo/saver/commit/6e191a0a86cf3d264955c4910bc3b9df518c4bcd
  #  commit_sha    6e191a0a86cf3d264955c4910bc3b9df518c4bcd
  #  repo_url      https://github.com/cyber-dojo/saver  40+/+commit+/
  #  repo_name     saver

  cat << EOF
    "${kind}_image_name" : "$(jq -r '.image_name'  <<< "${artifact}")",
    "${kind}_fingerprint": "$(jq -r '.fingerprint' <<< "${artifact}")",
    "${kind}_repo_url"   : "$(jq -r '.repo_url'    <<< "${artifact}")",
    "${kind}_repo_name"  : "$(jq -r '.repo_name'   <<< "${artifact}")",
    "${kind}_commit_sha" : "$(jq -r '.commit_sha'  <<< "${artifact}")",
    "${kind}_flow"       : "$(jq -r '.flow'        <<< "${artifact}")"${separator}
EOF
}

echo_deployment_diff_urls()
{
  # Creates [{"deployment_diff_url":"...},{"deployment_diff_url":"...},...]
  local -r incoming_artifacts="${1}"
  local -r outgoing_artifacts="${2}"
  local -r length=$(jq -r '. | length' <<< "${incoming_artifacts}")

  separator=""
  echo '['
  local n; for ((n = 0; n < length; n++))
  do
    incoming_artifact="$(jq -r ".[$n]" <<< "${incoming_artifacts}")"  # eg {...}
    outgoing_artifact="$(jq -r ".[$n]" <<< "${outgoing_artifacts}")"  # eg {...}

    incoming_commit_sha="$(jq -r '.commit_sha' <<< "${incoming_artifact}")"    # https://github.com/cyber-dojo/saver/commit/6e191a0a86cf3d264955c4910bc3b9df518c4bcd
    outgoing_commit_sha="$(jq -r '.commit_sha' <<< "${outgoing_artifact}")"    # https://github.com/cyber-dojo/saver/commit/7e191a0a86cf3d264955c4910bc3b9df518c4bcd

    echo "${separator}"
    echo '{'
    cat << EOF
      "deployment_diff_url": "https://.../${incoming_commit_sha}...${outgoing_commit_sha}"
EOF
    echo '}'
    separator=","
  done
  echo ']'
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# diff is the result of the Kosli CLI command:
#   kosli diff snapshots "${KOSLI_AWS_BETA}" "${KOSLI_AWS_PROD}" ...  --output=json
# which returns JSON with keys
#   "snappish1" for Artifacts in KOSLI_AWS_BETA but not KOSLI_AWS_PROD; these will be deployed
#   "snappish2" for Artifacts in KOSLI_AWS_PROD but not KOSLI_AWS_BETA; these will be un-deployed

check_args "$@"
exit_non_zero_unless_installed jq

diff="$(jq --raw-output --compact-output .)"
incoming="$(jq -r -c '.snappish1' <<< "${diff}")"
outgoing="$(jq -r -c '.snappish2' <<< "${diff}")"

exit_non_zero_if_mid_blue_green_deployment "${incoming}"
exit_non_zero_if_mid_blue_green_deployment "${outgoing}"

incoming_artifacts="$(echo_inflated_artifacts "${incoming}")"
outgoing_artifacts="$(echo_inflated_artifacts "${outgoing}")"

promotions="$(echo_promotions "${incoming_artifacts}" "${outgoing_artifacts}")"
deployment_diff_urls="$(echo_deployment_diff_urls "${incoming_artifacts}" "${outgoing_artifacts}")"

jq --slurp 'transpose | map(add)' <<< "${promotions}${deployment_diff_urls}"


