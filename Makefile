
promotions:
	@${PWD}/bin/create_snapshot_diff_json.sh | python3 ${PWD}/bin/promotions.py

run_tests:
	@${PWD}/tests/run_tests.sh
