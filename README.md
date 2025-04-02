# Release/Promotion workflow

Workflow to use [Kosli](https://kosli.com) find out which Artifacts:
- Are running in the cyber-dojo https://beta.cyber-dojo.org [aws-beta](https://app.kosli.com/cyber-dojo/environments/aws-beta/snapshots/) staging Environment.
- Are NOT running in the cyber-dojo https://cyber-dojo.org [aws-prod](https://app.kosli.com/cyber-dojo/environments/aws-prod/snapshots/) production Environment.
- Deploys them all, in parallel, after approval, into the latter.
- Records this release/promotion in a dedicated [Kosli Flow](https://app.kosli.com/cyber-dojo/flows/production-promotion/trails/)

```bash
python3 ./bin/promotions.py --help
```

```
    Reads (from stdin) the result of a 'kosli diff snapshots aws-beta aws-prod --org=cyber-dojo ... --output=json'.
    Writes (to stdout) a JSON array with one dict for each Artifact to be promoted.
    This JSON can be used as the source for a Github Action strategy:matrix:include to run a parallel job for each Artifact.
    If a blue-green deployment is in progress in aws-beta or aws-prod, the script will exit with a non-zero value.
        
    Example:
    
      $ ./bin/create_snapshot_diff_json.sh | python3 ./bin/promotions.py    
      ...
```

Example:

```bash
make promotions
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
        "outgoing_flow": "nginx-ci",
        "deployment_diff_url": "https://github.com/cyber-dojo/nginx/compare/fa32058a046015786d1589e16af7da0973f2e726...e92d83d1bf0b1de46205d5e19131f1cee2b6b3da"
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
        "outgoing_flow": "web-ci",
        "deployment_diff_url": "https://github.com/cyber-dojo/web/compare/ed1878bd4aba3cada1e6ae7bc510f6354c61c484...5db3d66084de99c0b9b3847680de78ea01f63643"
    },
    ...
]
```

When there are no promotion Artifacts, the echoed JSON will be an empty array.

```bash
make promotions
```

```json
[]
```
