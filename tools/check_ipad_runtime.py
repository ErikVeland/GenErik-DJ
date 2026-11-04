#!/usr/bin/env python3
"""Verify bundled framework load paths in a saved iPad app."""
from pathlib import Path
import argparse
import plistlib
import re
import subprocess
import sys


def verify_embedded_frameworks(app):
    app = Path(app).resolve()
    with (app / "Info.plist").open("rb") as stream:
        executable = app / plistlib.load(stream)["CFBundleExecutable"]
    visited = set()
    frameworks = set()

    def expand(path, loader):
        return Path(path.replace("@executable_path", str(executable.parent))
                    .replace("@loader_path", str(loader.parent)))

    def visit(binary, inherited):
        binary = binary.resolve()
        if binary in visited:
            return
        visited.add(binary)
        commands = subprocess.check_output(["xcrun", "otool", "-l", str(binary)], text=True)
        paths = [expand(path, binary) for path in re.findall(r"\bpath (.+?) \(offset \d+\)", commands)]
        paths += inherited
        libraries = subprocess.check_output(["xcrun", "otool", "-L", str(binary)], text=True)
        for line in libraries.splitlines()[1:]:
            dependency = line.strip().split(" (compatibility version", 1)[0]
            if ".framework/" not in dependency or dependency.startswith(("/System/Library/", "/usr/lib/")):
                continue
            if dependency.startswith("@rpath/"):
                candidates = [path / dependency.removeprefix("@rpath/") for path in paths]
            else:
                candidates = [expand(dependency, binary)]
            target = next((path.resolve() for path in candidates
                           if path.is_file() and path.resolve().is_relative_to(app)), None)
            if target is None:
                raise ValueError(f"Cannot load {dependency} from {binary.name}. Check the embedded framework and runtime search paths.")
            frameworks.add(target)
            visit(target, paths)

    visit(executable, [])
    return len(frameworks)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("app", type=Path)
    args = parser.parse_args()
    try:
        count = verify_embedded_frameworks(args.app)
    except (ValueError, FileNotFoundError, subprocess.CalledProcessError) as error:
        print(f"Runtime check failed: {error}", file=sys.stderr)
        return 1
    print(f"Runtime search paths resolve {count} embedded framework(s).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
