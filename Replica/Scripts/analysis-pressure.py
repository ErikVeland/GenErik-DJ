"""Repeated real analysis of a test fixture while a render probe is running."""
import json, os, subprocess, sys, time
from pathlib import Path
binary, source, result, stop_result = map(Path, sys.argv[1:5])
duration=float(sys.argv[5])
started=time.monotonic()
records=[]
os.nice(10)
while time.monotonic()-started<duration and not stop_result.exists():
    begin=time.monotonic()
    run=subprocess.run([str(binary.resolve()),'analyze',str(source.resolve())],stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
    records.append({'startSeconds':begin-started,'durationSeconds':time.monotonic()-begin,'exitCode':run.returncode,'error':run.stderr.decode(errors='replace')[:500]})
    if run.returncode: break
result.write_text(json.dumps({'scope':'actual AudioAnalyzer in a separate low-priority process; not an in-app UI check','wallSeconds':time.monotonic()-started,'source':str(source),'runs':records},indent=2)+'\n')
