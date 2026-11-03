#!/usr/bin/env python3
"""Check production touch geometry without building an application."""
import argparse
from pathlib import Path
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--group", choices=["anchors"], default="anchors")
    parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix="generik-touch-layout-") as directory:
        executable = Path(directory) / "check"
        subprocess.run([
            "xcrun", "swiftc", "-parse-as-library",
            str(root / "Replica/Sources/TDJInterface/AdaptivePerformanceLayout.swift"),
            str(root / "tools/check_touch_layout.swift"), "-o", str(executable),
        ], check=True)
        subprocess.run([str(executable)], check=True)


if __name__ == "__main__":
    main()
