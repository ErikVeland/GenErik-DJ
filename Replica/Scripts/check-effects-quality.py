import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import wave

import numpy as np


def impulse_metrics(path):
    audio = np.fromfile(path, dtype=np.float32).reshape(-1, 2).astype(np.float64)
    if not np.isfinite(audio).all():
        raise RuntimeError(f"Invalid impulse response: {path}")
    energy = np.sum(audio * audio, axis=1)
    decay = np.cumsum(energy[::-1])[::-1]
    decay_db = 10 * np.log10(np.maximum(decay / max(decay[0], 1e-300), 1e-300))
    fit = (decay_db >= -35) & (decay_db <= -5)
    times = np.arange(len(audio)) / 48000
    slope = np.polyfit(times[fit], decay_db[fit], 1)[0]
    tail = audio[12000:48000]
    stereo_energy = np.sum(tail * tail)
    mono_energy = np.sum(np.mean(tail, axis=1) ** 2)
    return {
        "peak": float(np.max(np.abs(audio))),
        "tailDensityAboveMinus140dB": float(np.mean(np.abs(tail) > 1e-7)),
        "tailCorrelation": float(np.corrcoef(tail.T)[0, 1]),
        "monoEnergyRatio": float(mono_energy / max(stereo_energy * 0.5, 1e-300)),
        "estimatedBroadbandRT60Seconds": float(-60 / slope),
        "energy": float(np.sum(energy)),
    }


def write_wav(source, destination):
    audio = np.fromfile(source, dtype=np.float32)
    if not np.isfinite(audio).all() or np.max(np.abs(audio)) > 1:
        raise RuntimeError(f"Unusable listening sample: {source}")
    integers = np.rint(audio * 8388607).astype(np.int32)
    packed = np.column_stack((integers & 255, (integers >> 8) & 255, (integers >> 16) & 255)).astype(np.uint8)
    with wave.open(str(destination), "wb") as output:
        output.setnchannels(2)
        output.setsampwidth(3)
        output.setframerate(48000)
        output.writeframes(packed.tobytes())


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path)
    parser.add_argument("--compare", type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    inputs = output / "inputs"
    inputs.mkdir()
    sources = [
        root / "Scripts/effects-quality-probe.c",
        root / "Sources/CTDJTransport/TDJMixer.h",
        root / "Sources/CTDJTransport/TDJEffects.h",
        root / "Sources/CTDJTransport/TDJDlcEffects.h",
        root / "Sources/CTDJTransport/TDJReverb.h",
        root / "Sources/CTDJTransport/include/TDJTransport.h",
        root / "Sources/CTDJTransport/include/TDJRecording.h",
        root / "Sources/CTDJTransport/include/TDJCallbackMetrics.h",
        root / "Sources/CTDJTransport/include/TDJStreaming.h",
    ]
    hashes = {}
    for source in sources:
        destination = inputs / source.name
        shutil.copy2(source, destination)
        hashes[str(source.relative_to(root))] = hashlib.sha256(destination.read_bytes()).hexdigest()
    (output / "sources.json").write_text(json.dumps(hashes, indent=2) + "\n")
    command = ["xcrun", "clang", "-O3", "-std=c11", "-I", str(inputs), str(inputs / "effects-quality-probe.c"), "-o", str(output / "probe")]
    subprocess.run(command, check=True)
    process = subprocess.run([str(output / "probe"), str(output)], text=True, capture_output=True, check=True)
    native = json.loads(process.stdout)
    responses = {}
    passed = (
        native["invalidSamples"] == 0
        and native["resetFailures"] == 0
        and native["zeroWetError"] == 0
        and native["linearityError"] < 1e-6
        and native["rapidSweepPeak"] < 1
        and native["sixReverbsPeak"] < 1
    )
    for effect in [1, 8]:
        for size in range(3):
            name = f"impulse-{effect}-{size}"
            metrics = impulse_metrics(output / f"{name}.f32")
            responses[name] = metrics
            passed = passed and metrics["peak"] < 1 and metrics["estimatedBroadbandRT60Seconds"] > 0
            if size > 0:
                passed = passed and metrics["tailDensityAboveMinus140dB"] > 0.99
                passed = passed and abs(metrics["tailCorrelation"]) < 0.6 and metrics["monoEnergyRatio"] > 0.2
        passed = passed and responses[f"impulse-{effect}-2"]["estimatedBroadbandRT60Seconds"] > 4 * responses[f"impulse-{effect}-0"]["estimatedBroadbandRT60Seconds"]
    write_wav(output / "demo-dry.f32", output / "FX-Dry.wav")
    write_wav(output / "demo-reverb.f32", output / "FX-Reverb-After.wav")
    comparison = None
    if args.compare:
        comparison = {
            f"impulse-{effect}-{size}": impulse_metrics(args.compare / f"impulse-{effect}-{size}.f32")
            for effect in [1, 8]
            for size in range(3)
        }
        write_wav(args.compare / "demo-reverb.f32", output / "FX-Reverb-Before.wav")
    report = {
        "passed": bool(passed),
        "scope": "Offline DSP at 8/44.1/48/96 kHz; impulse measurements at 48 kHz; deterministic synthetic music; not a listening verdict or target-device certification.",
        "native": native,
        "impulseResponses": responses,
        "before": comparison,
    }
    (output / "result.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))
    if not passed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
