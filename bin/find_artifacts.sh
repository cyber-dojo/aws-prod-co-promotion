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

# NOTE: in a Github Action, stdout and stderr appear to redirect to the same tty.
# This means that the output of the $(subshell) is not just stdout, it is stdout+stderr.
# To be sure we are not printing to stderr, we set the --debug=false flag explicitly.

diff="$(kosli diff snapshots "${KOSLI_AWS_BETA}" "${KOSLI_AWS_PROD}" \
    --host="${KOSLI_HOST}" \
    --org="${KOSLI_ORG}" \
    --api-token="${KOSLI_API_TOKEN}" \
    --debug=false \
    --output=json)"

#diff="$(cat "${ROOT_DIR}/docs/diff-snapshots-4.json")"

show_help()
{
    local -r MY_NAME=$(basename "${BASH_SOURCE[0]}")
    cat <<- EOF

    Use: ${MY_NAME}

    Uses the Kosli CLI to find which Artifacts are running in cyber-dojo's
    https://beta.cyber-dojo.org AWS staging environment that are NOT also
    running in cyber-dojo's https://cyber-dojo.org AWS prod environment.
    Creates a json file in the json/ directory for each Artifact. Eg

    {
             "flow": "saver-ci",
          "service": "saver",
      "fingerprint": "8bf657f7f47a4c32b2ffb0c650be2ced4de18e646309a4dfe11db22dfe2ea5eb",
         "repo_url": "https://github.com/cyber-dojo/saver/",
       "commit_sha": "c3b308d153f3594afea873d0c55b86dae929a9c5",
             "name": "244531986313.dkr.ecr.eu-central-1.amazonaws.com/saver:c3b308d@sha256:8bf657f7f47a4c32b2ffb0c650be2ced4de18e646309a4dfe11db22dfe2ea5eb"
    }

    Also creates the file 'matrix-include.json' ready to be used in a
    Github Action matrix to run a parallel job for each Artifact.

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

write_json_files()
{
  local -r artifacts_length=$(echo "${diff}" | jq -r '.snappish1.artifacts | length')
  for ((n=0; n < ${artifacts_length}; n++))
  do
      artifact="$(echo "${diff}" | jq -r ".snappish1.artifacts[$n]")"  # eg {...}
      commit_url="$(echo "${artifact}" | jq -r '.commit_url')"         # eg https://github.com/cyber-dojo/saver/commit/6e191a0a86cf3d264955c4910bc3b9df518c4bcd

      name="$(echo "${artifact}" | jq -r '.name')"                     # eg 244531986313.dkr.ecr.eu-central-1.amazonaws.com/saver:6e191a0@sha256:b3237b0e615e7041c23433faeee0bacd6ec893e89ae8899536433e4d27a5b6ef
      fingerprint="$(echo "${artifact}" | jq -r '.fingerprint')"       # eg b3237b0e615e7041c23433faeee0bacd6ec893e89ae8899536433e4d27a5b6ef
      flow="$(echo "${artifact}" | jq -r '.flow')"                     # eg saver-ci
      service="${flow::-3}"                                            # eg saver
      commit_sha="${commit_url:(-40)}"                                 # eg 6e191a0a86cf3d264955c4910bc3b9df518c4bcd
      repo_url="${commit_url:0:(-47)}"                                 # eg https://github.com/cyber-dojo/saver

      filename="${ROOT_DIR}/json/${service}.json"

      if excluded "${service}"; then
        echo "Cannot promote ${service}"
      else
        {
          echo '{'
          echo "  \"flow\": \"${flow}\","
          echo "  \"service\": \"${service}\","
          echo "  \"fingerprint\": \"${fingerprint}\","
          echo "  \"repo_url\": \"${repo_url}\","
          echo "  \"commit_sha\": \"${commit_sha}\","
          echo "  \"name\": \"${name}\""
          echo '}'
        } > "${filename}"
      fi
  done
}

write_matrix_include_file()
{
  matrix_include_filename="${ROOT_DIR}/json/matrix-include.json"
  {
    separator=""
    echo -n '{"include": ['
    local -r artifacts_length=$(echo "${diff}" | jq -r '.snappish1.artifacts | length')
    for ((n=0; n < ${artifacts_length}; n++))
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
  } > "${matrix_include_filename}"

  cat "${matrix_include_filename}" | jq .
}

check_args "$@"
write_json_files "$@"
write_matrix_include_file "$@"
