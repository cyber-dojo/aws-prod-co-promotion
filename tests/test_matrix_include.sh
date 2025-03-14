#!/usr/bin/env bash

readonly my_dir="$(cd "$(dirname "${0}")" && pwd)"

test_no_deployments()
{
  local -r filename="0.json"
  create_matrix_include "${filename}"
  assert_stdout_equals "$(cat "${my_dir}/expected/${filename}")"
  assert_stderr_empty
  assert_status_0
}

xtest_new_flow()
{
  local -r filename="new-flow.json"
  create_matrix_include "${filename}"
  assert_stdout_equals "$(cat "${my_dir}/expected/${filename}")"
  assert_stderr_empty
  assert_status_0
}

xtest_4_deployments()
{
  local -r filename="4.json"
  create_matrix_include "${filename}"
  assert_stdout_equals "$(cat "${my_dir}/expected/${filename}")"
  assert_stderr_empty
  assert_status_0
}

xtest_blue_green_aws_beta()
{
  local -r filename="blue-green-aws-beta.json"
  create_matrix_include "${filename}"
}

xtest_blue_green_aws_prod()
{
  local -r filename="blue-green-aws-prod.json"
  create_matrix_include "${filename}"
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

create_matrix_include()
{
  local -r filename="${1}"
  cat ${my_dir}/diff-snapshots/${filename} | ${my_dir}/../bin/create_matrix_include.sh | jq . >${stdoutF} 2>${stderrF}
  status=$?
  echo ${status} >${statusF}
}

echo "::${0##*/}"
. ${my_dir}/shunit2_helpers.sh
. ${my_dir}/shunit2

