#!/usr/bin/env python3
"""Generate reproducible musical diagnostics; these are not TDJ1 reference outputs."""

import argparse
import hashlib
import json
import math
import struct
import wave
from pathlib import Path


RATE = 22050


def expectation(status, **values):
    return {"status": status, **values}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    manifest_path = args.output / "synthetic-manifest.json"
    if manifest_path.exists():
        raise FileExistsError("Choose a fresh output directory; existing benchmark inputs are retained.")
    tracks = []

    def write(name, signal, tempo, key, downbeat, tags, annotation):
        path = args.output / (name + ".wav")
        payload = bytearray()
        for sample in signal:
            if not math.isfinite(sample) or abs(sample) >= 1:
                raise ValueError("Synthetic signal must be finite and must not clip.")
            value = round(sample * 32767)
            payload.extend(struct.pack("<hh", value, value))
        with path.open("xb") as target:
            with wave.open(target, "wb") as output:
                output.setnchannels(2)
                output.setsampwidth(2)
                output.setframerate(RATE)
                output.writeframes(payload)
        tracks.append({
            "id": name,
            "path": path.name,
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            "annotation": "Generator ground truth only. " + annotation,
            "tags": tags,
            "tempo": tempo,
            "key": key,
            "downbeat": downbeat,
        })

    def add_pulse(signal, time, frequency, amplitude, decay=180):
        start = round(time * RATE)
        for offset in range(round(0.04 * RATE)):
            index = start + offset
            if index >= len(signal):
                break
            seconds = offset / RATE
            signal[index] += amplitude * math.exp(-seconds * decay) * math.cos(2 * math.pi * frequency * seconds)

    for name, bpm, pickup, beats, offbeat, precursor in [
        ("clock-120", 120, 0, 64, False, False),
        ("fractional-127.7", 127.7, 0.25, 128, False, False),
        ("pickup-with-precursor", 120, 0.25, 64, False, True),
        ("strong-offbeats", 120, 0, 64, True, False),
    ]:
        duration = pickup + beats * 60 / bpm
        signal = [0.0] * math.ceil(duration * RATE)
        if precursor:
            add_pulse(signal, 0.04, 1300, 0.22)
        for beat in range(beats):
            time = pickup + beat * 60 / bpm
            add_pulse(signal, time, 110 if beat % 4 == 0 else 220, 0.3 if not offbeat else 0.12)
            if offbeat:
                add_pulse(signal, time + 30 / bpm, 5200, 0.35, decay=250)
        tags = ["four-on-floor"]
        if pickup:
            tags.append("pickup")
        if offbeat:
            tags.extend(["syncopated", "half-double-ambiguity"])
        if beats > 64:
            tags.append("fractional-tempo")
        write(name, signal, expectation("labelled", bpm=bpm, beatAnchorSeconds=pickup),
            expectation("absent"), expectation("labelled", barStartSeconds=pickup), tags,
            "Metrical pulses with a distinct bar accent; no stable harmonic key.")

    for name, tonic, mode, gain, cents in [
        ("c-major", 0, "major", 0.3, 0),
        ("c-major-quiet", 0, "major", 0.03, 0),
        ("c-major-detuned", 0, "major", 0.3, 28),
        ("a-minor", 9, "minor", 0.3, 0),
        ("f-sharp-major", 6, "major", 0.3, 0),
    ]:
        midi = 60 + tonic
        notes = [midi, midi + (4 if mode == "major" else 3), midi + 7]
        frequencies = [440 * 2 ** ((note - 69 + cents / 100) / 12) for note in notes]
        frames = RATE * 12
        signal = []
        for index in range(frames):
            time = index / RATE
            fade = min(1, time / 0.04, (frames - 1 - index) / RATE / 0.04)
            signal.append(gain * fade * sum(math.sin(2 * math.pi * frequency * time) for frequency in frequencies) / 3)
        write(name, signal, expectation("absent"), expectation("labelled", key={"tonic": tonic, "mode": mode}),
            expectation("absent"), ["sustained-tonal", "detuned" if cents else "concert-tuning", "mastering-variation"],
            "Steady triad with no rhythmic pulse. Gain and tuning are known from synthesis.")
    write("silence", [0.0] * (RATE * 4), expectation("absent"), expectation("absent"),
        expectation("absent"), ["silence"], "All samples are zero; no tempo, key or bar should be invented.")
    manifest = {
        "format": "tdj1.analysis-benchmark/v1",
        "corpus": "synthetic",
        "referenceBuild": None,
        "requiredTags": ["four-on-floor", "pickup", "fractional-tempo", "syncopated", "half-double-ambiguity", "detuned", "mastering-variation", "silence"],
        "limits": {
            "maximumBPMError": 0.02,
            "maximumBeatPhaseErrorMilliseconds": 10,
            "maximumGridDriftMilliseconds": 20,
            "maximumDownbeatErrorMilliseconds": 20,
            "maximumSimilarEnergyDistance": 1,
        },
        "tracks": tracks,
        "energyComparisons": [
            {"firstTrackID": "c-major", "secondTrackID": "c-major-quiet", "relation": "similar",
             "annotation": "Identical arrangement, timbre and musical activity; a 20 dB gain change should not dominate musical energy."},
            {"firstTrackID": "strong-offbeats", "secondTrackID": "c-major", "relation": "higher",
             "annotation": "Continuous strong percussion should have greater musical activity than a sustained triad."},
        ],
    }
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
    print(manifest_path)


if __name__ == "__main__":
    main()
