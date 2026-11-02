"""Run the silent native probe and real analysis concurrently, retaining both results."""
import json, subprocess, shutil, sys
from pathlib import Path
root=Path(__file__).resolve().parent.parent
out=root/'Validation'/sys.argv[1]
seconds=float(sys.argv[2])
if out.exists(): raise SystemExit('Evidence directory already exists')
out.mkdir()
shutil.copy2(root/'.build/debug/tdj-tool',out/'analysis-tool')
with (out/'native.log').open('w') as native_log, (out/'analysis.log').open('w') as analysis_log:
    native=subprocess.Popen(['bash','Scripts/stress-keylock-native.sh',str(out/'native.json'),str(seconds),'0','dense','performance-fx',*sys.argv[3:]],cwd=root,stdout=native_log,stderr=subprocess.STDOUT)
    analysis=subprocess.Popen([sys.executable,'Scripts/analysis-pressure.py',str(out/'analysis-tool'),str(root.parent/'Analysis/Traktor-DJ-1x/fixtures/clock-a-120.wav'),str(out/'analysis.json'),str(out/'native.json'),str(seconds+30)],cwd=root,stdout=analysis_log,stderr=subprocess.STDOUT)
    code=native.wait()
    try: analysis_code=analysis.wait(timeout=30)
    except subprocess.TimeoutExpired:
        analysis.terminate(); analysis_code=analysis.wait()
(out/'orchestration.json').write_text(json.dumps({'nativeExitCode':code,'analysisExitCode':analysis_code,'requestedSeconds':seconds,'outputBufferChangeRequested':False,'usesPhysicalIPad':False},indent=2)+'\n')
raise SystemExit(code or analysis_code)
