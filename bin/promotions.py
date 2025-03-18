#!/usr/local/bin/python3

import json
import sys


def promotions():
    diff = json.loads(sys.stdin.read())
    incoming = diff["snappish1"]
    outgoing = diff["snappish2"]
    common = diff["changed"]["artifacts"] + diff["not-changed"]["artifacts"]

    incoming_flow_names = [artifact["flow"] for artifact in incoming["artifacts"]]
    outgoing_flow_names = [artifact["flow"] for artifact in outgoing["artifacts"]]
    common_flow_names = [artifact["flow"] for artifact in common]

    # print(json.dumps(incoming_flow_names, indent=2))
    # print(json.dumps(outgoing_flow_names, indent=2))
    # print(json.dumps(common_flow_names, indent=2))

    exit_non_zero_if_mid_blue_green_deployment("incoming", incoming_flow_names + common_flow_names)
    exit_non_zero_if_mid_blue_green_deployment("outgoing", outgoing_flow_names + common_flow_names)


def exit_non_zero_if_mid_blue_green_deployment(kind, flow_names):
    print(flow_names)





if __name__ == "__main__":  # pragma: no cover
    promotions()
