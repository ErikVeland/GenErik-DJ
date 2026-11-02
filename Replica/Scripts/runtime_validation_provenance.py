"""Bind a runtime validation binary to unchanged build inputs."""
import hashlib
import json
from pathlib import Path
import sys


def inputs(root):
    paths = [p for p in (root / "Sources").rglob("*") if p.is_file()]
    # The optional package preview target shares these sources outside Sources/.
    paths += [p for p in (root / "iPadValidation").rglob("*.swift") if p.is_file()]
    paths += [root / "Package.swift", root / "Scripts/build-runtime-validation.sh",
              root / "Scripts/run-runtime-validation.py", Path(__file__).resolve()]
    return {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(paths)}


if __name__ == "__main__":
    root = Path(__file__).resolve().parent.parent
    record = root / ".build/runtime-validation-inputs.json"
    if sys.argv[1] == "begin":
        record.parent.mkdir(parents=True, exist_ok=True)
        record.write_text(json.dumps(inputs(root), indent=2) + "\n")
    elif sys.argv[1] == "finish":
        before = json.loads(record.read_text())
        if before != inputs(root):
            raise SystemExit("Runtime build inputs changed during compilation. Rebuild with sources settled.")
        binary = root / ".build/release/tdj-runtime-validation"
        manifest = {"inputsSHA256": before,
                    "binarySHA256": hashlib.sha256(binary.read_bytes()).hexdigest()}
        (root / ".build/runtime-validation-build.json").write_text(json.dumps(manifest, indent=2) + "\n")
