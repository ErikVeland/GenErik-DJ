#!/usr/bin/env python3
"""Write the reviewable catalogue from the checked model records."""
from collections import Counter
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def report(catalogue, runtime):
    models = catalogue["models"]
    counts = Counter(model["implementation"] for model in models)
    source_definitions = [item for item in catalogue["definitions"] if not item["id"].startswith("manufacturer:")]
    profiles = runtime["profiles"]
    lines = ["# Controller catalogue — R169", "", "Reviewed 11 November 2026. This catalogue is complete for the defined source boundary. Controller feature parity remains a release blocker.", "",
             "## Boundary and counts", "",
             f"- {len(catalogue['benchmarkRows'])} published Serato iOS rows, expanded to {sum(model['benchmark'] for model in models)} distinct model records.",
             f"- All {len(source_definitions)} Mixxx definitions at `{catalogue['upstreamRevision']}`, including alternative MIDI, HID and bulk mappings.",
             "- All 18 existing NI Traktor variants and the original Reloop Beatpad adapter.",
             f"- {len(models)} total catalogue records. {sum(model['isPhysicalModel'] for model in models)} name physical models. The remainder identify software endpoints or protocol families.",
             f"- {len(profiles)} bundled data recipes, plus seven existing code profiles. Most data recipes cover only part of the hardware.",
             f"- {sum(item['autoSelect'] for item in profiles) + 7} factory profiles select core controls automatically. Existing NI and Beatpad adapters retain their separate connection routes.",
             f"- Every one of the {sum(item['sourceInputCount'] for item in source_definitions):,} source input rows and {sum(item['sourceOutputCount'] for item in source_definitions):,} output rows has a conversion disposition.", "",
             "These counts do not establish hardware acceptance, complete pad modes, motor support, screens, audio routing or feature parity.",
             "Serato’s advertised total includes controllers, mixers, turntables, standalone units and accessories. It is not a count of full-feature controller mappings.", "",
             "## Priority", "",
             "The first five models in the reviewed Coolblue regional sales list have automatic core-control profiles: FLX4, FLX2, XDJ-RR, OMNIS-DUO and DDJ-GRV6.",
             "Pioneer/AlphaTheta remains the first brand tier, based on the 2026 Digital DJ Tips census. The survey is not a global model-sales ranking.",
             "Other models have no claimed popularity rank. Within that tier, finish documented protocols and startup messages before unknown proprietary protocols.", "",
             "## Implementation states", "", "| State | Records | Meaning |", "| --- | ---: | --- |"]
    meanings = {"automatic-profile": "Existing factory controls and lights. Physical acceptance remains open.",
                "automatic-core-profile": "Reviewed core MIDI controls. Additional modes and acceptance remain open.",
                "partial-midi-profile": "Explicit XML controls are available. Script-dependent behaviour is unresolved.",
                "protocol-needed": "The pinned references contain no implemented mapping for this model.",
                "adapter-needed": "A referenced HID, bulk or script protocol needs an adapter.",
                "linux-bridge": "An existing Linux USB bridge adapter is present. This is not direct iPad USB support.",
                "native-accessory": "An existing native accessory adapter is present.",
                "native-midi": "The existing native Beatpad MIDI adapter is present."}
    lines.extend(f"| {state} | {count} | {meanings[state]} |" for state, count in sorted(counts.items()))
    lines += ["", "## Release blockers", "",
              "1. Finish the protocol-needed and adapter-needed rows. Translate the listed script behaviours through explicit, tested app contracts.",
              "2. Complete shifted controls, pad modes, FX, stems, meters, screens and motors where the model provides them.",
              "3. Verify iPad USB access, model identity, hardware mode selection, power, audio channels and reconnection for each model.",
              "4. Verify simultaneous input, feedback, continuous audio and touch on the A10X. Keep the existing performance limits.",
              "5. Complete source-reuse and distribution review before release. Retain upstream provenance and applicable notices.", "",
              "The machine-readable release gate remains false for feature parity, source-reuse acceptance and A10X acceptance. No catalogue row passes the release gate.", "",
              "## Benchmark models", "",
              "Automatic means core control selection. Manual means a partial data recipe. Unknown routing requires verification.",
              "Detailed actions, source hashes, row dispositions, connection routes and remaining gaps are in [the JSON catalogue](controller-catalogue.json).", "",
              "| Model | Source role | Controls | Audio | Source |", "| --- | --- | --- | --- | --- |"]
    for model in models:
        if not model["benchmark"]:
            continue
        controls = "Automatic core" if model["zeroConfig"]["automaticControls"] else "Manual partial" if model["implementation"] == "partial-midi-profile" else model["implementation"]
        audio = "Automatic split" if model["audioRouting"].startswith("Automatic") else "Unverified"
        lines.append(f"| {model['name']} | {model['role']} | {controls} | {audio} | [Reference]({model['sources'][0]}) |")
    lines += ["", "## Additional models and source families", "", "| Model or family | Role | State | Source |", "| --- | --- | --- | --- |"]
    for model in models:
        if not model["benchmark"]:
            source = model["sources"][0]
            if not source.startswith("https:"):
                source = "../../" + source
            lines.append(f"| {model['name']} | {model['role']} | {model['implementation']} | [Reference]({source}) |")
    lines += ["", "## Provenance and reproduction", "",
              "The importer reads XML protocol facts. It never executes downloaded controller JavaScript. Script-dependent controls remain unresolved.",
              "Mixxx source files use GPL-2.0-or-later. The app bundles independently normalised protocol tables, not the upstream scripts. This does not settle distribution obligations.",
              "Manufacturer MIDI tables retain their owners’ rights. Their hashes and URLs identify the reviewed versions.",
              "See [the importer procedure](../../tools/controller_profiles/README.md) and [the R169 delivery note](controller-coverage.md#r169-complete-source-catalogue).", ""]
    return "\n".join(lines)


if __name__ == "__main__":
    catalogue = json.loads((ROOT / "docs/coordination/controller-catalogue.json").read_text())
    runtime = json.loads((ROOT / "Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json").read_text())
    (ROOT / "docs/coordination/controller-catalogue.md").write_text(report(catalogue, runtime))
