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
    lines = ["# Controller catalogue — R169", "", "Reviewed 12 November 2026. This catalogue is complete for the defined source boundary. Controller feature parity remains a release blocker.", "",
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
             "## Completion rule — R175", "",
             "Theoretical support is the implementation target for every physical model. Physical verification has a separate status.",
             "Complete the documented protocol, controls, modes, lifecycle, feedback and audio routing. Verify them with automated protocol fixtures.",
             "A missing physical test does not block theoretical completion. Unsupported protocols and missing functions still require implementation.",
             "Keep the A10X audio and touch baseline. Test representative connected controllers when they are available.", "",
             "## Priority", "",
             "The first five models in the reviewed Coolblue regional sales list have automatic core-control profiles: FLX4, FLX2, XDJ-RR, OMNIS-DUO and DDJ-GRV6.",
             "Pioneer/AlphaTheta remains the first brand tier, based on the 2026 Digital DJ Tips census. The survey is not a global model-sales ranking.",
             "Other models have no claimed popularity rank. Within that tier, finish documented protocols and startup messages before unknown proprietary protocols.", "",
             "## Club players — R176", "",
             "The club-player order balances established models and recent releases. It is an implementation order, not a measured global sales ranking.",
             "All six players select core controls automatically after the hardware enters Software Control / USB-MIDI mode.",
             "Connected players receive separate A/B assignments. Saved endpoint identities retain their assignments. C/D require the existing four-deck trial.",
             "HID, screens, lights and automatic routing across multiple player audio interfaces remain unimplemented.", "",
             "| Order | Player | MIDI core | HID and screens |", "| ---: | --- | --- | --- |"]
    club = sorted((model for model in models if model["priority"].get("clubImplementationOrder")),
                  key=lambda model: model["priority"]["clubImplementationOrder"])
    lines.extend(f"| {model['priority']['clubImplementationOrder']} | {model['name']} | Automatic | Open |" for model in club)
    lines += ["", "See [the R176 scope and evidence](controller-coverage.md#r176-club-player-midi-controls).", "",
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
              "3. Implement documented iPad or bridge access, model matching, hardware mode selection, audio channels and reconnection. Test these contracts with fixtures.",
              "4. Verify the shared A10X audio and touch baseline, then sample representative connected hardware. Keep the existing performance limits.",
              "5. Complete source-reuse and distribution review before release. Retain upstream provenance and applicable notices.", "",
              "The theoretical support gate depends on implementation and automated fixtures. It does not require physical verification for every model.",
              "Hardware evidence and source-reuse review retain separate states. Current implementation gaps still prevent full theoretical support.", "",
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
              "The importer reads XML protocol facts and explicit, hash-locked handler translations. It never executes downloaded controller JavaScript. Untranslated handlers remain unresolved.",
              "Mixxx source files use GPL-2.0-or-later. The app bundles independently normalised protocol tables, not the upstream scripts. This does not settle distribution obligations.",
              "Manufacturer MIDI tables retain their owners’ rights. Their hashes and URLs identify the reviewed versions.",
              "See [the importer procedure](../../tools/controller_profiles/README.md) and [the R169 delivery note](controller-coverage.md#r169-complete-source-catalogue).", ""]
    return "\n".join(lines)


if __name__ == "__main__":
    catalogue = json.loads((ROOT / "docs/coordination/controller-catalogue.json").read_text())
    runtime = json.loads((ROOT / "Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json").read_text())
    (ROOT / "docs/coordination/controller-catalogue.md").write_text(report(catalogue, runtime))
