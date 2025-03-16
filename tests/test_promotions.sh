#!/usr/bin/env bash

readonly my_dir="$(cd "$(dirname "${0}")" && pwd)"

test_no_deployments()
{
  local -r filename="0.json"
  create_promotions "${filename}"
  assert_stdout_equals "$(cat "${my_dir}/expected/${filename}")"
  assert_stderr_empty
  assert_status_0
}

test_new_flow()
{
  local -r filename="new-flow.json"
  create_promotions "${filename}"
  assert_stdout_equals "$(cat "${my_dir}/expected/${filename}")"
  assert_stderr_empty
  assert_status_0
}

test_4_deployments()
{
  local -r filename="4.json"
  create_promotions "${filename}"
  assert_stdout_equals "$(cat "${my_dir}/expected/${filename}")"
  assert_stderr_empty
  assert_status_0
}

test_blue_green_aws_beta()
{
  local -r filename="blue-green-aws-beta"
  create_promotions "${filename}.json"
  assert_stdout_empty
  assert_stderr_equals "$(cat "${my_dir}/expected/${filename}.txt")"
  assert_status_equals 42
}

test_blue_green_aws_prod()
{
  local -r filename="blue-green-aws-prod"
  create_promotions "${filename}.json"
  assert_stdout_empty
  assert_stderr_equals "$(cat "${my_dir}/expected/${filename}.txt")"
  assert_status_equals 42
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

create_promotions()
{
  local -r filename="${1}"
  cat ${my_dir}/diff-snapshots/${filename} | ${my_dir}/../bin/create_promotions.sh >${stdoutF} 2>${stderrF}
  status=${PIPESTATUS[1]}
  echo ${status} >${statusF}
}

echo "::${0##*/}"
. ${my_dir}/shunit2_helpers.sh
. ${my_dir}/shunit2

