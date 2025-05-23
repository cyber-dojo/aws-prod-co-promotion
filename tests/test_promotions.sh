#!/usr/bin/env bash

readonly my_dir="$(cd "$(dirname "${0}")" && pwd)"

test_SUCCESS_json_promotions_written_to_stdout() { :; }

test___SUCCESS_no_deployments()
{
  local -r filename="0.json"
  create_promotions "${filename}"
  assert_status_equals 0
  assert_stdout_equals "$(cat "${my_dir}/expected/${filename}")"
  assert_stderr_equals ""
}

test___SUCCESS_new_flow()
{
  local -r filename="new-flow.json"
  create_promotions "${filename}"
  assert_status_equals 0
  assert_stdout_equals "$(cat "${my_dir}/expected/${filename}")"
  assert_stderr_equals ""
}

test___SUCCESS_2_deployments()
{
  local -r filename="2.json"
  create_promotions "${filename}"
  assert_status_equals 0
  assert_stdout_equals "$(cat "${my_dir}/expected/${filename}")"
  assert_stderr_equals ""
}

test___SUCCESS_4_deployments()
{
  local -r filename="4.json"
  create_promotions "${filename}"
  assert_status_equals 0
  assert_stdout_equals "$(cat "${my_dir}/expected/${filename}")"
  assert_stderr_equals ""
}

test___SUCCESS_has_gitlab_image()
{
  local -r filename="has-gitlab-image.json"
  create_promotions "${filename}"
  assert_status_equals 0
  assert_stdout_equals "$(cat "${my_dir}/expected/${filename}")"
  assert_stderr_equals ""
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

test_FAILURE_with_diagnostic_on_stderr() { :; }

test___FAILURE_blue_green_aws_beta()
{
  local -r filename="blue-green-aws-beta"
  create_promotions "${filename}.json"
  assert_status_not_equals 0
  assert_stdout_equals ""
  assert_stderr_equals "$(cat "${my_dir}/expected/${filename}.txt")"
}

test___FAILURE_blue_green_aws_prod()
{
  local -r filename="blue-green-aws-prod"
  create_promotions "${filename}.json"
  assert_status_not_equals 0
  assert_stdout_equals ""
  assert_stderr_equals "$(cat "${my_dir}/expected/${filename}.txt")"
}

test___FAILURE_repo_urls_are_different()
{
  local -r filename="different-repo-urls"
  create_promotions "${filename}.json"
  assert_status_not_equals 0
  assert_stdout_equals ""
  assert_stderr_equals "$(cat "${my_dir}/expected/${filename}.txt")"
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

create_promotions()
{
  local -r filename="${1}"
  cat ${my_dir}/diff-snapshots/${filename} | python3 ${my_dir}/../bin/promotions.py >${stdoutF} 2>${stderrF}
  status=$?
  echo ${status} >${statusF}
}

echo "::${0##*/}"
. ${my_dir}/shunit2_helpers.sh
. ${my_dir}/shunit2

