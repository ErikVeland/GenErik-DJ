#!/usr/bin/env python3
"""Check the deck-load ordering that protects waveform and Play feedback."""
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[1]
model = (root / 'Replica/Sources/TDJInterface/ReplicaModel.swift').read_text()
button = (root / 'Replica/Sources/TDJInterface/VinylBrakeControl.swift').read_text()
load = model.split('func loadPreparedTrack(', 1)[1].split('func cancelDeckLoadIntent', 1)[0]
play = model.split('public func pressPlay(', 1)[1].split('public func setMixer(', 1)[0]
checks = {
    'Waveform starts before queued audio work': 'prepareWaveform(track)' in load.split('let loadTask = Task', 1)[0],
    'Full analysis does not block audio loading': 'forceFullAnalysis' not in load and 'service.analyzeNativeMusic' not in load,
    'Analysis starts after audio readiness': 'scheduleDeckAnalysis(deck: deck)' in load and load.index('preparingPlayback.remove(deck)') < load.index('scheduleDeckAnalysis(deck: deck)'),
    'Play retains a request during loading': 'pendingLoadPlay[deck]' in play.split('do {', 1)[0],
    'Play button accepts loading input': '.disabled(model.track(deck) == nil || model.preparingPlayback.contains(deck))' not in button,
}
for name, passed in checks.items():
    print(f"{'PASS' if passed else 'FAIL'}: {name}")
sys.exit(0 if all(checks.values()) else 1)
