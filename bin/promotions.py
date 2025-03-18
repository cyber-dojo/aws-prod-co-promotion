#!/usr/local/bin/python3

import json
import sys
from collections import Counter


def promotions():
    diff = json.loads(sys.stdin.read())
    incoming = diff["snappish1"]
    outgoing = diff["snappish2"]
    common = diff["changed"]["artifacts"] + diff["not-changed"]["artifacts"]

    incoming_flow_names = [artifact["flow"] for artifact in incoming["artifacts"]]
    outgoing_flow_names = [artifact["flow"] for artifact in outgoing["artifacts"]]
    common_flow_names = [artifact["flow"] for artifact in common]

    incoming_env_id = incoming["snapshot_id"]
    outgoing_env_id = outgoing["snapshot_id"]
    exit_non_zero_if_mid_blue_green_deployment(incoming_env_id, incoming_flow_names + common_flow_names)
    exit_non_zero_if_mid_blue_green_deployment(outgoing_env_id, outgoing_flow_names + common_flow_names)

    incoming_artifacts = inflated_artifacts("incoming", incoming)
    outgoing_artifacts = inflated_artifacts("outgoing", outgoing)

    #print(json.dumps(incoming_artifacts, indent=2))
    #print(json.dumps(outgoing_artifacts, indent=2))


def inflated_artifacts(kind, snappish):
    return [inflated_artifact(kind, art) for art in snappish["artifacts"] if not excluded_flow(art)]


def inflated_artifact(kind, artifact):
    image_name = artifact["name"]          # 244531986313.dkr.ecr.eu-central-1.amazonaws.com/saver:6e191a0@sha256:b3237b0e615e7041c23433faeee0bacd6ec893e89ae8899536433e4d27a5b6ef
    fingerprint = artifact["fingerprint"]  # b3237b0e615e7041c23433faeee0bacd6ec893e89ae8899536433e4d27a5b6ef
    flow = artifact["flow"]                # saver-ci
    commit_url = artifact["commit_url"]    # https://github.com/cyber-dojo/saver/commit/6e191a0a86cf3d264955c4910bc3b9df518c4bcd
    commit_sha = commit_url[-40:]          # 6e191a0a86cf3d264955c4910bc3b9df518c4bcd
    repo_url = commit_url[0:-48]           # https://github.com/cyber-dojo/saver
    repo_name = repo_url.split('/')[-1]    # saver

    return {
        f"{kind}_image_name": image_name,
        f"{kind}_fingerprint": fingerprint,
        f"{kind}_repo_url": repo_url,
        f"{kind}_repo_name": repo_name,
        f"{kind}_commit_sha": commit_sha,
        f"{kind}_flow": flow
    }


def excluded_flow(artifact):
    flow = artifact["flow"]
    if flow == "differ-ci":
        return True
    elif flow == "creator-ci":
        return True
    else:
        return False


def exit_non_zero_if_mid_blue_green_deployment(env_id, flow_names):
    duplicate_flow_names = duplicates(flow_names)
    if duplicate_flow_names:
        stderr(f"A blue-green deployment is in progress in {env_id}")
        stderr(f"For {duplicate_flow_names}")
        sys.exit(42)


def duplicates(seq):
    return [k for k, v in Counter(seq).items() if v > 1]


def stderr(message):
    print(message, file=sys.stderr)


if __name__ == "__main__":  # pragma: no cover
    promotions()
