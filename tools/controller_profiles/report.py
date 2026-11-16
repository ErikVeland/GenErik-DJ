#!/usr/bin/env python3
"""Write the reviewable catalogue from the checked model records."""
from collections import Counter
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def report(catalogue, runtime):
    models = catalogue["models"]
    counts = Counter(model["implementation"] for model in models)
    source_definitions = [item for item in catalogue["definitions"] if item["id"].endswith(".xml")]
    profiles = runtime["profiles"]
    player_count = sum("playerSupport" in model for model in models)
    lines = ["# Controller catalogue — R169", "", "Reviewed 16 November 2026. This catalogue is complete for the defined source boundary. Controller feature parity remains a release blocker.", "",
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
             "## Club and XDJ players — R176/R177", "",
             "The club-player order balances established models and recent releases. It is an implementation order, not a measured global sales ranking.",
             f"All {player_count} players select core controls automatically after the hardware enters its PC or USB-MIDI mode.",
             "Connected players receive separate A/B assignments. Saved endpoint identities retain their assignments. C/D require the existing four-deck trial.",
             "HID, screens, lights and automatic routing across multiple player audio interfaces remain unimplemented.", "",
             "| Order | Player | MIDI core | HID and screens |", "| ---: | --- | --- | --- |"]
    club = sorted((model for model in models if model["priority"].get("clubImplementationOrder")),
                  key=lambda model: model["priority"]["clubImplementationOrder"])
    lines.extend(f"| {model['priority']['clubImplementationOrder']} | {model['name']} | Automatic | Open |" for model in club)
    lines += ["", "See [R176 club-player controls](controller-coverage.md#r176-club-player-midi-controls) and [R177 earlier-player controls](controller-coverage.md#r177-xdj-and-earlier-cdj-controls).", "",
              "## Popular controller systems — R178", "",
              "XDJ-AZ, XDJ-RX3, XDJ-XZ, DDJ-FLX6, DDJ-800 and DDJ-SB3 now select reviewed core MIDI profiles automatically.",
              "Factory tables retain separate pad channels, fader direction, loop controls and documented feedback. Inactive C/D targets cannot control hidden decks.",
              "Hardware modes, advanced functions, screens and audio routing remain open. This increment does not claim full feature parity.",
              "See [R178 controller systems](controller-coverage.md#r178-popular-xdj-and-ddj-systems).", "",
              "## SX and RX-family systems — R179", "",
              "DDJ-SX3, SX2, SX, RX, RZ and RZX select core MIDI profiles automatically. Their factory tables retain model-specific controls.",
              "The original SX deck-D filter stays unmapped because its published pair conflicts with Browse. SR2 banked Load routing remains unimplemented.",
              "Hardware mode selection, advanced functions, complete feedback and audio routing remain open.",
              "See [R179 DDJ families](controller-coverage.md#r179-sx-and-rx-family-controllers).", "",
              "## Serato-oriented DDJ and XDJ-RX models — R180", "",
              "DDJ-1000SRT, DDJ-SZ2, DDJ-SZ and XDJ-RX2 now select core MIDI profiles automatically.",
              "The original RX has a separate manual recipe. Its speed jogs, four Hot Cues and absent Load/output messages retain their factory-table limits.",
              "REV7 motorised-platter, display and lifecycle protocols remain unimplemented. Its published relative JOG entry does not establish platter support.",
              "See [R180 controller systems](controller-coverage.md#r180-serato-oriented-ddj-and-xdj-rx-models).", "",
              "## Common entry-level Pioneer systems — R181", "",
              "DDJ-SB2, SB, RB, RR, 200 and WeGO4 select documented core controls automatically.",
              "The profiles retain two/four-deck limits, actual pad layouts, SB Vinyl Off releases and published application-connect messages.",
              "Missing physical controls stay in the app. Remaining modes, complete feedback and audio routing remain open.",
              "See [R181 entry-level systems](controller-coverage.md#r181-entry-level-pioneer-systems).", "",
              "## Published DDJ startup packets — R182", "",
              "SX, SX2, RX, RZ, RZX, SZ and SZ2 now send their documented application-connect packet once per session and after reconnects.",
              "Paired-output and failure fixtures retain the existing control facts. Full lifecycle and feature parity remain open.",
              "See [R182 startup messages](controller-coverage.md#r182-published-ddj-application-connect-messages).", "",
              "## OPUS-QUAD core controls — R183", "",
              "OPUS-QUAD selects core MIDI controls automatically, with its own Hot Cue layout, shifted jog and signed loop-size encoder.",
              "Screens, complete feedback, advanced modes and audio routing remain open.",
              "See [R183 OPUS-QUAD](controller-coverage.md#r183-opus-quad-core-midi-controls).", "",
              "## ERGO and earlier WeGO systems — R184", "",
              "WeGO3, WeGO2, WeGO and ERGO select separate core MIDI profiles automatically.",
              "Their deck counts, Play messages, jog encodings, loop controls and global mixer pairs retain each generation’s factory facts.",
              "See [R184 legacy Pioneer](controller-coverage.md#r184-ergo-and-earlier-wego-systems).", "",
              "## DDJ-S1 paired relative jogs — R185", "",
              "DDJ-S1 selects core MIDI controls automatically. Its signed 14-bit jog decoder emits once per complete pair and clears pending pairs on reconnect.",
              "Orphan/repeated low bytes cannot move the deck. Jog calibration, remaining modes, complete feedback and audio routing remain open.",
              "See [R185 DDJ-S1](controller-coverage.md#r185-ddj-s1-and-paired-relative-jog-messages).", "",
              "## XDJ-AERO and XDJ-R1 — R186", "",
              "XDJ-AERO and XDJ-R1 select core MIDI profiles automatically. Their deck-local browsers load the intended deck.",
              "R1 retains three Hot Cues per deck. AERO sample controls do not become invented Hot Cues. Hardware modes and full audio routing remain open.",
              "See [R186 earlier XDJ systems](controller-coverage.md#r186-xdj-aero-and-xdj-r1-core-controls).", "",
              "## Mixtrack FX core controls — R187", "",
              "Mixtrack Pro FX and Platinum FX select native core controls with model-specific, bounded SysEx setup.",
              "The profiles reuse pinned Mixxx protocol facts. Scripts do not run in the app. Unresolved pads, modes, displays and audio routing remain explicit.",
              "See [R187 Mixtrack FX](controller-coverage.md#r187-mixtrack-fx-core-controls-and-bounded-sysex-setup).", "",
              "## Mode-gated Pro FX Hot Cues — R188", "",
              "Mixtrack Pro FX has eight native Hot Cues per deck in Hot Cue mode. Other pad modes cannot trigger them.",
              "Independent mode state, paired indicators, releases and reconnects have fixtures. Platinum FX pad bank/hold behaviour remains open.",
              "See [R188 Pro FX pads](controller-coverage.md#r188-mode-gated-mixtrack-pro-fx-hot-cues).", "",
              "## Mixtrack 3 and Pro 3 — R189", "",
              "Mixtrack 3 and Pro 3 select separate native core profiles from their shared pinned mapping.",
              "Shift state remains independent per deck. Unsupported shifted combinations cannot change base controls on that deck.",
              "See [R189 Mixtrack 3](controller-coverage.md#r189-mixtrack-3-and-mixtrack-pro-3-core-controls).", "",
              "## Original Mixtrack Platinum — R190", "",
              "The original Platinum selects a separate native core profile. Its explicit low-byte CC 119 and wrapped-jog rule retain the pinned protocol facts.",
              "Four-deck routing and global Shift have fixtures. Pads, advanced modes, screens, physical calibration and full audio routing remain open.",
              "See [R190 original Platinum](controller-coverage.md#r190-original-mixtrack-platinum-core-controls).", "",
              "## Native tempo direction correction — R191", "",
              "Mixxx-derived tempo controls now account for its default engine direction once. Only tempo polarity changes in 54 runtime recipes.",
              "Manufacturer-table controls retain their interpretation. Endpoint fixtures cover reviewed Numark and converted Hercules controls.",
              "See [R191 tempo direction](controller-coverage.md#r191-native-tempo-direction-for-mixxx-derived-controls).", "",
              "## Mixtrack II and Pro II — R192", "",
              "Mixtrack II and Pro II select separate native core profiles. One physical channel retains independent deck and Shift routing.",
              "Shifted Keylock/loop sizing and seven-bit tempo have fixtures. Pads, additional modes and full audio routing remain open.",
              "See [R192 Mixtrack II](controller-coverage.md#r192-mixtrack-ii-and-mixtrack-pro-ii-core-controls).", "",
              "## Denon MC4000 — R193", "",
              "MC4000 selects a native core profile. Factory addresses and the pinned working tempo order have fixtures.",
              "The factory pitch-byte label conflict stays explicit. Pad modes, additional functions and audio routing remain open.",
              "See [R193 MC4000](controller-coverage.md#r193-denon-mc4000-core-controls).", "",
              "## Denon MC6000MK2 — R194", "",
              "MC6000MK2 selects a native core profile with A/C/B/D deck channels, side-wide Shift and separate LED trigger commands.",
              "Factory pitch-bend tempo and zero/127 browser counts have fixtures. Pad banks, filters, advanced functions and audio routing remain open.",
              "See [R194 MC6000MK2](controller-coverage.md#r194-denon-mc6000mk2-core-controls).", "",
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
