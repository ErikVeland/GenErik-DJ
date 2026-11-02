#!/usr/bin/env python3
"""Create deterministic diagnostic audio for later reference-app measurements."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import struct
import wave
from pathlib import Path

SAMPLE_RATE = 44_100
AMPLITUDE = 0.30


def write_wav(path: Path, samples: list[tuple[float, float]]) -> dict:
    """Write a new stereo PCM file and return its measured file properties."""
    peak = max(max(abs(left), abs(right)) for left, right in samples)
    if peak >= 1:
        raise ValueError("Diagnostic signal would clip")
    payload = bytearray()
    for left, right in samples:
        payload.extend(struct.pack("<hh", round(left * 32767), round(right * 32767)))
    with path.open("xb") as target:
        with wave.open(target, "wb") as output:
            output.setnchannels(2)
            output.setsampwidth(2)
            output.setframerate(SAMPLE_RATE)
            output.writeframes(payload)
    return {
        "file": path.name,
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        "sample_rate": SAMPLE_RATE,
        "channels": 2,
        "bits_per_sample": 16,
        "frames": len(samples),
        "duration_seconds": len(samples) / SAMPLE_RATE,
        "peak_before_quantisation": peak,
    }


def clock_track(path: Path, bpm: int, frequency: int, pickup: float = 0) -> dict:
    beats = 32
    origin = round(pickup * SAMPLE_RATE)
    frames = origin + round(beats * 60 / bpm * SAMPLE_RATE)
    signal = [0.0] * frames
    beat_frames = [origin + round(beat * 60 / bpm * SAMPLE_RATE) for beat in range(beats)]
    pulse_frames = round(0.018 * SAMPLE_RATE)
    for beat, start in enumerate(beat_frames):
        pitch = frequency * (2 if beat % 4 == 0 else 1)
        for offset in range(pulse_frames):
            frame = start + offset
            if frame >= frames:
                break
            time = offset / SAMPLE_RATE
            signal[frame] += AMPLITUDE * math.exp(-time * 250) * math.cos(2 * math.pi * pitch * time)
    result = write_wav(path, [(value, value) for value in signal])
    result.update({
        "kind": "beat_clock",
        "bpm": bpm,
        "beats_per_bar": 4,
        "bars": beats // 4,
        "grid_origin_frame": origin,
        "intended_beat_frames": beat_frames,
        "ordinary_beat_frequency_hz": frequency,
        "bar_start_frequency_hz": frequency * 2,
        "note": "Pulse starts at each listed frame. Rounding is to the nearest output sample.",
    })
    return result


def tone_track(path: Path, left_hz: int, right_hz: int) -> dict:
    frames = SAMPLE_RATE * 8
    fade = round(SAMPLE_RATE * 0.01)
    samples = []
    for frame in range(frames):
        envelope = min(1, frame / fade, (frames - 1 - frame) / fade)
        time = frame / SAMPLE_RATE
        samples.append((
            AMPLITUDE * envelope * math.sin(2 * math.pi * left_hz * time),
            AMPLITUDE * envelope * math.sin(2 * math.pi * right_hz * time),
        ))
    result = write_wav(path, samples)
    result.update({
        "kind": "tone",
        "left_frequency_hz": left_hz,
        "right_frequency_hz": right_hz,
        "fade_seconds": 0.01,
        "note": "No natural beatgrid. Set any test grid manually and record that choice.",
    })
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    names = [
        "clock-a-120.wav", "clock-b-120.wav", "clock-b-128.wav",
        "clock-b-120-pickup.wav", "tone-stereo-440.wav", "routing-left440-right880.wav",
        "manifest.json",
    ]
    existing = [name for name in names if (args.output / name).exists()]
    if existing:
        raise FileExistsError(f"Choose a fresh output directory. Existing files: {existing}")
    files = [
        clock_track(args.output / names[0], 120, 880),
        clock_track(args.output / names[1], 120, 660),
        clock_track(args.output / names[2], 128, 660),
        clock_track(args.output / names[3], 120, 660, pickup=0.25),
        tone_track(args.output / names[4], 440, 440),
        tone_track(args.output / names[5], 440, 880),
    ]
    manifest = {
        "purpose": "Synthetic inputs for later Traktor DJ reference tests. No device has been modified.",
        "generator": "tools/make_reference_audio.py",
        "format": "Stereo 44100 Hz signed 16-bit PCM WAV",
        "files": files,
    }
    (args.output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"Created {len(files)} diagnostic WAV files in {args.output}")


if __name__ == "__main__":
    main()
