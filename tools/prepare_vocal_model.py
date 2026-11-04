#!/usr/bin/env python3
"""Verify the pinned offline vocal model before an iPad build."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "Replica/Sources/TDJInterface/VocalModelAssets"


def prepare(source=None):
    manifest = json.loads((ASSETS / "model.json").read_text())
    target = ASSETS / manifest["filename"]

    def valid(path):
        if not path.is_file() or path.stat().st_size != manifest["bytes"]:
            return False
        with path.open("rb") as stream:
            return hashlib.file_digest(stream, "sha256").hexdigest() == manifest["sha256"]

    if valid(target):
        return target
    temporary = target.with_suffix(".download")
    try:
        if source is not None:
            if not valid(source):
                raise ValueError("The local vocal model does not match the pinned model.")
            shutil.copyfile(source, temporary)
        else:
            print("Download the pinned offline vocal model (190 MB).", flush=True)
            with urllib.request.urlopen(manifest["source"], timeout=30) as response, temporary.open("wb") as output:
                shutil.copyfileobj(response, output)
        if not valid(temporary):
            raise ValueError("The vocal model failed its size or checksum check.")
        temporary.replace(target)
    finally:
        temporary.unlink(missing_ok=True)
    return target


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path)
    print(prepare(parser.parse_args().source))
