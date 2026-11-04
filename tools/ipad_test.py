#!/usr/bin/env python3
"""Build once, install the saved iPad app, then leave testing to Erik."""
import argparse
from datetime import datetime, timezone
import fcntl
import hashlib
import json
from pathlib import Path
import plistlib
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
LOCAL = ROOT / "TestBuilds/ipad"
RECORDS = ROOT / "docs/testing/builds"
CACHE = ROOT / ".build-ipad"
BUNDLE = "org.generikdj.replica.audiocheck"


def run(args, **kwargs):
    return subprocess.run(args, cwd=ROOT, check=True, **kwargs)


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(".tmp")
    temporary.write_text(json.dumps(value, indent=2) + "\n")
    temporary.replace(path)


def digest(paths, base):
    result = hashlib.sha256()
    for path in sorted(paths):
        if path.is_file() and not any(p in {"xcuserdata", "project.xcworkspace"} for p in path.parts) and path.name != ".DS_Store":
            result.update(path.relative_to(base).as_posix().encode() + b"\0")
            result.update(hashlib.sha256(path.read_bytes()).digest())
    return result.hexdigest()


def source_identity():
    paths = [ROOT / "Replica/Package.swift", ROOT / "Replica/THIRD_PARTY_NOTICES.txt"]
    for folder in ["Replica/Sources", "Replica/iPad"]:
        paths.extend((ROOT / folder).rglob("*"))
    return digest(paths, ROOT)


def info(app):
    with (app / "Info.plist").open("rb") as stream:
        value = plistlib.load(stream)
    if value["CFBundleIdentifier"] != BUNDLE:
        raise ValueError("This is not the expected GenErik DJ app. Installation stopped.")
    return value


def archive(app, record):
    number = int(info(app)["CFBundleVersion"])
    target = LOCAL / str(number) / "GenErikDJ.app"
    if target.parent.exists() or (RECORDS / f"{number}.json").exists():
        raise ValueError(f"Build {number} already exists. Do not overwrite it.")
    target.parent.mkdir(parents=True)
    run(["ditto", str(app), str(target)])
    record.update(build=number, app=str(target.relative_to(ROOT)),
                  appSHA256=digest(target.rglob("*"), target), state="ready",
                  createdUTC=datetime.now(timezone.utc).isoformat())
    write(RECORDS / f"{number}.json", record)


def build(config, notes):
    from prepare_vocal_model import prepare
    from check_ipad_runtime import verify_embedded_frameworks
    prepare()
    app = CACHE / "Build/Products/Release-iphoneos/GenErikDJ.app"
    last = int(info(app)["CFBundleVersion"]) if app.exists() else 44
    if app.exists() and not (RECORDS / f"{last}.json").exists() and not (LOCAL / str(last)).exists():
        archive(app, {"notes": "Previous local build retained. Source identity unverified.", "sourceCommit": None})
    numbers = [int(p.stem) for p in RECORDS.glob("*.json") if p.stem.isdigit()]
    numbers += [int(p.name) for p in LOCAL.iterdir() if p.is_dir() and p.name.isdigit()]
    number = max([last, 44, *numbers]) + 1
    before = source_identity()
    commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    dirty = subprocess.check_output(["git", "status", "--porcelain", "--", "Replica/Sources", "Replica/iPad", "Replica/Package.swift"], cwd=ROOT, text=True).strip()
    log = LOCAL / f"build-{number}.log"
    started = time.monotonic()
    print(f"Building iPad test {number}…", flush=True)
    with log.open("w") as output:
        try:
            run(["xcodebuild", "-quiet", "-project", "Replica/iPad/GenErikDJ.xcodeproj",
                 "-scheme", "GenErikDJ", "-configuration", "Release",
                 "-destination", "generic/platform=iOS", "-derivedDataPath", str(CACHE),
                 "-jobs", "2", f"PRODUCT_BUNDLE_IDENTIFIER={BUNDLE}",
                 f"CURRENT_PROJECT_VERSION={number}", f"DEVELOPMENT_TEAM={config['team']}",
                 "CODE_SIGN_STYLE=Automatic", "INFOPLIST_KEY_CFBundleDisplayName=GenErik DJ",
                 "TARGETED_DEVICE_FAMILY=1,2", "build"], stdout=output, stderr=subprocess.STDOUT)
        except subprocess.CalledProcessError:
            print(f"Build failed. See {log}", flush=True)
            raise
    if before != source_identity() or int(info(app)["CFBundleVersion"]) != number:
        raise ValueError("Source or build identity changed. Installation stopped.")
    frameworks = verify_embedded_frameworks(app)
    print(f"Runtime search paths resolve {frameworks} embedded framework(s).", flush=True)
    run(["codesign", "--verify", "--deep", "--strict", str(app)])
    archive(app, {"notes": notes, "sourceCommit": commit, "sourceSHA256": before,
                  "uncommittedAppChanges": dirty, "buildSeconds": round(time.monotonic() - started, 2),
                  "checks": "Runtime framework paths and signing passed. Erik performs acceptance testing.",
                  "feedback": [], "log": str(log.relative_to(ROOT))})
    print(f"Build {number} ready.", flush=True)
    return number


def deploy(config, number):
    from check_ipad_runtime import verify_embedded_frameworks
    path = RECORDS / f"{number}.json"
    record = json.loads(path.read_text())
    app = ROOT / record["app"]
    if int(info(app)["CFBundleVersion"]) != number or digest(app.rglob("*"), app) != record["appSHA256"]:
        raise ValueError("The saved app changed. Installation stopped.")
    verify_embedded_frameworks(app)
    run(["codesign", "--verify", "--deep", "--strict", str(app)])
    install_timeout = config.get("install_timeout", 20)
    run(["xcrun", "devicectl", "--timeout", str(install_timeout), "device", "install", "app",
         "--device", config["device"], str(app)], timeout=install_timeout + 5)
    record.update(state="installed", installedUTC=datetime.now(timezone.utc).isoformat())
    write(path, record)
    run(["xcrun", "devicectl", "--timeout", "10", "device", "process", "launch", "--device", config["device"],
         "--terminate-existing", BUNDLE], timeout=15)
    record.update(state="testing", launchedUTC=datetime.now(timezone.utc).isoformat(),
                  launchVerification="iPadOS accepted the launch request. Erik checks continued operation.")
    write(path, record)
    print(f"Build {number} installed. iPadOS accepted the launch request. Over to Erik. No further device actions.", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["run", "build", "deploy"])
    parser.add_argument("--notes", default="Incremental iPad test build")
    parser.add_argument("--number", type=int, help="Saved build to install, including rollback")
    parser.add_argument("--device", help="Override the saved test iPad device ID")
    parser.add_argument("--team", help="Override the saved signing team")
    parser.add_argument("--install-timeout", type=int, default=20, help="Installation limit in seconds")
    args = parser.parse_args()
    if args.install_timeout < 1:
        parser.error("The installation limit must be at least one second.")
    if args.action == "deploy" and args.number is None:
        parser.error("deploy requires --number")
    LOCAL.mkdir(parents=True, exist_ok=True)
    with (LOCAL / "cycle.lock").open("w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            parser.error("An iPad build or installation is already running.")
        config_path = LOCAL / "config.json"
        config = json.loads(config_path.read_text()) if config_path.exists() else {}
        config["install_timeout"] = args.install_timeout
        for key in ["device", "team"]:
            if getattr(args, key):
                config[key] = getattr(args, key)
        required = (["team"] if args.action != "deploy" else []) + (["device"] if args.action != "build" else [])
        if any(not config.get(key) for key in required):
            parser.error("Supply the signing team/device, or save TestBuilds/ipad/config.json.")
        number = build(config, args.notes) if args.action != "deploy" else args.number
        if args.action != "build":
            deploy(config, number)


if __name__ == "__main__":
    try:
        main()
    except subprocess.TimeoutExpired:
        print("The iPad connection timed out. The saved build is ready. Reconnect and unlock the iPad, then retry deployment without rebuilding.", file=sys.stderr)
        sys.exit(1)
    except (subprocess.CalledProcessError, ValueError, FileNotFoundError) as error:
        print(f"Stopped: {error}", file=sys.stderr)
        sys.exit(1)
