#!/usr/bin/env python3
"""Check production touch geometry without building an application."""
import argparse
from pathlib import Path
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--group", choices=["anchors", "panels", "all"], default="anchors")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix="generik-touch-layout-") as directory:
        executable = Path(directory) / "check"
        for group in (["anchors", "panels"] if args.group == "all" else [args.group]):
            sources = [root / "Replica/Sources/TDJInterface/AdaptivePerformanceLayout.swift"]
            if group == "panels":
                sources.append(root / "Replica/Sources/TDJInterface/TouchPanelState.swift")
            harness = "check_touch_layout.swift" if group == "anchors" else "check_touch_panels.swift"
            subprocess.run(["xcrun", "swiftc", "-parse-as-library",
                *map(str, sources), str(root / "tools" / harness), "-o", str(executable)], check=True)
            subprocess.run([str(executable)], check=True)


if __name__ == "__main__":
    main()
