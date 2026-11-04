#!/usr/bin/env python3
"""Check repository hygiene, script syntax and local documentation links."""
import ast
from pathlib import Path
import re
import subprocess
import sys
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[1]


def main():
    output = subprocess.check_output(
        ["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"], cwd=ROOT)
    paths = sorted({Path(name.decode()) for name in output.split(b"\0") if name})
    errors = []
    checked = 0
    for relative in paths:
        path = ROOT / relative
        if not path.is_file():
            continue
        checked += 1
        if path.suffix in {".log", ".pyc", ".pyo"} or path.name == ".DS_Store":
            errors.append(f"Generated file: {relative}")
        if path.suffix == ".py":
            try:
                ast.parse(path.read_text(), filename=str(relative))
            except SyntaxError as error:
                errors.append(str(error))
        if path.suffix == ".sh":
            result = subprocess.run(["bash", "-n", str(path)], capture_output=True, text=True)
            if result.returncode:
                errors.append(result.stderr.strip())
        if path.suffix != ".md" or "Vendor" in path.parts:
            continue
        for target in re.findall(r"\]\(([^)]+)\)", path.read_text()):
            link = urlsplit(target.strip("<>"))
            if link.scheme or link.netloc or not link.path:
                continue
            if not (path.parent / unquote(link.path)).exists():
                errors.append(f"Broken link in {relative}: {target}")
    for error in errors:
        print(error)
    print(f"Checked {checked} files. {len(errors)} issue(s).")
    return bool(errors)


if __name__ == "__main__":
    sys.exit(main())
