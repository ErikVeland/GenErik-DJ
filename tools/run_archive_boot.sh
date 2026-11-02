#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"

if pgrep -f '[p]alera1n-macos-universal' >/dev/null; then
    printf '%s\n' 'Another palera1n process is already running. Close it before retrying.' >&2
    exit 1
fi

python3 - <<'PY'
import hashlib
import json
from pathlib import Path

report = json.loads(Path('Analysis/document-acquisition.json').read_text())
if report['status'] != 'complete':
    raise SystemExit('Shared-document copy is not complete. Do not restart the iPad yet.')
for entry in report['files']:
    local = Path(report['destination']) / entry['name']
    if entry['status'] != 'copied_size_verified' or local.stat().st_size != entry['size']:
        raise SystemExit('A shared-document copy is missing or incomplete.')
tool = Path('tools/vendor/palera1n-macos-universal')
expected = 'dcf2f827e89a12215685c55f0462cd7d0cbc0551e3acd340bf0216c274c2e83e'
if hashlib.sha256(tool.read_bytes()).hexdigest() != expected:
    raise SystemExit('The palera1n tool hash does not match the acquired v2.4 binary.')
print('Shared documents copied. This is not a full device or private app-data backup.', flush=True)
print('Starting palera1n rootless. Follow its physical-button prompts.', flush=True)
PY

tools/vendor/palera1n-macos-universal -l -S 2>&1 | tee Analysis/jailbreak-live.log
