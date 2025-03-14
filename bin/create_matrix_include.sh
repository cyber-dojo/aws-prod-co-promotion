#!/usr/bin/env bash
set -Eeu

export ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/bin/lib.sh"

show_help()
{
    local -r MY_NAME=$(basename "${BASH_SOURCE[0]}")
    cat <<- EOF

    Use: ${MY_NAME}

    Reads the result of a 'kosli diff snapshots --output-type=json' from stdin.
    Writes a JSON array with one dict for each Artifact to be promoted, to stdout.
    This JSON can be used in a Github Action matrix to run a parallel job for each Artifact.
    If a blue-green deployment is in progress for any of the Artifacts the script will exit with a non-zero value.
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
          {
              "incoming_image_name": "244531986313.dkr.ecr.eu-central-1.amazonaws.com/web:ed1878b@sha256:337fa91d02fa59729aca2941bbfebf999d1c5ae74b1492a4c99a33a925c7f052",
              "incoming_fingerprint": "337fa91d02fa59729aca2941bbfebf999d1c5ae74b1492a4c99a33a925c7f052",
              "incoming_repo_url": "https://github.com/cyber-dojo/web/",
              "incoming_repo_name": "web",
              "incoming_commit_sha": "ed1878bd4aba3cada1e6ae7bc510f6354c61c484",
              "incoming_flow": "web-ci",
              "outgoing_image_name": "244531986313.dkr.ecr.eu-central-1.amazonaws.com/web:5db3d66@sha256:49cfb0d0696a9934e408ff20eaeea17ba87924ea520963be2021134814a086cc",
              "outgoing_fingerprint": "49cfb0d0696a9934e408ff20eaeea17ba87924ea520963be2021134814a086cc",
              "outgoing_repo_url": "https://github.com/cyber-dojo/web",
              "outgoing_repo_name": "web",
              "outgoing_commit_sha": "5db3d66084de99c0b9b3847680de78ea01f63643",
              "outgoing_flow": "web-ci"
          }
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
  # diff is the result of the Kosli CLI command:
  #   kosli diff snapshots "${KOSLI_AWS_BETA}" "${KOSLI_AWS_PROD}" ...  --output=json
  # which returns JSON with keys
  #   "snappish1" for Artifacts in KOSLI_AWS_BETA but not KOSLI_AWS_PROD; these will be deployed
  #   "snappish2" for Artifacts in KOSLI_AWS_PROD but not KOSLI_AWS_BETA; these will be un-deployed
  local -r diff="${1}"
  local -r incoming_artifacts=$(echo "${diff}" | jq -r -c '.snappish1.artifacts')
  local -r outgoing_artifacts=$(echo "${diff}" | jq -r -c '.snappish2.artifacts')
  local -r incoming_length=$(echo "${incoming_artifacts}" | jq -r '. | length')
  separator=""
  {
    echo '['
    for ((n = 0; n < incoming_length; n++))
    do
      artifact="$(echo "${incoming_artifacts}" | jq -r -c ".[$n]")"  # eg {...}
      flow="$(echo "${artifact}" | jq -r '.flow')"                   # eg saver-ci
      if ! excluded "${flow}" ; then
        echo "${separator}"
        echo '{'
        echo_json_entry    "incoming" "${artifact}" ","
        echo_json_outgoing "${flow}" "${outgoing_artifacts}"
        echo '}'
        separator=","
      fi
    done
    echo
    echo ']'
  }
}

echo_json_outgoing()
{
  local -r incoming_flow="${1}"
  local -r outgoing_artifacts="${2}"
  local -r outgoing_length=$(echo "${outgoing_artifacts}" | jq -r '. | length')

  for ((n = 0; n < outgoing_length; n++))
  do
    artifact="$(echo "${outgoing_artifacts}" | jq -r ".[$n]")"  # eg {...}
    outgoing_flow="$(echo "${artifact}" | jq -r '.flow')"       # eg saver-ci
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
  local -r raw="$(jq -r '.. | .incoming_flow? | select(length > 0)' <<< "${1}" | sort)"
  local -r cooked="$(echo "${raw}" | uniq)"
  if [ "${raw}" != "${cooked}" ]; then
    stderr Duplicate flow names in:
    stderr "  $(echo "${raw}" | tr '\n' ' ')"
    stderr This indicates a blue-green deployment is in progress
    exit 42
  fi
}

check_args "$@"
exit_non_zero_unless_installed kosli jq
diff="$(jq --raw-output --compact-output .)"
matrix_include="$(create_matrix_include "${diff}")"
exit_non_zero_if_mid_blue_green_deployment "${matrix_include}"
echo "${matrix_include}"
