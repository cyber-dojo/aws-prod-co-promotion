
matrix_include:
	 @${PWD}/bin/create_snapshot_diff_json.sh | ${PWD}/bin/create_matrix_include.sh | jq .

test-0:
	 @cat ${PWD}/docs/diff-snapshots-0.json | ${PWD}/bin/create_matrix_include.sh | jq .

test-new-flow:
	 @cat ${PWD}/docs/diff-snapshots-new-flow.json | ${PWD}/bin/create_matrix_include.sh | jq .

test-4:
	 @cat ${PWD}/docs/diff-snapshots-4.json | ${PWD}/bin/create_matrix_include.sh | jq .

test-blue-green-aws-beta:
	 @cat ${PWD}/docs/diff-snapshots-blue-green-aws-beta.json | ${PWD}/bin/create_matrix_include.sh | jq .

json_files:
	@${PWD}/bin/create_json_files.sh