
new_promotions:
	@${PWD}/bin/create_snapshot_diff_json.sh | python3 ${PWD}/bin/promotions.py

promotions:
	@${PWD}/bin/create_snapshot_diff_json.sh | ${PWD}/bin/create_promotions.sh | jq .

run_tests:
	@${PWD}/tests/run_tests.sh

json_files:
	@${PWD}/bin/create_json_files.sh