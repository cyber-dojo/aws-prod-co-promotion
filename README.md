# aws-prod-co-promotion

Workflow to find which Artifacts are running in cyber-dojo's https://beta.cyber-dojo.org AWS staging environment
that are NOT also running in cyber-dojo's https://cyber-dojo.org AWS prod environment, and to promote them
all (at the same time) from the former to latter.

```shell
./bin/find_artifacts.sh --help
```

```
    Use: find-artifacts.sh

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