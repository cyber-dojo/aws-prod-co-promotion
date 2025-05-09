import json
import sys
from collections import Counter


def print_help():
    print("""
        Reads (from stdin) the result of a 'kosli diff snapshots aws-beta aws-prod --org=cyber-dojo ... --output=json'.
        Writes (to stdout) a JSON array with one dict for each Artifact to be promoted.
        This JSON can be used as the source for a Github Action strategy:matrix:include to run a parallel job for each Artifact.
        If a blue-green deployment is in progress in aws-beta or aws-prod, the script will exit with a non-zero value.
        Also creates an all-annotations.txt file containing --annotation flags to be used in a Kosli attestation.

        Example:

          $ ./bin/create_snapshot_diff_json.sh | python3 ./bin/promotions.py    
          [
              {
                  "incoming_snapshot_id": "aws-beta#5088",
                  "incoming_snapshot_url": "https://app.kosli.com/cyber-dojo/environments/aws-beta/snapshots/5088?fingerprint=0fd1eae4a2ab75d4d08106f86af3945a9e95b60693a4b9e4e44b59cc5887fdd1"
                  "incoming_image_name": "244531986313.dkr.ecr.eu-central-1.amazonaws.com/nginx:fa32058@sha256:0fd1eae4a2ab75d4d08106f86af3945a9e95b60693a4b9e4e44b59cc5887fdd1",
                  "incoming_fingerprint": "0fd1eae4a2ab75d4d08106f86af3945a9e95b60693a4b9e4e44b59cc5887fdd1",
                  "incoming_repo_url": "https://github.com/cyber-dojo/nginx/",
                  "incoming_repo_name": "nginx",
                  "incoming_commit_sha": "fa32058a046015786d1589e16af7da0973f2e726",
                  "incoming_flow": "nginx-ci",
                  "incoming_ci": "github",
                  "outgoing_image_name": "244531986313.dkr.ecr.eu-central-1.amazonaws.com/nginx:e92d83d@sha256:0f803b05be83006c77e8c371b1f999eaabfb2feca9abef64332633362b36ca94",
                  "outgoing_fingerprint": "0f803b05be83006c77e8c371b1f999eaabfb2feca9abef64332633362b36ca94",
                  "outgoing_repo_url": "https://github.com/cyber-dojo/nginx",
                  "outgoing_repo_name": "nginx",
                  "outgoing_commit_sha": "e92d83d1bf0b1de46205d5e19131f1cee2b6b3da",
                  "outgoing_flow": "nginx-ci",
                  "outgoing_ci": "github",
                  "deployment_diff_url": "https://github.com/cyber-dojo/nginx/compare/fa32058a046015786d1589e16af7da0973f2e726...e92d83d1bf0b1de46205d5e19131f1cee2b6b3da"
              },
              ...
          ]
    """)


def promotions():
    diff = json.loads(sys.stdin.read())
    incoming = diff["snappish1"]
    outgoing = diff["snappish2"]
    common = diff["changed"]["artifacts"] + diff["not-changed"]["artifacts"]

    incoming_flow_names = [artifact["flow"] for artifact in incoming["artifacts"]]
    outgoing_flow_names = [artifact["flow"] for artifact in outgoing["artifacts"]]
    common_flow_names = [artifact["flow"] for artifact in common]

    incoming_env_id = incoming["snapshot_id"]  # eg aws-beta#5081
    outgoing_env_id = outgoing["snapshot_id"]  # eg aws-prod#3699
    exit_non_zero_if_mid_blue_green_deployment(incoming_env_id, incoming_flow_names + common_flow_names)
    exit_non_zero_if_mid_blue_green_deployment(outgoing_env_id, outgoing_flow_names + common_flow_names)

    snapshot_info = {a["flow"]: get_snapshot_info(incoming_env_id, a) for a in incoming["artifacts"]}
    outgoing_artifacts = {a["flow"]: prefixed_artifact("outgoing", a) for a in outgoing["artifacts"]}
    incoming_artifacts = {a["flow"]: prefixed_artifact("incoming", a) for a in incoming["artifacts"]}
    matching_outgoing = {a["flow"]: blanked_artifact(a["flow"], outgoing_artifacts) for a in incoming["artifacts"]}

    deployment_diff_urls = {flow: deployment_diff_url(incoming_artifacts[flow], matching_outgoing[flow]) for flow in incoming_artifacts.keys()}

    return [snapshot_info[flow] | incoming_artifacts[flow] | matching_outgoing[flow] | deployment_diff_urls[flow]
            for flow in incoming_artifacts.keys()]


def deployment_diff_url(incoming_artifact, outgoing_artifact):
    incoming_flow = incoming_artifact["incoming_flow"]
    outgoing_flow = outgoing_artifact["outgoing_flow"]
    incoming_repo_url = incoming_artifact["incoming_repo_url"]
    outgoing_repo_url = outgoing_artifact["outgoing_repo_url"]
    incoming_commit_sha = incoming_artifact["incoming_commit_sha"]
    outgoing_commit_sha = outgoing_artifact["outgoing_commit_sha"]

    if outgoing_flow == "":
        url = f"{incoming_repo_url}/commit/{incoming_commit_sha}"
    elif incoming_repo_url != outgoing_repo_url:
        stderr(f"In Flow {incoming_flow} repo_url entries are different.")
        stderr(f"Incoming repo_url={incoming_repo_url}")
        stderr(f"Outgoing repo_url={outgoing_repo_url}")
        sys.exit(42)
    else:
        assert incoming_flow == outgoing_flow
        url = f"{incoming_repo_url}/compare/{outgoing_commit_sha}...{incoming_commit_sha}"

    return {"deployment_diff_url": url}


def get_snapshot_info(incoming_env_id, incoming_artifact):
    # eg incoming_env_id == aws-beta#5081
    env, sid = incoming_env_id.split("#")
    fingerprint = incoming_artifact["fingerprint"]
    return {
        "incoming_snapshot_id": incoming_env_id,
        "incoming_snapshot_url": f"https://app.kosli.com/cyber-dojo/environments/{env}/snapshots/{sid}?fingerprint={fingerprint}"
    }


def blanked_artifact(flow_name, outgoing_artifact):
    if flow_name in outgoing_artifact:
        return outgoing_artifact[flow_name]
    else:
        kind = "outgoing"
        return {
            f"{kind}_image_name": "",
            f"{kind}_fingerprint": "",
            f"{kind}_repo_url": "",
            f"{kind}_repo_name": "",
            f"{kind}_commit_sha": "",
            f"{kind}_flow": "",
            f"{kind}_ci": ""
        }


def prefixed_artifact(kind, artifact):
    image_name = artifact["name"]          # 244531986313.dkr.ecr.eu-central-1.amazonaws.com/saver:6e191a0@sha256:b3237b0e615e7041c23433faeee0bacd6ec893e89ae8899536433e4d27a5b6ef
    fingerprint = artifact["fingerprint"]  # b3237b0e615e7041c23433faeee0bacd6ec893e89ae8899536433e4d27a5b6ef
    flow = artifact["flow"]                # saver-ci
    commit_url = artifact["commit_url"]    # https://github.com/cyber-dojo/saver/commit/6e191a0a86cf3d264955c4910bc3b9df518c4bcd
    commit_sha = commit_url[-40:]          # 6e191a0a86cf3d264955c4910bc3b9df518c4bcd

    return {
        f"{kind}_image_name": image_name,
        f"{kind}_fingerprint": fingerprint,
        f"{kind}_repo_url": repo_url(artifact),    # https://github.com/cyber-dojo/saver
        f"{kind}_repo_name": repo_name(artifact),  # saver
        f"{kind}_commit_sha": commit_sha,
        f"{kind}_flow": flow,
        f"{kind}_ci": ci_system(artifact)
    }


def write_annotations_file(services):
    annotations = []
    for service in services:
        key = service["incoming_repo_name"]
        diff_url = service["deployment_diff_url"]
        quote = '"'
        annotations.append(f"--annotate {quote}{key}_diff_URL={diff_url}{quote}")

    with open("all-annotations.txt", "w") as file:
        file.write(" ".join(annotations))


def ci_system(artifact):
    commit_url = artifact["commit_url"]
    if commit_url.startswith("https://github.com/"):
        return "github"
    elif commit_url.startswith("https://gitlab.com"):
        return "gitlab"


def repo_url(artifact):
    commit_url = artifact["commit_url"]
    if ci_system(artifact) == "github":    # https://github.com/cyber-dojo/saver/commit/6e191a0a86cf3d264955c4910bc3b9df518c4bcd
        return commit_url[0:-48]           # --> https://github.com/cyber-dojo/saver
    elif ci_system(artifact) == "gitlab":  # https://gitlab.com/cyber-dojo/creator/-/commit/63739c64c04437b29e3fe082d699fb757846e0f0
        return commit_url[0:-50]           # --> https://gitlab.com/cyber-dojo/creator


def repo_name(artifact):
    return repo_url(artifact).split('/')[-1]


def exit_non_zero_if_mid_blue_green_deployment(env_id, flow_names):
    duplicate_flow_names = duplicates(flow_names)
    if duplicate_flow_names:
        stderr(f"A blue-green deployment is in progress in {env_id}")
        stderr(f"For {duplicate_flow_names}")
        sys.exit(42)


def duplicates(seq):
    return [k for k, v in Counter(seq).items() if v > 1]


def stderr(message):
    print(f"ERROR: {message}", file=sys.stderr)


if __name__ == "__main__":  # pragma: no cover
    if len(sys.argv) > 1 and sys.argv[1] in ["-h", "--help"]:
        print_help()
    else:
        # Note: This is expecting input on stdin
        info = promotions()
        print(json.dumps(info, indent=2))
        write_annotations_file(info)
