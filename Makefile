
matrix_include:
	@${PWD}/bin/create_snapshot_diff_json.sh | ${PWD}/bin/create_matrix_include.sh | jq .

run_tests:
	@${PWD}/tests/run_tests.sh

json_files:
	@${PWD}/bin/create_json_files.sh