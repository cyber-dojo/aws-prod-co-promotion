# aws-prod-co-promotion

Workflow to find out which Artifacts:
- Are running in the cyber-dojo https://beta.cyber-dojo.org
  [aws-beta](https://app.kosli.com/cyber-dojo/environments/aws-beta/snapshots/) Environment.
- Are NOT running in the cyber-dojo https://cyber-dojo.org 
  [aws-prod](https://app.kosli.com/cyber-dojo/environments/aws-prod/snapshots/) Environment.
- Deploy them all, at the same time, into the latter.

```shell
$ ./bin/create_matrix_include.sh --help
```

```
    Use: create_matrix_include.sh

    Reads (from stdin) the result of a 'kosli diff snapshots aws-beta aws-prod --org=cyber-dojo ... --output-type=json'.
    Writes (to stdout) a JSON array with one dict for each Artifact to be promoted.
    This JSON can be used in a Github Action matrix to run a parallel job for each Artifact.
    If a blue-green deployment is in progress in aws-beta or aws-prod, the script will exit with a non-zero value.    
    Example:
      ...
```

Example where three Artifacts were found:

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
        "incoming_flow": "nginx-ci",
        "outgoing_image_name": "244531986313.dkr.ecr.eu-central-1.amazonaws.com/nginx:e92d83d@sha256:0f803b05be83006c77e8c371b1f999eaabfb2feca9abef64332633362b36ca94",
        "outgoing_fingerprint": "0f803b05be83006c77e8c371b1f999eaabfb2feca9abef64332633362b36ca94",
        "outgoing_repo_url": "https://github.com/cyber-dojo/nginx",
        "outgoing_repo_name": "nginx",
        "outgoing_commit_sha": "e92d83d1bf0b1de46205d5e19131f1cee2b6b3da",
        "outgoing_flow": "nginx-ci"      
    },
    {
        "incoming_image_name": "244531986313.dkr.ecr.eu-central-1.amazonaws.com/web:ed1878b@sha256:337fa91d02fa59729aca2941bbfebf999d1c5ae74b1492a4c99a33a925c7f052",
        "incoming_fingerprint": "337fa91d02fa59729aca2941bbfebf999d1c5ae74b1492a4c99a33a925c7f052",
        "incoming_repo_url": "https://github.com/cyber-dojo/web/",
        "incoming_repo_name": "web",
        "incoming_commit_sha": "ed1878bd4aba3cada1e6ae7bc510f6354c61c484",
        "incoming_flow": "web-ci",
        "outgoing_image_name": "244531986313.dkr.ecr.eu-central-1.amazonaws.com/web:5db3d66@sha256:49cfb0d0696a9934e408ff20eaeea17ba87924ea520963be2021134814a086cc",
        "outgoing_fingerprint": "49cfb0d0696a9934e408ff20eaeea17ba87924ea520963be2021134814a086cc",
        "outgoing_repo_url": "https://github.com/cyber-dojo/web",
        "outgoing_repo_name": "web",
        "outgoing_commit_sha": "5db3d66084de99c0b9b3847680de78ea01f63643",
        "outgoing_flow": "web-ci"      
    },
    {
        "incoming_image_name": "244531986313.dkr.ecr.eu-central-1.amazonaws.com/custom-start-points:df95ef1@sha256:47849582a3804b2091b68e97dab36789e2346229df6d2c398c256a51c884e5ce",
        "incoming_fingerprint": "47849582a3804b2091b68e97dab36789e2346229df6d2c398c256a51c884e5ce",
        "incoming_repo_url": "https://github.com/cyber-dojo/custom-start-points/",
        "incoming_repo_name": "custom-start-points",
        "incoming_commit_sha": "df95ef1e16c367e9c1bda5de2b67c168ab17174b",
        "incoming_flow": "custom-start-points-ci",
        "outgoing_image_name": "244531986313.dkr.ecr.eu-central-1.amazonaws.com/custom-start-points:0a4a895@sha256:f896ba9ae26c6f53a5229704fac1cf6b0eb34e3b8fd8c1cd6f24d808cc52d96f",
        "outgoing_fingerprint": "f896ba9ae26c6f53a5229704fac1cf6b0eb34e3b8fd8c1cd6f24d808cc52d96f",
        "outgoing_repo_url": "https://github.com/cyber-dojo/custom-start-points",
        "outgoing_repo_name": "custom-start-points",
        "outgoing_commit_sha": "0a4a8953918f5be854e424946201e98820d9c789",
        "outgoing_flow": "custom-start-points-ci"      
    }
]
```

When NO Artifacts are found, the matrix-include.json file will contain '[]'.
