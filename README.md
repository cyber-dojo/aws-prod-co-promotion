# aws-prod-co-promotion

Workflow to find out which Artifacts:
- Are running in the cyber-dojo https://beta.cyber-dojo.org
  [aws-beta](https://app.kosli.com/cyber-dojo/environments/aws-beta/snapshots/) Environment.
- Are NOT running in the cyber-dojo https://cyber-dojo.org 
  [aws-prod](https://app.kosli.com/cyber-dojo/environments/aws-prod/snapshots/) Environment.
- deploy them all, at the same time, into the latter.

```shell
$ ./bin/create_matrix_include.sh --help
```

```
    Use: create_matrix_include.sh

    Creates the file 'matrix-include.json' ready to be used in a
    Github Action matrix to run a parallel job for each Artifact.
    If a blue-green deployment is in progress for any of the Artifacts
    the script will exit with a non-zero value.
```

Example where four Artifacts were found:

```bash
$ make matrix_include
```

```json
[
    { 
        "incoming_image_name": "244531986313.dkr.ecr.eu-central-1.amazonaws.com/nginx:fa32058@sha256:0fd1eae4a2ab75d4d08106f86af3945a9e95b60693a4b9e4e44b59cc5887fdd1",
        "incoming_fingerprint": "0fd1eae4a2ab75d4d08106f86af3945a9e95b60693a4b9e4e44b59cc5887fdd1",
        "incoming_repo_url": "https://github.com/cyber-dojo/nginx/",
        "incoming_repo_name": "nginx",
        "incoming_commit_sha": "fa32058a046015786d1589e16af7da0973f2e726",
        "incoming_flow": "nginx-ci"
    },
    {
        "incoming_image_name": "244531986313.dkr.ecr.eu-central-1.amazonaws.com/web:ed1878b@sha256:337fa91d02fa59729aca2941bbfebf999d1c5ae74b1492a4c99a33a925c7f052",
        "incoming_fingerprint": "337fa91d02fa59729aca2941bbfebf999d1c5ae74b1492a4c99a33a925c7f052",
        "incoming_repo_url": "https://github.com/cyber-dojo/web/",
        "incoming_repo_name": "web",
        "incoming_commit_sha": "ed1878bd4aba3cada1e6ae7bc510f6354c61c484",
        "incoming_flow": "web-ci"
    },
    {
        "incoming_image_name": "244531986313.dkr.ecr.eu-central-1.amazonaws.com/custom-start-points:df95ef1@sha256:47849582a3804b2091b68e97dab36789e2346229df6d2c398c256a51c884e5ce",
        "incoming_fingerprint": "47849582a3804b2091b68e97dab36789e2346229df6d2c398c256a51c884e5ce",
        "incoming_repo_url": "https://github.com/cyber-dojo/custom-start-points/",
        "incoming_repo_name": "custom-start-points",
        "incoming_commit_sha": "df95ef1e16c367e9c1bda5de2b67c168ab17174b",
        "incoming_flow": "custom-start-points-ci"
    }
]
```

When NO Artifacts are found, the matrix-include.json file will be '[]'.
