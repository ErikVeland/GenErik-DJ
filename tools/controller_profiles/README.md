# Controller catalogue tools

These tools reproduce the R169 source catalogue and bounded MIDI data recipes.
They use Python 3.9 or later and the standard library. No package installation is required.
The repository has no controller-generation script in `package.json`, so these tools run directly.

## Sources

`sources.lock.json` pins all 317 Mixxx reference files by Git revision, Git blob hash and SHA-256.
It also retains the 121 reviewed Serato iOS model rows and their source-page hash.
`curated.py` records independently checked manufacturer MIDI facts for the next popular models.

The source boundary includes every shipped Mixxx definition at the pinned revision, the published Serato iOS list, existing NI adapters and Beatpad.
It does not assert coverage of every controller ever sold.
Virtual endpoints, protocol families, accessory models and DVS-only models retain separate roles.

## Regenerate the catalogue

Run these commands from the repository root.
The first command downloads public references when the cache is absent.
It verifies each pinned Git blob before writing the manifest.

```sh
python3 tools/controller_profiles/fetch_reference.py TestBuilds/r169/upstream
python3 tools/controller_profiles/build_catalogue.py \
  --cache TestBuilds/r169/upstream \
  --catalogue docs/coordination/controller-catalogue.json \
  --runtime Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json
python3 tools/controller_profiles/report.py
python3 -m unittest discover -s tools/controller_profiles -p 'test_*.py'
```

To verify the original Serato HTML snapshot, add `--serato TestBuilds/r169/serato-ios.html` to the build command.
The tool rejects a different page hash or different model rows.
The locked rows allow offline reproduction without that HTML file.

Do not update the revision or source hashes without reviewing the resulting protocol changes.
Preserve earlier snapshots and failed validation evidence.

## Conversion rules

- Translate explicit XML input and output facts to existing app actions.
- Preserve A/B/C/D targets, channels, message kinds, inversion and documented relative encoding.
- Require a matching group, key, channel and low byte for each high-resolution CC pair.
- Reject conflicting physical addresses and unknown encodings.
- Retain a disposition for every source input and output row.
- Leave script-dependent behaviour unresolved. Never execute controller JavaScript.
- Select an imported recipe automatically only when it has the required core controls and no script lifecycle dependency.
- Keep all physical acceptance and complete-feature release gates open until evidence closes them.

Manufacturer adapters can select reviewed core controls automatically.
Their extra pad modes, displays, FX, motors, audio routing and hardware acceptance remain separate work.
Only the reviewed Inpulse 500 adapter sends a startup/shutdown mode message in this batch.
It requires one paired physical output. A failed startup leaves its controls inactive.

## Reuse and distribution review

Mixxx source files use GPL-2.0-or-later. The lock file links the exact upstream files and licence.
The app does not bundle or execute those scripts.
Independently normalised protocol facts do not, by themselves, settle distribution obligations.
Complete source-reuse review before release and retain all applicable notices.
Manufacturer documents retain their owners’ rights.

## Validation scope

Python checks verify identity, source completeness, row accounting, address conflicts and deterministic generation.
Focused Swift checks verify catalogue decoding, automatic matching, four-deck targets, learning, feedback edits and device lifecycle messages.
Native iPad compilation checks the active target without simulator packaging.
These checks do not replace a signed app, physical-controller tests or A10X audio and touch acceptance.
