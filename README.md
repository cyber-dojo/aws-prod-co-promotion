# aws-prod-co-promotion

Workflow to find which Artifacts are running in cyber-dojo's https://beta.cyber-dojo.org AWS staging environment
that are NOT also running in cyber-dojo's https://cyber-dojo.org AWS prod environment, and to promote them
all (at the same time) from the former to latter.

```shell
./bin/find_artifacts.sh --help
```

```
    Use: find_artifacts.sh

    Uses the Kosli CLI to find which Artifacts are running in cyber-dojo's
    https://beta.cyber-dojo.org AWS staging environment that are NOT also
    running in cyber-dojo's https://cyber-dojo.org AWS prod environment.
    Creates a json file in the json/ directory for each Artifact. Eg

    {
             "name": "244531986313.dkr.ecr.eu-central-1.amazonaws.com/saver:c3b308d@sha256:8bf657f7f47a4c32b2ffb0c650be2ced4de18e646309a4dfe11db22dfe2ea5eb",
      "fingerprint": "8bf657f7f47a4c32b2ffb0c650be2ced4de18e646309a4dfe11db22dfe2ea5eb",
         "repo_url": "https://github.com/cyber-dojo/saver/",
       "commit_sha": "c3b308d153f3594afea873d0c55b86dae929a9c5",
          "service": "saver"
    }

    Also creates the file 'matrix-include.json' ready to be used in a
    Github Action matrix to run a parallel job for each Artifact.
```

After the workflow has completed there should be no difference between the Artifacts
running in https://beta.cyber-dojo.org and https://cyber-dojo.org
(unless new Artifacts have appeared in the former during the promotion!)

You can check this by running:
```bash
make find_artifacts
```
which prints two things.

1. the current latest Kosli snapshot numbers for 
    [aws-beta](https://app.kosli.com/cyber-dojo/environments/aws-beta/snapshots/) which is the Kosli Environment for https://beta.cyber-dojo.org and
    [aws-prod](https://app.kosli.com/cyber-dojo/environments/aws-prod/snapshots/) which is the Kosli Environment for https://cyber-dojo.org
    For example:
    ```bash
    FROM: aws-beta#4754
      TO: aws-prod#3553
    ```
2. The contents of the matrix-include.json file which should be an empty list. 
    For example:
    ```json
    {
      "include": []
    }
    ```
