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
{
  "include": [
    {
      "flow": "nginx-ci",
      "service": "nginx",
      "fingerprint": "0fd1eae4a2ab75d4d08106f86af3945a9e95b60693a4b9e4e44b59cc5887fdd1",
      "repo_url": "https://github.com/cyber-dojo/nginx/",
      "commit_sha": "fa32058a046015786d1589e16af7da0973f2e726",
      "name": "244531986313.dkr.ecr.eu-central-1.amazonaws.com/nginx:fa32058@sha256:0fd1eae4a2ab75d4d08106f86af3945a9e95b60693a4b9e4e44b59cc5887fdd1"
    },
    {
      "flow": "web-ci",
      "service": "web",
      "fingerprint": "337fa91d02fa59729aca2941bbfebf999d1c5ae74b1492a4c99a33a925c7f052",
      "repo_url": "https://github.com/cyber-dojo/web/",
      "commit_sha": "ed1878bd4aba3cada1e6ae7bc510f6354c61c484",
      "name": "244531986313.dkr.ecr.eu-central-1.amazonaws.com/web:ed1878b@sha256:337fa91d02fa59729aca2941bbfebf999d1c5ae74b1492a4c99a33a925c7f052"
    },
    {
      "flow": "custom-start-points-ci",
      "service": "custom-start-points",
      "fingerprint": "47849582a3804b2091b68e97dab36789e2346229df6d2c398c256a51c884e5ce",
      "repo_url": "https://github.com/cyber-dojo/custom-start-points/",
      "commit_sha": "df95ef1e16c367e9c1bda5de2b67c168ab17174b",
      "name": "244531986313.dkr.ecr.eu-central-1.amazonaws.com/custom-start-points:df95ef1@sha256:47849582a3804b2091b68e97dab36789e2346229df6d2c398c256a51c884e5ce"
    },
    {
      "flow": "languages-start-points-ci",
      "service": "languages-start-points",
      "fingerprint": "8fc546c2adeec10f8a52201e8e7fea854a804a929ab692275b61cbce141c9182",
      "repo_url": "https://github.com/cyber-dojo/languages-start-points/",
      "commit_sha": "9c270699fa10888b1c270ae69f8c13988bc4a26b",
      "name": "244531986313.dkr.ecr.eu-central-1.amazonaws.com/languages-start-points:9c27069@sha256:8fc546c2adeec10f8a52201e8e7fea854a804a929ab692275b61cbce141c9182"
    }
  ]
}
```

When NO Artifacts are found, the matrix-include.json file will be empty.
