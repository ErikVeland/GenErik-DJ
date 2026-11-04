#!/usr/bin/env python3
"""Check production front-screen state and geometry without building an app."""
from pathlib import Path
import subprocess
import tempfile


def main():
    root = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix="generik-front-performance-") as directory:
        executable = Path(directory) / "check"
        sources = [root / "Replica/Sources/TDJInterface" / name for name in [
            "FrontPerformanceLayout.swift", "BrowserPresentation.swift",
            "TouchPanelState.swift", "AdaptivePerformanceLayout.swift"]]
        subprocess.run(["xcrun", "swiftc", "-parse-as-library", *map(str, sources),
                        str(root / "tools/check_front_performance.swift"), "-o", str(executable)], check=True)
        subprocess.run([str(executable)], check=True)


if __name__ == "__main__":
    main()
