#!/usr/bin/env python3
"""Summarise the retained, fixed-size native callback timing traces."""
import argparse
import json
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("result", type=Path)
args = parser.parse_args()
data = json.loads(args.result.read_text())
scale = data["hostTickNanoseconds"] / 1_000_000
traces = []
for trace in data.get("gapTimingTraces", []):
    before = [cycle for cycle in trace["before"] if cycle["endHostTick"]]
    gap = trace["gap"]
    previous = before[-1] if before else None
    def describe(cycle):
        return {
            "frame": cycle["frame"],
            "sampleTime": cycle["sampleTime"],
            "sourceWallMs": (cycle["endHostTick"] - cycle["arrivalHostTick"]) * scale,
            "coreRenderMs": (cycle["renderEndHostTick"] - cycle["renderBeginHostTick"])*scale if "renderBeginHostTick" in cycle else None,
            "beginCPUProbeMs": cycle["beginCPUProbeHostTicks"]*scale if data["callbackProfilingEnabled"] and "beginCPUProbeHostTicks" in cycle else None,
            "endCPUProbeMs": cycle["endCPUProbeHostTicks"]*scale if data["callbackProfilingEnabled"] and "endCPUProbeHostTicks" in cycle else None,
            "renderThroughMs": (cycle["renderEndHostTick"] - cycle["arrivalHostTick"]) * scale if "renderEndHostTick" in cycle else None,
            "checksAfterRenderMs": (cycle["endHostTick"] - cycle["renderEndHostTick"]) * scale if "renderEndHostTick" in cycle else None,
            "presentationMinusArrivalMs": (cycle["presentationHostTick"] - cycle["arrivalHostTick"]) * scale,
            "precedingMixerWallMs": (cycle["previousGraphEnd"] - cycle["previousGraphBegin"]) * scale if cycle["previousGraphEnd"] else None,
        }
    worst = sorted(before, key=lambda c: c["endHostTick"]-c["arrivalHostTick"], reverse=True)[:3]
    traces.append({
        "gap": describe(gap),
        "deviceFramesSkipped": gap["sampleTime"]-previous["sampleTime"]-previous["count"] if previous else None,
        "sourceArrivalIntervalMs": (gap["arrivalHostTick"]-previous["arrivalHostTick"])*scale if previous else None,
        "sourceIdleIntervalMs": (gap["arrivalHostTick"]-previous["endHostTick"])*scale if previous else None,
        "lastFour": [describe(c) for c in before[-4:]],
        "longestThreeInHistory": [describe(c) for c in worst],
    })
print(json.dumps({"source": str(args.result), "timingUnit": "milliseconds", "traces": traces}, indent=2))
