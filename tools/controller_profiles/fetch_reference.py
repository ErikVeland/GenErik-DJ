#!/usr/bin/env python3
"""Cache pinned public protocol references without executing upstream scripts."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import re
from urllib.parse import quote
from urllib.request import Request, urlopen


def git_blob_hash(data):
    return hashlib.sha1(f"blob {len(data)}\0".encode() + data).hexdigest()


def fetch(tree, revision, cache, read_url):
    if not re.fullmatch(r"[0-9a-f]{40}", revision) or tree.get("truncated"):
        raise ValueError("Use a full revision and a complete Git tree.")
    root = Path(cache).resolve()
    selected = [entry for entry in tree["tree"] if entry["type"] == "blob" and (
        entry["path"] == "LICENSE" or (entry["path"].startswith("res/controllers/")
        and entry["path"].endswith((".xml", ".js"))))]

    def download(entry):
        name = entry["path"]
        path = (root / name).resolve()
        if not path.is_relative_to(root):
            raise ValueError("The reference path leaves the cache.")
        url = f"https://raw.githubusercontent.com/mixxxdj/mixxx/{revision}/{quote(name)}"
        data = path.read_bytes() if path.is_file() else read_url(url)
        if git_blob_hash(data) != entry["sha"]:
            raise ValueError(f"The pinned reference hash does not match: {name}")
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        return {"path": name, "url": url, "git_blob": entry["sha"],
                "sha256": hashlib.sha256(data).hexdigest(), "bytes": len(data)}

    with ThreadPoolExecutor(max_workers=6) as pool:
        records = list(pool.map(download, selected))
    manifest = {"repository": "mixxxdj/mixxx", "revision": revision,
                "files": sorted(records, key=lambda record: record["path"])}
    (root / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("cache", type=Path)
    parser.add_argument("--lock", type=Path, default=Path(__file__).with_name("sources.lock.json"))
    args = parser.parse_args()

    def read_url(url):
        request = Request(url, headers={"User-Agent": "GenErik-DJ-controller-catalogue"})
        with urlopen(request, timeout=45) as response:
            return response.read()

    locked = json.loads(args.lock.read_text())["mixxx"]
    tree = {"tree": [{"type": "blob", "path": item["path"], "sha": item["git_blob"]} for item in locked["files"]]}
    result = fetch(tree, locked["revision"], args.cache, read_url)
    if result != locked:
        raise ValueError("The source cache differs from the reviewed lock file.")
    print(f"Cached and verified {len(result['files'])} references at {result['revision']}.")


if __name__ == "__main__":
    main()
