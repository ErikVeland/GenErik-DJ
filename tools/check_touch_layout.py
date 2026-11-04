#!/usr/bin/env python3
"""Check production touch geometry without building an application."""
import argparse
from pathlib import Path
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--group", choices=["anchors", "panels", "contacts", "panel-pairs", "split", "all"], default="anchors")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix="generik-touch-layout-") as directory:
        executable = Path(directory) / "check"
        for group in (["anchors", "panels", "contacts", "panel-pairs", "split"] if args.group == "all" else [args.group]):
            sources = [root / "Replica/Sources/TDJInterface/AdaptivePerformanceLayout.swift"]
            if group == "split":
                sources += [root / "Replica/Sources/TDJInterface" / name for name in ["DeckSplitState.swift", "TouchContactGeometry.swift"]]
            if group in ["panels", "panel-pairs"]:
                sources.append(root / "Replica/Sources/TDJInterface/TouchPanelState.swift")
            if group == "panel-pairs":
                sources += [root / "Replica/Sources/TDJInterface" / name for name in [
                    "DeckPanelSizing.swift", "TouchContactGeometry.swift", "TouchSurfaceInputGate.swift", "DeckPanelPresentation.swift"]]
            if group == "contacts":
                sources += [root / "Replica/Sources/TDJInterface" / name for name in [
                    "TouchContactGeometry.swift", "FaderGestureSession.swift", "TouchAxisSession.swift",
                    "FilterPadContactState.swift", "EffectPadGestureSession.swift"]]
            harness = {"anchors": "check_touch_layout.swift", "panels": "check_touch_panels.swift",
                "contacts": "check_touch_contacts.swift", "panel-pairs": "check_performance_panels.swift", "split": "check_deck_split.swift"}[group]
            subprocess.run(["xcrun", "swiftc", "-parse-as-library",
                *map(str, sources), str(root / "tools" / harness), "-o", str(executable)], check=True)
            subprocess.run([str(executable)], check=True)


if __name__ == "__main__":
    main()
