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

#local Testing
#diff="$(cat "${ROOT_DIR}/docs/diff-snapshots-duplicate.json")"

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
  local -r service="${1}"
  if [ "${service}" == "differ" ] || [ "${service}" == "creator" ]; then
    return 0
  else
    return 1
  fi
}

create_matrix_include()
{
  # The Github Action workflow does this:
  #
  # job:
  #   if: ${{ needs.find-artifacts.outputs.matrix_include != '' }}
  #   strategy:
  #     matrix: ${{ fromJSON(needs.find-artifacts.outputs.matrix_include) }}
  #
  # The if: is necessary because the matrix: expression does not work if the json is {"include": []}
  # So if there are no Artifacts, create an empty file.

  local -r artifacts_length=$(echo "${diff}" | jq -r '.snappish1.artifacts | length')
  if [ "${artifacts_length}" == "0" ]; then
    echo -n '' > "${MATRIX_INCLUDE_FILENAME}"
  else
    {
      separator=""
      echo -n '{"include": ['
      for ((n = 0; n < artifacts_length; n++))
      do
          artifact="$(echo "${diff}" | jq -r ".snappish1.artifacts[$n]")"  # eg {...}
          commit_url="$(echo "${artifact}" | jq -r '.commit_url')"         # eg https://github.com/cyber-dojo/saver/commit/6e191a0a86cf3d264955c4910bc3b9df518c4bcd

          name="$(echo "${artifact}" | jq -r '.name')"                     # eg 244531986313.dkr.ecr.eu-central-1.amazonaws.com/saver:6e191a0@sha256:b3237b0e615e7041c23433faeee0bacd6ec893e89ae8899536433e4d27a5b6ef
          fingerprint="$(echo "${artifact}" | jq -r '.fingerprint')"       # eg b3237b0e615e7041c23433faeee0bacd6ec893e89ae8899536433e4d27a5b6ef
          flow="$(echo "${artifact}" | jq -r '.flow')"                     # eg saver-ci
          service="${flow::-3}"                                            # eg saver
          commit_sha="${commit_url:(-40)}"                                 # eg 6e191a0a86cf3d264955c4910bc3b9df518c4bcd
          repo_url="${commit_url:0:(-47)}"                                 # eg https://github.com/cyber-dojo/saver

          if ! excluded "${service}" ; then
            echo -n "${separator}"
            separator=","
            echo -n '{'
            echo -n "  \"flow\": \"${flow}\","
            echo -n "  \"service\": \"${service}\","
            echo -n "  \"fingerprint\": \"${fingerprint}\","
            echo -n "  \"repo_url\": \"${repo_url}\","
            echo -n "  \"commit_sha\": \"${commit_sha}\","
            echo -n "  \"name\": \"${name}\""
            echo -n '}'
          fi
      done
      echo -n ']}'
    } > "${MATRIX_INCLUDE_FILENAME}"
  fi

  jq . "${MATRIX_INCLUDE_FILENAME}"
}

exit_non_zero_if_duplicate()
{
  local -r raw="$(cat "${MATRIX_INCLUDE_FILENAME}" | jq -r '.. | .service? | select(length > 0)' | sort)"
  local -r cooked="$(echo "${raw}" | uniq)"
  if [ "${raw}" != "${cooked}" ]; then
    stderr Duplicate service names in:
    stderr "  $(echo "${raw}" | tr '\n' ' ')"
    stderr This indicates a blue-green deployment is in progress
    exit 42
  fi
}


check_args "$@"
create_matrix_include "$@"
exit_non_zero_if_duplicate
