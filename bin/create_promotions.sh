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

      $ cat docs/diff-snapshots-2.json | ${MY_NAME}
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
              "outgoing_flow": "nginx-ci",
              "deployment_diff_url": "https://github.com/cyber-dojo/nginx/compare/fa32058a046015786d1589e16af7da0973f2e726...e92d83d1bf0b1de46205d5e19131f1cee2b6b3da"
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
  local -r artifacts="$(jq --raw-output '.artifacts' <<< "${snappish}")"
  local -r duplicate_flows="$(jq --raw-output '.. | .flow? | select(length > 0)' <<< "${artifacts}" | sort | uniq --repeated)"
  if [ "${duplicate_flows}" != "" ]; then
    local -r env_id="$(jq --raw-output '.snapshot_id' <<< "${snappish}")"
    stderr "Promotion abandoned because a blue-green deployment is in progress in ${env_id}"
    stderr "${duplicate_flows}"
    exit 42
  fi
}

echo_inflated_artifacts()
{
  local -r kind="${1}"      # incoming | outgoing
  local -r snappish="${2}"
  local -r artifacts=$(jq --raw-output '.artifacts' <<< "${snappish}")
  local -r length=$(jq --raw-output '. | length' <<< "${artifacts}")

  separator=""
  echo '['
  local n; for ((n = 0; n < length; n++))
  do
    artifact="$(jq --raw-output ".[$n]" <<< "${artifacts}")"  # {"flow": "saver",...}
    flow="$(jq --raw-output '.flow' <<< "${artifact}")"       # saver
    if ! excluded "${flow}" ; then
      echo "${separator}"
      echo '{'
      echo_inflated_artifact "${kind}" "${artifact}"
      echo '}'
      separator=","
    fi
  done
  echo
  echo ']'
}

echo_inflated_artifact()
{
  local -r kind="${1}"      # incoming | outgoing
  local -r artifact="${2}"  # {...}

  image_name="$( jq --raw-output '.name'        <<< "${artifact}")"  # 244531986313.dkr.ecr.eu-central-1.amazonaws.com/saver:6e191a0@sha256:b3237b0e615e7041c23433faeee0bacd6ec893e89ae8899536433e4d27a5b6ef
  fingerprint="$(jq --raw-output '.fingerprint' <<< "${artifact}")"  # b3237b0e615e7041c23433faeee0bacd6ec893e89ae8899536433e4d27a5b6ef
  flow="$(       jq --raw-output '.flow'        <<< "${artifact}")"  # saver-ci
  commit_url="$( jq --raw-output '.commit_url'  <<< "${artifact}")"  # https://github.com/cyber-dojo/saver/commit/6e191a0a86cf3d264955c4910bc3b9df518c4bcd
  commit_sha="${commit_url:(-40)}"                                   # 6e191a0a86cf3d264955c4910bc3b9df518c4bcd
  repo_url="${commit_url:0:(-48)}"                                   # https://github.com/cyber-dojo/saver  40+/+commit+/
  repo_name="${repo_url##*/}"                                        # saver

  cat << EOF
    "${kind}_image_name": "${image_name}",
    "${kind}_fingerprint": "${fingerprint}",
    "${kind}_repo_url": "${repo_url}",
    "${kind}_repo_name": "${repo_name}",
    "${kind}_commit_sha": "${commit_sha}",
    "${kind}_flow": "${flow}"
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

echo_deployment_diff_urls()
{
  # Creates [{"deployment_diff_url":"...},{"deployment_diff_url":"...},...]
  # Relies on incoming_artifacts and outgoing_artifacts having the same Flow ordering.

  local -r incoming_artifacts="${1}"
  local -r outgoing_artifacts="${2}"
  local -r length=$(jq --raw-output '. | length' <<< "${incoming_artifacts}")

  separator=""
  echo '['
  local n; for ((n = 0; n < length; n++))
  do
    incoming_artifact="$(jq --raw-output ".[$n]" <<< "${incoming_artifacts}")"  # eg {...}
    outgoing_artifact="$(jq --raw-output ".[$n]" <<< "${outgoing_artifacts}")"  # eg {...}

    incoming_repo_url="$(jq --raw-output '.incoming_repo_url' <<< "${incoming_artifact}")"    # https://github.com/cyber-dojo/nginx
    outgoing_repo_url="$(jq --raw-output '.outgoing_repo_url' <<< "${outgoing_artifact}")"    # https://github.com/cyber-dojo/nginx
    if [ "${incoming_repo_url}" != "${outgoing_repo_url}" ]; then
      : # TODO: repo_url entries don't match
    fi

    incoming_commit_sha="$(jq --raw-output '.incoming_commit_sha' <<< "${incoming_artifact}")"    # 6e191a0a86cf3d264955c4910bc3b9df518c4bcd
    outgoing_commit_sha="$(jq --raw-output '.outgoing_commit_sha' <<< "${outgoing_artifact}")"    # 7e191a0a86cf3d264955c4910bc3b9df518c4bcd

    echo "${separator}"
    echo '{'
    # TODO: check if this is the first Deployment (outgoing_commit_sha == "") and if so echo the incoming_commit_url
    # TODO: This deployment_diff_url it specific to https://github.com
    cat << EOF
      "deployment_diff_url": "${incoming_repo_url}/compare/${incoming_commit_sha}...${outgoing_commit_sha}"
EOF
    echo '}'
    separator=","
  done
  echo ']'
}

echo_same_flow_ordering()
{
  # Echoes outgoing_artifacts reordered so its Flow entries match incoming_artifacts.
  # This enables both JSON arrays to be spliced together using jq 'transpose | map(add)'

  local -r outgoing_artifacts="${1}"
  local -r incoming_artifacts="${2}"
  local -r length="$(jq --raw-output '. | length' <<< "${incoming_artifacts}")"

  separator=""
  echo '['
  local n; for ((n = 0; n < length; n++))
  do
    incoming_artifact="$(jq --raw-output ".[$n]" <<< "${incoming_artifacts}")"       # {...}
    incoming_flow="$(jq --raw-output '.incoming_flow' <<< "${incoming_artifact}")"   # saver-ci
    echo "${separator}"
    echo '{'
    echo_json_outgoing "${incoming_flow}" "${outgoing_artifacts}"
    echo '}'
    separator=","
  done
  echo ']'
}

echo_json_outgoing()
{
  # Echoes the entry in outgoing_artifacts whose Flow matches incoming_flow.
  # Echoes an empty entry if this is the first deployment for the incoming_flow.

  local -r incoming_flow="${1}"
  local -r outgoing_artifacts="${2}"
  local -r outgoing_length=$(jq --raw-output '. | length' <<< "${outgoing_artifacts}")

  local n; for ((n = 0; n < outgoing_length; n++))
  do
    outgoing_artifact="$(jq --raw-output ".[$n]" <<< "${outgoing_artifacts}")"      # {...}
    outgoing_flow="$(jq --raw-output '.outgoing_flow' <<< "${outgoing_artifact}")"  # eg saver-ci
    if [ "${outgoing_flow}" == "${incoming_flow}" ]; then
      cat << EOF
        "outgoing_image_name" : "$(jq --raw-output '.outgoing_image_name'  <<< "${outgoing_artifact}")",
        "outgoing_fingerprint": "$(jq --raw-output '.outgoing_fingerprint' <<< "${outgoing_artifact}")",
        "outgoing_repo_url"   : "$(jq --raw-output '.outgoing_repo_url'    <<< "${outgoing_artifact}")",
        "outgoing_repo_name"  : "$(jq --raw-output '.outgoing_repo_name'   <<< "${outgoing_artifact}")",
        "outgoing_commit_sha" : "$(jq --raw-output '.outgoing_commit_sha'  <<< "${outgoing_artifact}")",
        "outgoing_flow"       : "$(jq --raw-output '.outgoing_flow'        <<< "${outgoing_artifact}")"
EOF
      return 0
    fi
  done

  # There is no matching outgoing Artifact. This is the first deployment.
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

# - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# diff is the result of the Kosli CLI command:
#   kosli diff snapshots "${KOSLI_AWS_BETA}" "${KOSLI_AWS_PROD}" ...  --output=json
# which returns JSON with keys
#   "snappish1" for Artifacts in KOSLI_AWS_BETA but not KOSLI_AWS_PROD; these will be deployed
#   "snappish2" for Artifacts in KOSLI_AWS_PROD but not KOSLI_AWS_BETA; these will be un-deployed

check_args "$@"
exit_non_zero_unless_installed jq

diff="$(jq --raw-output --compact-output .)"
incoming="$(jq --raw-output --compact-output '.snappish1' <<< "${diff}")"
outgoing="$(jq --raw-output --compact-output '.snappish2' <<< "${diff}")"

exit_non_zero_if_mid_blue_green_deployment "${incoming}"
exit_non_zero_if_mid_blue_green_deployment "${outgoing}"

incoming_artifacts="$(echo_inflated_artifacts incoming "${incoming}")"
outgoing_artifacts="$(echo_inflated_artifacts outgoing "${outgoing}")"
outgoing_artifacts="$(echo_same_flow_ordering "${outgoing_artifacts}" "${incoming_artifacts}")"

deployment_diff_urls="$(echo_deployment_diff_urls "${incoming_artifacts}" "${outgoing_artifacts}")"

jq --slurp 'transpose | map(add)' <<< "${incoming_artifacts}${outgoing_artifacts}${deployment_diff_urls}"


