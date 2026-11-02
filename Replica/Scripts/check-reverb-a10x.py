import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import statistics
import subprocess
import sys
import wave

import numpy as np
from scipy import signal


HEADER_PATHS = [
    "Sources/CTDJTransport/TDJReverb.h",
    "Sources/CTDJTransport/TDJEffects.h",
    "Sources/CTDJTransport/TDJDlcEffects.h",
    "Sources/CTDJTransport/TDJMixer.h",
    "Sources/CTDJTransport/include/TDJTransport.h",
    "Sources/CTDJTransport/include/TDJRecording.h",
    "Sources/CTDJTransport/include/TDJCallbackMetrics.h",
    "Sources/CTDJTransport/include/TDJStreaming.h",
]
RATE = 48000
FAILURES = []


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def compiler_command():
    if platform.system() == "Darwin" and shutil.which("xcrun"):
        return ["xcrun", "clang"]
    for name in ["clang", "gcc", "cc"]:
        if shutil.which(name):
            return [name]
    raise RuntimeError("A C compiler is required")


def run_json(command, environment=None, allow_failure=False):
    completed = subprocess.run(command, text=True, capture_output=True, env=environment, timeout=180)
    if completed.returncode:
        failure = {"command": command, "returncode": completed.returncode, "stdout": completed.stdout, "stderr": completed.stderr}
        if not allow_failure:
            raise RuntimeError(json.dumps(failure))
        FAILURES.append(failure)
        if not completed.stdout.startswith("{"):
            return {"failed": True, "returncode": completed.returncode, "stderr": completed.stderr}
    return json.loads(completed.stdout)


def compile_probe(compiler, source, inputs, output, audit=False, sanitizers=False, features=()):
    command = compiler + ["-std=c11", "-D_DEFAULT_SOURCE", "-O1" if sanitizers else "-O3"]
    if audit:
        command.append("-DAUDIT_OPERATIONS")
    command.extend("-D" + feature for feature in features)
    if sanitizers:
        command += ["-fsanitize=address,undefined", "-fno-omit-frame-pointer"]
    command += ["-I", str(inputs), str(source), "-lm", "-o", str(output)]
    compiled = subprocess.run(command, text=True, capture_output=True, timeout=120)
    if compiled.returncode:
        error_path = output.with_name(output.name + "-compile-error.json")
        error_path.write_text(json.dumps({"command": command, "returncode": compiled.returncode, "stdout": compiled.stdout, "stderr": compiled.stderr}, indent=4) + "\n")
        print(compiled.stderr, file=sys.stderr)
        raise RuntimeError("Native compilation failed; diagnostic saved to " + str(error_path))
    return command


def read_audio(path):
    audio = np.fromfile(path, dtype=np.float32).reshape(-1, 2).astype(np.float64)
    if not np.isfinite(audio).all():
        raise RuntimeError("Nonfinite rendered audio: " + str(path))
    return audio


def decay_measure(audio):
    energy = np.sum(audio * audio, axis=1)
    total = float(energy.sum())
    if total <= 1e-30:
        return {"energy": total, "rt60_from_t20_seconds": None}
    integrated = np.cumsum(energy[::-1])[::-1]
    level = 10 * np.log10(np.maximum(integrated / total, 1e-300))
    times = np.arange(len(audio)) / RATE
    fit = (level <= -5) & (level >= -25)
    if fit.sum() < 32:
        return {"energy": total, "rt60_from_t20_seconds": None}
    slope, intercept = np.polyfit(times[fit], level[fit], 1)
    residual = level[fit] - (times[fit] * slope + intercept)
    return {
        "energy": total,
        "rt60_from_t20_seconds": float(-60 / slope) if slope < 0 else None,
        "fit_residual_rms_db": float(np.sqrt(np.mean(residual * residual))),
        "fit_start_seconds": float(times[fit][0]),
        "fit_end_seconds": float(times[fit][-1]),
        "last_second_energy_fraction": float(energy[-RATE:].sum() / total),
    }


def echo_density(audio):
    result = []
    window = 1920
    step = 240
    gaussian_exceedance = 0.31731050786291415
    for start in range(0, min(len(audio) - window, RATE), step):
        segment = audio[start:start + window]
        centred = segment - segment.mean(axis=0)
        deviation = np.sqrt(np.mean(centred * centred, axis=0))
        valid = deviation > 1e-12
        if not valid.any():
            value = None
        else:
            value = float(np.mean(np.mean(np.abs(centred[:, valid]) > deviation[valid], axis=0)) / gaussian_exceedance)
        result.append({"centre_seconds": (start + window * 0.5) / RATE, "normalised_density": value})
    first = None
    for index in range(len(result) - 2):
        values = [item["normalised_density"] for item in result[index:index + 3]]
        if all(value is not None and value >= 0.9 for value in values):
            first = result[index]["centre_seconds"]
            break
    sampled = []
    for target in [0.025, 0.05, 0.1, 0.2, 0.4, 0.75]:
        sampled.append(min(result, key=lambda item: abs(item["centre_seconds"] - target)))
    intervals = {}
    for low, high in [(0.02, 0.05), (0.05, 0.10), (0.10, 0.15)]:
        segment = audio[round(low * RATE):round(high * RATE)]
        centred = segment - segment.mean(axis=0)
        deviation = np.sqrt(np.mean(centred * centred, axis=0))
        valid = deviation > 1e-12
        intervals[f"{low * 1000:.0f}_{high * 1000:.0f}_ms"] = float(np.mean(np.abs(centred[:, valid]) > deviation[valid]) / gaussian_exceedance) if valid.any() else None
    return {"first_three_windows_at_least_0_9_seconds": first, "sampled_windows": sampled, "fixed_interval_density": intervals}


def impulse_metrics(path):
    audio = read_audio(path)
    tail = audio[RATE // 2:RATE]
    energy = np.sum(tail * tail, axis=0)
    correlation = float(np.sum(tail[:, 0] * tail[:, 1]) / np.sqrt(max(float(energy.prod()), 1e-300)))
    mono = float(np.sum(np.mean(tail, axis=1) ** 2) / max(float(energy.sum()) * 0.5, 1e-300))
    bands = {}
    for name, bounds in {"bass_80_250_hz": (80, 250), "mid_500_2000_hz": (500, 2000), "high_4000_10000_hz": (4000, 10000)}.items():
        coefficients = signal.butter(3, bounds, btype="bandpass", fs=RATE, output="sos")
        bands[name] = decay_measure(signal.sosfilt(coefficients, audio, axis=0))
    frequencies, spectrum = signal.welch(audio[RATE // 2:RATE * 2], fs=RATE, nperseg=2048, axis=0)
    selected = np.mean(spectrum[(frequencies >= 250) & (frequencies <= 4000)], axis=1)
    selected = np.maximum(selected, 1e-300)
    flatness = float(np.exp(np.mean(np.log(selected))) / np.mean(selected))
    return {
        "peak": float(np.max(np.abs(audio))),
        "broadband_decay": decay_measure(audio),
        "band_decays": bands,
        "late_stereo_correlation": correlation,
        "late_mono_energy_ratio": mono,
        "late_nonzero_fraction_above_1e_8": float(np.mean(np.abs(tail) > 1e-8)),
        "early_echo_density": echo_density(audio),
        "late_spectral_flatness_250_4000_hz": flatness,
        "late_peak_over_median_bin_db": float(10 * np.log10(np.max(selected) / np.median(selected))),
    }


def write_wav(path, audio):
    if not np.isfinite(audio).all() or np.max(np.abs(audio)) > 1:
        raise RuntimeError("Invalid WAV output: " + str(path))
    integers = np.rint(audio.reshape(-1) * 8388607).astype(np.int32)
    packed = np.column_stack((integers & 255, (integers >> 8) & 255, (integers >> 16) & 255)).astype(np.uint8)
    with wave.open(str(path), "wb") as output:
        output.setnchannels(2)
        output.setsampwidth(3)
        output.setframerate(RATE)
        output.writeframes(packed.tobytes())


def audition_files(output, variants):
    destination = output / "audition"
    destination.mkdir()
    evidence = {}
    for name in ["percussion", "chords", "mix"]:
        dry = read_audio(variants["candidate"]["directory"] / (name + "-dry.f32"))
        after = read_audio(variants["candidate"]["directory"] / (name + ".f32"))
        before = read_audio(variants["baseline"]["directory"] / (name + ".f32")) if "baseline" in variants else after
        before_return = before - dry
        after_return = after - dry
        before_energy = float(np.sum(before_return * before_return))
        after_energy = float(np.sum(after_return * after_return))
        gain = np.sqrt(before_energy / max(after_energy, 1e-300))
        matched = dry + after_return * gain
        shared_scale = min(1.0, 0.95 / max(float(np.max(np.abs(before))), float(np.max(np.abs(after))), float(np.max(np.abs(matched))), float(np.max(np.abs(dry))), 1e-9))
        title = name.title()
        versions = [("Dry", dry), ("Candidate-App", after), ("Candidate-Matched", matched)]
        if "baseline" in variants:
            versions.insert(1, ("Baseline", before))
        full_versions = []
        for variant in variants:
            full_path = variants[variant]["directory"] / "full-wet" / (name + ".f32")
            if full_path.exists():
                full_versions.append(("Baseline-FullWet" if variant == "baseline" else "Candidate-App-FullWet", read_audio(full_path)))
        full_scale = min(1.0, 0.95 / max([float(np.max(np.abs(audio))) for _, audio in full_versions] + [1e-9]))
        for version, audio in versions:
            write_wav(destination / ("Reverb-" + title + "-" + version + ".wav"), audio * shared_scale)
        for version, audio in full_versions:
            write_wav(destination / ("Reverb-" + title + "-" + version + ".wav"), audio * full_scale)
        evidence[name] = {
            "wet_return_energy_match_candidate_gain": float(gain),
            "shared_output_gain_y_0_65_versions": shared_scale,
            "shared_output_gain_y_1_versions": full_scale if full_versions else None,
            "parameters": {"x": 0.72, "y_standard": 0.65, "y_full_wet": 1},
            "baseline_original_peak": float(np.max(np.abs(before))),
            "candidate_original_peak": float(np.max(np.abs(after))),
            "matching_method": "Candidate wet-return energy is matched to baseline over the complete eight-second synthetic excerpt; identical dry signal is retained. This is RMS/energy matching, not a perceptual loudness certification." if "baseline" in variants else "Candidate and dry versions share one output gain. No baseline or level-match comparison was requested.",
            "wav_sha256": {version: sha256(destination / ("Reverb-" + title + "-" + version + ".wav")) for version, _ in versions + full_versions},
        }
    return evidence


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--baseline-root", "--baseline", dest="baseline", type=Path)
    parser.add_argument("--source-root", "--candidate", dest="candidate", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--candidate-header", type=Path)
    parser.add_argument("--candidate-effects", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--repetitions", type=int, default=5)
    parser.add_argument("--skip-sanitizers", action="store_true")
    parser.add_argument("--skip-audio", action="store_true")
    parser.add_argument("--disable-leak-detection", action="store_true", help="Keep AddressSanitizer/UBSan enabled but disable LeakSanitizer when the host cannot support it; Darwin always disables leak detection.")
    parser.add_argument("--blocks", nargs="+", type=int, default=[16, 128])
    args = parser.parse_args()
    if args.repetitions < 1 or args.repetitions > 15:
        parser.error("repetitions must be between 1 and 15")
    if any(block < 16 or block > 512 for block in args.blocks):
        parser.error("blocks must be between 16 and 512")
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    probe = Path(__file__).with_name("reverb-a10x-probe.c")
    compiler = compiler_command()
    variants = {}
    commands = []
    sources = [("candidate", args.candidate)]
    if args.baseline:
        sources.insert(0, ("baseline", args.baseline))
    for name, source in sources:
        directory = output / name
        inputs = directory / "inputs"
        inputs.mkdir(parents=True)
        hashes = {}
        for relative in HEADER_PATHS:
            original = source / relative
            if name == "candidate" and relative.endswith("/TDJReverb.h") and args.candidate_header:
                original = args.candidate_header
            if name == "candidate" and relative.endswith("/TDJEffects.h") and args.candidate_effects:
                original = args.candidate_effects
            copied = inputs / original.name
            shutil.copy2(original, copied)
            hashes[relative] = sha256(copied)
        copied_probe = inputs / probe.name
        shutil.copy2(probe, copied_probe)
        hashes["probe"] = sha256(copied_probe)
        plain = directory / "probe"
        audited = directory / "probe-audited"
        features = []
        if "REVERB_INJECTION_GAIN" in (inputs / "TDJReverb.h").read_text():
            features.append("A10X_REVERB_INVARIANTS")
        if "reverb_tail_active" in (inputs / "TDJEffects.h").read_text():
            features.append("A10X_RELEASE_CONTRACT")
        commands.append(compile_probe(compiler, copied_probe, inputs, plain, features=features))
        commands.append(compile_probe(compiler, copied_probe, inputs, audited, audit=True, features=features))
        safety = run_json([str(audited), "safety"], allow_failure=True)
        long_decay = run_json([str(audited), "long-decay"], allow_failure=True)
        constructors = run_json([str(audited), "constructors"], allow_failure=True) if "A10X_REVERB_INVARIANTS" in features else None
        release = run_json([str(audited), "release"], allow_failure=True) if "A10X_RELEASE_CONTRACT" in features else None
        sanitizers = None
        if not args.skip_sanitizers:
            sanitized = directory / "probe-sanitized"
            commands.append(compile_probe(compiler, copied_probe, inputs, sanitized, audit=True, sanitizers=True, features=features))
            environment = os.environ.copy()
            leak_detection = platform.system() != "Darwin" and not args.disable_leak_detection
            environment["ASAN_OPTIONS"] = f"detect_leaks={int(leak_detection)}:quarantine_size_mb=16"
            environment["UBSAN_OPTIONS"] = "halt_on_error=1:print_stacktrace=1"
            sanitizers = {"asan_leak_detection_enabled": leak_detection, "safety": run_json([str(sanitized), "safety"], environment, allow_failure=True), "long_decay": run_json([str(sanitized), "long-decay"], environment, allow_failure=True)}
            if "A10X_RELEASE_CONTRACT" in features:
                sanitizers["release"] = run_json([str(sanitized), "release"], environment, allow_failure=True)
            if "A10X_REVERB_INVARIANTS" in features:
                sanitizers["constructors"] = run_json([str(sanitized), "constructors"], environment, allow_failure=True)
        impulses = {}
        if not args.skip_audio:
            run_json([str(plain), "render", str(directory)])
            (directory / "full-wet").mkdir()
            run_json([str(plain), "render-full", str(directory / "full-wet")])
            for impulse in ["room-short", "room-medium", "room-long", "ice-medium"]:
                impulses[impulse] = impulse_metrics(directory / (impulse + ".f32"))
        variants[name] = {"directory": directory, "plain": plain, "input_sha256": hashes, "features_checked": features, "safety": safety, "long_decay": long_decay, "release": release, "constructors": constructors, "sanitizers": sanitizers, "impulses": impulses}
        print(json.dumps({"stage": "validated", "variant": name, "safety": safety, "release": release}), flush=True)
    measurements = []
    for trial in range(args.repetitions):
        for layout in range(3):
            for mode in range(3):
                order = list(variants)
                if (trial + layout + mode) % 2:
                    order.reverse()
                for block in args.blocks:
                    for name in order:
                        row = run_json([str(variants[name]["plain"]), "bench", str(layout), str(mode), str(block)])
                        row.update({"variant": name, "trial": trial})
                        measurements.append(row)
    summaries = []
    for layout in range(3):
        for mode in range(3):
            for block in args.blocks:
                row = {"layout": ["six_reverbs", "six_iceverbs", "alternating_reverb_iceverb"][layout], "mode": ["settled", "continuous_parameter_ramps", "parameter_type_and_bypass_churn"][mode], "block_frames": block}
                for name in variants:
                    selected = [item for item in measurements if item["variant"] == name and item["layout"] == layout and item["mode"] == mode and item["block_frames"] == block]
                    row[name] = {
                        "median_wall_seconds": statistics.median(item["wall_seconds"] for item in selected),
                        "median_p50_microseconds": statistics.median(item["p50_microseconds"] for item in selected),
                        "median_p99_microseconds": statistics.median(item["p99_microseconds"] for item in selected),
                        "largest_observed_block_microseconds": max(item["max_microseconds"] for item in selected),
                    }
                if "baseline" in variants:
                    row["candidate_to_baseline_median_p50_ratio"] = row["candidate"]["median_p50_microseconds"] / row["baseline"]["median_p50_microseconds"]
                    row["candidate_to_baseline_median_wall_ratio"] = row["candidate"]["median_wall_seconds"] / row["baseline"]["median_wall_seconds"]
                summaries.append(row)
    audition = audition_files(output, variants) if not args.skip_audio else None
    report = {
        "scope": "Offline native DSP, isolated real effect wrappers and synthetic material. No Core Audio, device, entire transport, GUI, real music, or subjective quality certification.",
        "host": platform.platform(),
        "compiler": subprocess.run(compiler + ["--version"], capture_output=True, text=True, check=True).stdout.splitlines()[0],
        "commands": commands,
        "functional_checks_passed": not FAILURES,
        "failures": FAILURES,
        "instrumentation_scope": "Direct malloc/calloc/realloc/free and memset calls in included effect headers; expensive elementary functions count only while processing. This is not a whole-process or Apple runtime allocator trace.",
        "variants": {name: {key: value for key, value in record.items() if key not in ["directory", "plain"]} for name, record in variants.items()},
        "timing_summary": summaries,
        "timing_trials": measurements,
        "audition": audition,
        "limitations": [
            "No elapsed-time or aesthetic threshold has been invented to certify the A10X.",
            "Source-level mathematical invariants, sanitizers, actual-device output and manual listening remain distinct evidence.",
            "Band T20 extrapolations, spectral flatness and Gaussian exceedance echo density are diagnostics, not perceptual preference scores.",
            "Benchmark maxima include ordinary host scheduler interruptions; retain every observation and compare actual Apple workloads before promotion.",
        ],
    }
    (output / "result.json").write_text(json.dumps(report, indent=4) + "\n")
    print(json.dumps({"result": str(output / "result.json"), "functional_checks_passed": not FAILURES, "timing_summary": summaries}), flush=True)
    return 1 if FAILURES else 0


if __name__ == "__main__":
    sys.exit(main())
