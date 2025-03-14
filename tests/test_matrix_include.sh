#!/usr/bin/env bash

readonly my_dir="$(cd "$(dirname "${0}")" && pwd)"

test_no_deployments()
{
  create_matrix_include 0.json
}

test_new_flow()
{
  create_matrix_include new-flow.json
}

test_4_deployments()
{
  create_matrix_include 4.json
}

test_blue_green_aws_beta()
{
  create_matrix_include blue-green-aws-beta.json
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

create_matrix_include()
{
  local -r filename="${1}"
  cat ${my_dir}/diff-snapshots/${filename} | ${my_dir}/../bin/create_matrix_include.sh | jq .
}

echo "::${0##*/}"
. ${my_dir}/shunit2_helpers.sh
. ${my_dir}/shunit2

