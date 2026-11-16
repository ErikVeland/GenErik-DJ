#!/usr/bin/env python3
"""Build the complete source catalogue and separate bounded runtime profiles."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path

from convert import convert_xml
from curated import curated_profiles, REFERENCES
from sources import canonical, manufacturer, read_serato, split_models
from reviewed import REVIEWED
from support import theoretical_support, theoretical_gate
from cdj import cdj_profiles, CDJ_REFERENCES, CLUB_PRIORITY, CDJ_GAPS
from players import player_profiles, PLAYER_REFERENCES, PLAYER_PRIORITY
from controllers import controller_profiles, controller_references
from ddj_family import ddj_profiles, ddj_references, PENDING_DDJ
from legacy_xdj import legacy_xdj_profiles, LEGACY_XDJ_REFERENCES
from entry import entry_profiles, entry_references
from opus import opus_profiles, OPUS_REFERENCES
from legacy_ddj import legacy_ddj_profiles, legacy_ddj_references
from s1 import s1_profiles, S1_REFERENCES
from legacy_systems import legacy_system_profiles, LEGACY_SYSTEM_REFERENCES
from numark import numark_profiles, numark_references
from mixtrack3 import mixtrack3_profiles, mixtrack3_references, MIXTRACK3_SOURCES
from platinum import platinum_profiles, PLATINUM_REFERENCES, PLATINUM_SOURCES
from mixtrack2 import mixtrack2_profiles, mixtrack2_references, MIXTRACK2_SOURCES
from denon import denon_profiles, denon_references, MC4000_SOURCES
from mc6000 import mc6000_profiles, MC6000_REFERENCES, MC6000_SOURCES
from mc7000 import mc7000_profiles, MC7000_REFERENCES, MC7000_SOURCES
from original_mixtrack import original_mixtrack_profiles, original_mixtrack_references, ORIGINAL_MIXTRACK_SOURCES
from party_mix import party_mix_profiles, PARTY_MIX_REFERENCES, PARTY_MIX_SOURCES
from t1 import t1_profiles, T1_REFERENCES
from pad_accessories import pad_accessory_profiles, PAD_REFERENCES
from party_mix2 import party_mix2_profiles, PARTY2_REFERENCES, PARTY2_SOURCES
from terminal_mix import terminal_mix_profiles, terminal_mix_references, TERMINAL_MIX_SOURCES
from dj2go2 import dj2go2_profiles, DJ2GO2_REFERENCES
from ns4fx import ns4fx_profiles, NS4FX_REFERENCES
from mixstream import mixstream_profiles, MIXSTREAM_REFERENCES
from flx10 import flx10_profiles, FLX10_REFERENCES
from ddj1000 import ddj1000_profiles, DDJ1000_REFERENCES
from manufacturer_inventory import MODELS as MANUFACTURER_MODELS, REVIEWED as INVENTORY_REVIEWED
from jogvision import jogvision_profiles, JOGVISION_REFERENCES
from inpulse300mk2 import inpulse300mk2_profiles, MK2_REFERENCES
from inpulse200mk2 import inpulse200mk2_profiles, INPULSE200_REFERENCES
from beatmix import beatmix_profiles, BEATMIX_REFERENCES
from mc2000 import mc2000_profiles, MC2000_REFERENCES
from mixon4 import mixon4_profiles, MIXON4_REFERENCES
from dicer import dicer_profiles, DICER_REFERENCES
from ns6ii import ns6ii_profiles, NS6II_REFERENCES

LEGACY = {"Pioneer DDJ-FLX4": "DDJ-FLX4", "AlphaTheta DDJ-FLX2": "DDJ-FLX2",
          "Pioneer DDJ-400": "DDJ-400",
          "Pioneer DDJ-REV1": "DDJ-REV1", "Pioneer DDJ-REV5": "DDJ-REV5"}
NI_MODELS = ["S2 Mk1", "S2 Mk2", "S2 Mk3", "S3", "S4 Mk1", "S4 Mk2", "S4 Mk3", "S5", "S8",
             "X1 Mk1", "X1 Mk2", "X1 Mk3", "Z1", "Z1 Mk2", "F1", "D2", "Z2", "MX2"]
NATIVE = {"S2 Mk2", "S2 Mk3", "S3", "S4 Mk2", "Z1"}
SALES = {canonical(name): rank for rank, name in enumerate([
    "Pioneer DDJ-FLX4", "AlphaTheta DDJ-FLX2", "Pioneer XDJ-RR", "AlphaTheta OMNIS-DUO", "AlphaTheta DDJ-GRV6"], 1)}
GENERIC_NAMES = {"", "dj", "cmd", "traktor", "pioneer", "hercules", "mixtrack", "numark", "gemini", "reloop",
                 "network", "usb audio device", "mixvibes", "ns6", "vestax"}
CORE = {"playA", "playB", "levelA", "levelB", "tempoA", "tempoB", "crossfader", "cueA", "cueB"}
FEEDBACK = {"playA", "playB", "syncA", "syncB", "keylockA", "keylockB", "cueA", "cueB", "loopA", "loopB"}
FEEDBACK |= {f"hotcue{slot}{deck}" for slot in range(1, 9) for deck in "AB"}
DJ_BRANDS = {"Pioneer", "Numark", "Hercules", "Denon", "Reloop", "Behringer", "Stanton", "Vestax", "American Audio", "MixVibes", "Korg"}


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def aliases(name, identifiers):
    brand = manufacturer(name)
    names = [name, name[len(brand):].strip()] if brand != "Other" else [name]
    names += [value.strip() for value in identifiers if value.strip().lower() not in GENERIC_NAMES]
    for model in split_models(name):
        names.append(model)
        brand = manufacturer(model)
        if brand != "Other":
            names.append(model[len(brand):].strip())
    return sorted({value for value in names if len(value) >= 4 and value.lower() not in GENERIC_NAMES})


def build(cache, serato_html):
    locked = json.loads(Path(__file__).with_name("sources.lock.json").read_text())
    manifest = json.loads((cache / "manifest.json").read_text())
    if manifest != locked["mixxx"]:
        raise ValueError("The reference manifest differs from the reviewed lock file.")
    refs = {Path(entry["path"]).name: entry for entry in manifest["files"]}
    benchmark = locked["benchmark"]["rows"]
    if serato_html is not None:
        if hashlib.sha256(serato_html.read_bytes()).hexdigest() != locked["benchmark"]["sha256"]:
            raise ValueError("The benchmark snapshot differs from the reviewed lock file.")
        if read_serato(serato_html.read_text()) != benchmark:
            raise ValueError("The benchmark model rows differ from the reviewed lock file.")
    models, definitions, profiles = {}, [], []

    def add_model(name, source, role="primary", benchmark_row=False):
        key = canonical(name)
        if key not in models:
            models[key] = {"id": key, "name": name, "manufacturer": manufacturer(name), "role": role,
                           "benchmark": False, "sources": [], "definitions": [], "implementation": "protocol-needed",
                           "hardwareAcceptance": "not-verified", "releaseReady": False}
        model = models[key]
        model["benchmark"] |= benchmark_row
        if benchmark_row:
            model["role"] = role
        if source not in model["sources"]:
            model["sources"].append(source)
        return model

    for entry in benchmark:
        for name in split_models(entry["name"]):
            add_model(name, entry["source"], entry["role"], True)
    for name, source in MANUFACTURER_MODELS:
        add_model(name, source)
    for name, profile in LEGACY.items():
        model = add_model(name, "Replica/Sources/TDJInterface/ControllerPioneerProfiles.swift")
        model.update(implementation="automatic-profile", profile=profile)
    for name in NI_MODELS:
        prefix = "Native Instruments Traktor " + ("" if name == "MX2" else "Kontrol ")
        model = add_model(prefix + name, "docs/coordination/controller-coverage.md")
        model.update(implementation="native-accessory" if name in NATIVE else "linux-bridge",
                     profile=name, role="accessory" if name.startswith(("X1", "F1", "D2")) else "primary")
    add_model("Reloop Beatpad", "docs/coordination/beatpad-native.md").update(implementation="native-midi", profile="Beatpad")

    reviewed = curated_profiles() + cdj_profiles() + player_profiles() + controller_profiles() + ddj_profiles() + legacy_xdj_profiles() + entry_profiles() + opus_profiles() + legacy_ddj_profiles() + s1_profiles() + legacy_system_profiles() + numark_profiles() + mixtrack3_profiles() + platinum_profiles() + mixtrack2_profiles() + denon_profiles() + mc6000_profiles() + mc7000_profiles() + original_mixtrack_profiles() + party_mix_profiles() + t1_profiles() + pad_accessory_profiles() + party_mix2_profiles() + terminal_mix_profiles() + dj2go2_profiles() + ns4fx_profiles() + mixstream_profiles() + flx10_profiles() + ddj1000_profiles() + jogvision_profiles() + inpulse300mk2_profiles() + inpulse200mk2_profiles() + beatmix_profiles() + mc2000_profiles() + mixon4_profiles() + dicer_profiles() + ns6ii_profiles()
    reviewed_ids = {canonical(item.get("catalogueName", item["id"])) for item in reviewed}
    for path in sorted((cache / "res/controllers").glob("*.xml")):
        reference = refs[path.name]
        data = path.read_bytes()
        if hashlib.sha256(data).hexdigest() != reference["sha256"]:
            raise ValueError(f"The reference changed: {path.name}")
        review = REVIEWED.get(path.name)
        if review:
            script = refs[review["script"]]
            if hashlib.sha256((cache / script["path"]).read_bytes()).hexdigest() != script["sha256"]:
                raise ValueError(f"The reviewed script changed: {review['script']}")
        result = convert_xml(path, review["handlers"] if review else None)
        definition_id = path.name
        transport = "midi" if path.name.endswith(".midi.xml") else "hid" if path.name.endswith(".hid.xml") else "bulk"
        definitions.append({"id": definition_id, "name": result["name"], "transport": transport,
                            "source": reference, "scripts": result["scripts"],
                            "implementedInputCount": len(result["inputs"]), "sourceInputCount": result["inputCount"],
                            "implementedOutputCount": len(result["outputs"]), "sourceOutputCount": result["outputCount"],
                            "inputRecords": result["inputRecords"], "outputRecords": result["outputRecords"],
                            "unresolved": result["unresolved"]})
        for name in split_models(result["name"]):
            role = "virtual" if any(word in name.lower() for word in ["dummy", "wireless", "ipad", "joymidi", "midi for light"]) else "primary"
            if name in {"Pioneer CDJ HID", "MIDI Keyboard"}:
                role = "protocol-family"
            model = add_model(name, reference["url"], role)
            model["definitions"].append(definition_id)
            if model["implementation"] == "protocol-needed":
                model["implementation"] = "partial-midi-profile" if result["inputs"] and transport == "midi" else "adapter-needed"
        if not result["inputs"] or transport != "midi":
            continue
        if canonical(result["name"]) in reviewed_ids or canonical(result["name"]) in {canonical(name) for name in LEGACY} or "Traktor" in result["name"] or result["name"] == "Reloop Beatpad":
            continue
        outputs = [entry for entry in result["outputs"] if entry["action"] in FEEDBACK]
        profile = {"id": result["name"], "aliases": aliases(result["name"], result["identifiers"]),
                   "definition": definition_id,
                   "inputs": result["inputs"], "outputs": outputs,
                   "startup": review["startup"] if review else [], "shutdown": review["shutdown"] if review else [],
                   "autoSelect": CORE <= {entry["action"] for entry in result["inputs"] if entry.get("targetDeck")
                       in {None, "a" if entry["action"].endswith("A") else "b" if entry["action"].endswith("B") else None}}
                   and manufacturer(result["name"]) in DJ_BRANDS and (bool(review) or not result["scripts"]),
                   "scope": review.get("scope", "Partial mapping. Hardware verification is open.") if review else "Partial mapping. Hardware verification is open.", "source": reference["url"]}
        profiles.append(profile)
    for item in reviewed:
        for name in split_models(item.get("catalogueName", item["id"])):
            model = add_model(name, item["source"], "accessory" if item.get("role") == "accessory" else "primary")
            if item["id"] in PLAYER_REFERENCES:
                model["name"] = item["id"]
            model.update(implementation="automatic-core-profile" if item["autoSelect"] else "partial-midi-profile",
                         profile=item["id"], automaticControls=item["autoSelect"])
            model["definitions"].append(item["definition"])
        reference = REFERENCES.get(item["id"])
        source = CDJ_REFERENCES.get(item["id"]) or PLAYER_REFERENCES.get(item["id"]) or controller_references().get(item["id"]) or ddj_references().get(item["id"]) or LEGACY_XDJ_REFERENCES.get(item["id"]) or entry_references().get(item["id"]) or OPUS_REFERENCES.get(item["id"]) or legacy_ddj_references().get(item["id"]) or S1_REFERENCES.get(item["id"]) or LEGACY_SYSTEM_REFERENCES.get(item["id"]) or numark_references().get(item["id"]) or mixtrack3_references().get(item["id"]) or PLATINUM_REFERENCES.get(item["id"]) or mixtrack2_references().get(item["id"]) or denon_references().get(item["id"]) or MC6000_REFERENCES.get(item["id"]) or MC7000_REFERENCES.get(item["id"]) or original_mixtrack_references().get(item["id"]) or PARTY_MIX_REFERENCES.get(item["id"]) or T1_REFERENCES.get(item["id"]) or PAD_REFERENCES.get(item["id"]) or PARTY2_REFERENCES.get(item["id"]) or terminal_mix_references().get(item["id"]) or DJ2GO2_REFERENCES.get(item["id"]) or NS4FX_REFERENCES.get(item["id"]) or MIXSTREAM_REFERENCES.get(item["id"]) or FLX10_REFERENCES.get(item["id"]) or DDJ1000_REFERENCES.get(item["id"]) or JOGVISION_REFERENCES.get(item["id"]) or MK2_REFERENCES.get(item["id"]) or INPULSE200_REFERENCES.get(item["id"]) or BEATMIX_REFERENCES.get(item["id"]) or MC2000_REFERENCES.get(item["id"]) or MIXON4_REFERENCES.get(item["id"]) or DICER_REFERENCES.get(item["id"]) or NS6II_REFERENCES.get(item["id"]) or {"url": item["source"],
            "sha256": reference[1] if reference else "b1274a096816e795f0d35183527fc69a170d6d21a4f0e9151a1dae7810e3aee7"}
        definitions.append({"id": item["definition"], "name": item["id"], "transport": "midi",
                            "source": source,
                            "implementedInputCount": len(item["inputs"]), "implementedOutputCount": len(item["outputs"]),
                            "sourceInputCount": None, "sourceOutputCount": None,
                            "unresolved": [{"reason": gap} for gap in CDJ_GAPS] if item.get("role") == "player" else
                            [{"reason": reason} for reason in ["Additional modes, FX, displays and audio routing remain unimplemented."] + item.get("gaps", [])]})
    for name, pending in PENDING_DDJ.items():
        definition = "manufacturer:" + canonical(name)
        model = add_model(name, pending["source"]["url"])
        model["implementation"] = pending.get("implementation", "adapter-needed")
        model["definitions"].append(definition)
        definitions.append({"id": definition, "name": name, "transport": "midi", "source": pending["source"],
                            "implementedInputCount": 0, "implementedOutputCount": 0,
                            "sourceInputCount": None, "sourceOutputCount": None,
                            "unresolved": [{"reason": pending["gap"]}]})
    profiles.extend(reviewed)
    # Alternative mappings stay in the source inventory. One deterministic recipe serves each model.
    choices = {}
    for profile in profiles:
        key = canonical(profile["id"])
        current = choices.get(key)
        if current is None or (len(profile["inputs"]), len(profile["outputs"])) > (len(current["inputs"]), len(current["outputs"])):
            choices[key] = profile
    profiles = sorted(choices.values(), key=lambda profile: profile["id"].lower())
    for model in models.values():
        candidates = [profile for profile in profiles if profile["definition"] in model["definitions"]]
        profile = max(candidates, key=lambda item: len(item["inputs"])) if candidates else None
        if profile and model["implementation"] == "partial-midi-profile":
            model.update(profile=profile["id"], automaticControls=profile["autoSelect"])
        model["controlActions"] = sorted({item["action"] + (":" + item["targetDeck"] if item.get("targetDeck") else "")
                                          for item in profile["inputs"]}) if profile else []
        model["inputBindingCount"] = len(profile["inputs"]) if profile else None
        model["feedbackBindingCount"] = len(profile["outputs"]) if profile else None
        automatic = model["implementation"] in {"automatic-profile", "automatic-core-profile", "native-accessory", "native-midi"}
        model["connection"] = "Linux USB bridge" if model["implementation"] == "linux-bridge" else "USB MIDI" if profile or model["implementation"] == "automatic-profile" else "Existing native adapter" if automatic else "Protocol and iPad connection route require review"
        model["audioRouting"] = "Automatic master 1–2 / headphones 3–4" if model["id"] in {canonical("Pioneer DDJ-FLX4"), canonical("Pioneer DDJ-400")} else "Existing native routing. Physical acceptance is open." if model["implementation"] in {"native-accessory", "native-midi"} else "Unverified. Automatic channel assignment is not enabled."
        model["zeroConfig"] = {"automaticControls": automatic or bool(profile and profile["autoSelect"]),
                               "completeFeatureParity": False, "acceptedOnA10X": False}
        if profile and profile.get("hardwareMode"):
            model["zeroConfig"]["requiredHardwareMode"] = profile["hardwareMode"]
        model["isPhysicalModel"] = model["role"] not in {"virtual", "protocol-family"}
        model["theoreticalSupport"] = theoretical_support(model["implementation"], model["zeroConfig"]["automaticControls"],
            [definition for definition in definitions if definition["id"] == profile["definition"]] if profile else [],
            lifecycle_reviewed=bool(profile and (profile["definition"] in REVIEWED or profile["definition"].startswith("manufacturer:")
                or not next(item for item in definitions if item["id"] == profile["definition"]).get("scripts"))),
            audio_routing_implemented=model["audioRouting"].startswith(("Automatic", "Existing native")))
        model["zeroConfig"]["completeFeatureParity"] = model["theoreticalSupport"]["complete"]
        model["gaps"] = [] if model["theoreticalSupport"]["complete"] else [
            "Complete documented controls, modes, lifecycle, audio routing and automated protocol fixtures."]
        model["gaps"].extend(profile.get("gaps", []) if profile else [])
        for name, pending in PENDING_DDJ.items():
            if model["id"] == canonical(name):
                model["gaps"].append(pending["gap"])
        if model["implementation"] == "protocol-needed":
            model["gaps"].append("No implemented protocol is present in the pinned references. Manufacturer protocol work is required.")
        elif model["implementation"] == "adapter-needed":
            model["gaps"].append("A controller-specific protocol adapter is required.")
        elif model["implementation"] == "partial-midi-profile":
            model["gaps"].append("Untranslated controls and script behaviour remain in the linked definition records.")
        if profile and profile.get("role") == "player":
            model["playerSupport"] = {"requiredHardwareMode": profile.get("hardwareMode", "Software Control / USB-MIDI"), "midiInputImplemented": True,
                                      "recognisedNames": profile["aliases"],
                                      "automaticDeckAssignment": True, "hidImplemented": False, "displayFeedbackImplemented": False,
                                      "ledFeedbackImplemented": False, "automaticMultiDeviceAudioImplemented": False}
            model["gaps"].extend(CDJ_GAPS)
        model["priority"] = {"regionalSalesRank": SALES.get(model["id"]),
                             "brandTier": 0 if model["manufacturer"] in {"Pioneer", "AlphaTheta"} else 1,
                             "basis": "Coolblue regional sales rank where available. Pioneer/AlphaTheta first follows the 2026 DJ Census. Other model ranks are unknown."}
        priorities = [canonical(name) for name in CLUB_PRIORITY + PLAYER_PRIORITY]
        model["priority"]["clubImplementationOrder"] = priorities.index(model["id"]) + 1 if model["id"] in priorities else None
        if model["priority"]["clubImplementationOrder"]:
            model["priority"]["basis"] = "Club-player implementation order balances established models and recent releases. Global model sales ranks are unknown."
    ordered = sorted(models.values(), key=lambda model: (model["priority"]["clubImplementationOrder"] or 1000,
                     model["priority"]["regionalSalesRank"] or 100,
                     model["priority"]["brandTier"], model["manufacturer"], model["name"]))
    catalogue = {"schemaVersion": 1, "reviewed": "2026-11-17", "upstreamRevision": manifest["revision"],
                 "benchmarkSource": {"url": locked["benchmark"]["url"],
                                     "sha256": locked["benchmark"]["sha256"], "rowCount": len(benchmark)},
                 "benchmarkRows": benchmark, "manufacturerInventoryReviewed": INVENTORY_REVIEWED, "models": ordered, "definitions": definitions,
                 "releaseGate": {"catalogueCompletionScope": "Pinned software sources and the listed manufacturer additions. The market audit remains open.",
                                 "manufacturerAuditComplete": False, "catalogueComplete": all(all(canonical(name) in models for name in split_models(row["name"])) for row in benchmark)
                     and {item["id"] for item in definitions if item["id"].endswith(".xml")}
                     == {Path(item["path"]).name for item in locked["mixxx"]["files"] if item["path"].endswith(".xml")}, "hardwareParityAccepted": False,
                                 "sourceReuseReviewAccepted": False,
                                 "theoreticalSupport": theoretical_gate(ordered),
                                 "reason": "Documented implementation gaps block theoretical completion. Physical tests are separate evidence, not a per-model completion requirement."}}
    if not catalogue["releaseGate"]["catalogueComplete"]:
        raise ValueError("The cache does not contain every locked mapping definition.")
    return catalogue, {"schemaVersion": 1, "profiles": profiles}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cache", type=Path, required=True)
    parser.add_argument("--serato", type=Path)
    parser.add_argument("--catalogue", type=Path, required=True)
    parser.add_argument("--runtime", type=Path, required=True)
    args = parser.parse_args()
    catalogue, runtime = build(args.cache, args.serato)
    write_json(args.catalogue, catalogue)
    write_json(args.runtime, runtime)
    print(json.dumps({"benchmarkRows": len(catalogue["benchmarkRows"]), "models": len(catalogue["models"]),
                      "definitions": len(catalogue["definitions"]), "runtimeProfiles": len(runtime["profiles"]),
                      "automaticControlCandidates": sum(profile["autoSelect"] for profile in runtime["profiles"]),
                      "implementation": dict(Counter(model["implementation"] for model in catalogue["models"]))}))


if __name__ == "__main__":
    main()
