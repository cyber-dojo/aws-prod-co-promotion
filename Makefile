
matrix_include:
	 @${PWD}/bin/create_snapshot_diff_json.sh | ${PWD}/bin/create_matrix_include.sh | jq .

diff-0-test:
	 @cat ${PWD}/docs/diff-snapshots-0.json | ${PWD}/bin/create_matrix_include.sh | jq .

diff-snapshots-new-flow-test:
	 @cat ${PWD}/docs/diff-snapshots-new-flow.json | ${PWD}/bin/create_matrix_include.sh | jq .

diff-4-test:
	 @cat ${PWD}/docs/diff-snapshots-4.json | ${PWD}/bin/create_matrix_include.sh | jq .

json_files:
	@${PWD}/bin/create_json_files.sh