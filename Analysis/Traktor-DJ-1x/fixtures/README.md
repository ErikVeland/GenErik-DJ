# Traktor DJ reference audio fixtures

These are synthetic diagnostic inputs created locally for later measurements. They have not been imported into the reference iPad. They contain no Traktor audio or extracted assets.

All files are stereo, 44.1 kHz, signed 16-bit PCM WAV. Peak amplitude before quantisation is 0.30. See `manifest.json` for hashes and intended beat sample positions.

| File | Purpose |
| --- | --- |
| `clock-a-120.wav` | Eight bars at 120 BPM. Higher-pitched pulse marks each bar start. Use as a clock reference |
| `clock-b-120.wav` | Eight bars at 120 BPM with a different pulse pitch. Identify the incoming deck in a combined capture |
| `clock-b-128.wav` | Eight bars at 128 BPM. Test tempo matching and relative drift |
| `clock-b-120-pickup.wav` | Same B clock with 0.25 seconds before the grid origin. Test source offset and pickup treatment |
| `tone-stereo-440.wav` | Eight-second 440 Hz tone in both channels. Test pitch change and Keylock |
| `routing-left440-right880.wav` | Eight seconds with 440 Hz left and 880 Hz right. Identify stereo routing and downmix |

The clock tracks contain 32 pulse onsets. The first pulse is a bar start. The listed grid is the intended diagnostic grid. The reference app may analyse it differently, so inspect and correct its grid before using the fixture to judge Sync.

The pickup file's intended first beat is at frame 11,025. A cue at frame zero includes the lead-in. A cue at that first beat does not. This distinguishes source position from scheduled master-clock timing.

The pure tones do not have a natural beatgrid. If a test needs one, set it manually and retain its settings with the capture.

To generate a new copy in a fresh directory:

```bash
python3 tools/make_reference_audio.py --output /private/tmp/traktor-reference-fixtures
```

The generator refuses to overwrite its known outputs. Use the files with the later [capture protocol](../05-reference-capture-and-open-questions.md). They establish diagnostic inputs, not the original app's measured output or musical sound quality.

These are synthetic/codec fixtures, not original TDJ1 ground truth. Current implementation and analysis acceptance are recorded in [Status.md](../../../Replica/Status.md).
