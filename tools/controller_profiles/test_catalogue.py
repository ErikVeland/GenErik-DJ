"""Focused checks for source identity, conversion and catalogue completeness."""
import hashlib
from itertools import combinations
import json
from pathlib import Path
import tempfile
import unittest
import xml.etree.ElementTree as ET

from build_catalogue import build
from convert import control_record, convert_xml
from curated import curated_profiles
from fetch_reference import fetch, git_blob_hash
from sources import canonical, split_models
from reviewed import REVIEWED
from support import theoretical_support, theoretical_gate
from cdj import cdj_profiles, CDJ_REFERENCES, CLUB_PRIORITY
from players import player_profiles, PLAYER_REFERENCES, PLAYER_PRIORITY
from controllers import controller_profiles, controller_references
from ddj_family import ddj_profiles, ddj_references, PENDING_DDJ
from legacy_xdj import legacy_xdj_profiles, LEGACY_XDJ_REFERENCES
from entry import entry_profiles, entry_references
from opus import opus_profiles, OPUS_REFERENCES
from legacy_ddj import legacy_ddj_profiles, legacy_ddj_references
from s1 import s1_profiles, S1_REFERENCES
from legacy_systems import legacy_system_profiles, LEGACY_SYSTEM_REFERENCES
from numark import numark_profiles, numark_references, NUMARK_SOURCES
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
from report import report

ROOT = Path(__file__).resolve().parents[2]


class ConversionTests(unittest.TestCase):
    def control(self, key="play", group="[Channel3]", extra="", status="0x92", address="11"):
        return ET.fromstring(f"<control><group>{group}</group><key>{key}</key><status>{status}</status><midino>{address}</midino>{extra}</control>")

    def test_mixxx_rate_controls_translate_default_engine_direction_once(self):
        for extra, inverted in [("", True), ("<options><invert/></options>", False)]:
            record, reason = control_record(self.control("rate", "[Channel1]", extra, "0xB0", "13"))
            self.assertIsNone(reason)
            self.assertEqual(record["inverted"], inverted)
        for item in numark_profiles() + mixtrack3_profiles() + platinum_profiles():
            tempos = [binding for binding in item["inputs"] if binding["action"] in {"tempoA", "tempoB"}]
            self.assertTrue(tempos)
            self.assertTrue(all(not binding["inverted"] for binding in tempos))

    def test_four_deck_target(self):
        record, reason = control_record(self.control())
        self.assertIsNone(reason)
        self.assertEqual((record["action"], record["targetDeck"]), ("playA", "c"))

    def test_script_and_unknown_encoding_are_not_guessed(self):
        for option, expected in [("script-binding", "script-behaviour"), ("switch", "unsupported-encoding: switch")]:
            record, reason = control_record(self.control(extra=f"<options><{option}/></options>"))
            self.assertIsNone(record)
            self.assertEqual(reason, expected)

    def test_browser_requires_documented_relative_encoding(self):
        record, reason = control_record(self.control("MoveVertical", "[Library]", status="0xB0"))
        self.assertIsNone(record)
        self.assertEqual(reason, "unspecified-relative-encoding")
        record, _ = control_record(self.control("MoveVertical", "[Library]", "<options><selectknob/></options>", "0xB0"))
        self.assertEqual(record["encoding"], "twosComplement")

    def test_pair_requires_matching_group_and_control(self):
        high = ET.tostring(self.control("volume", "[Channel1]", "<options><fourteen-bit-msb/></options>", "0xB0", "0")).decode()
        low = ET.tostring(self.control("rate", "[Channel1]", "<options><fourteen-bit-lsb/></options>", "0xB0", "32")).decode()
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "fixture.midi.xml"
            path.write_text(f"<root><controller><controls>{high}{low}</controls></controller></root>")
            result = convert_xml(path)
            self.assertEqual(result["inputs"], [])
            self.assertEqual(result["inputRecords"][0]["disposition"], "missing-paired-low-byte")

    def test_conflicting_controls_are_removed_and_all_rows_are_accounted_for(self):
        controls = "".join(ET.tostring(self.control(key), encoding="unicode") for key in ["play", "pfl", "unknown"])
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "fixture.midi.xml"
            path.write_text(f"<root><controller><controls>{controls}</controls></controller></root>")
            result = convert_xml(path)
            self.assertEqual(result["inputs"], [])
            self.assertEqual(len(result["inputRecords"]), 3)
            self.assertEqual(result["inputRecords"][0]["disposition"], "conflicting-input-actions")

    def test_model_identity_preserves_plus_and_hardware_versions(self):
        self.assertNotEqual(canonical("Denon DJ PRIME 4+"), canonical("Denon PRIME 4"))
        self.assertNotEqual(canonical("DDJ-1000"), canonical("DDJ-1000SRT"))
        self.assertEqual(canonical("Vestax VCI-100MKII"), canonical("Vestax VCI-100 mk II"))
        self.assertEqual(canonical("Denon DJ MC4000"), canonical("Denon MC4000"))
        self.assertEqual(len(split_models("Mixars DUO (incl. MKII)")), 2)

    def test_curated_addresses_have_no_conflicts(self):
        for profile in curated_profiles() + cdj_profiles() + player_profiles() + controller_profiles() + ddj_profiles() + legacy_xdj_profiles() + entry_profiles() + opus_profiles() + legacy_ddj_profiles() + s1_profiles() + legacy_system_profiles() + numark_profiles() + mixtrack3_profiles() + platinum_profiles() + mixtrack2_profiles() + denon_profiles() + mc6000_profiles() + mc7000_profiles() + original_mixtrack_profiles() + party_mix_profiles() + t1_profiles() + pad_accessory_profiles():
            for left, right in combinations(profile["inputs"], 2):
                address = lambda item: (item["kind"], item["channel"], item["number"])
                if address(left) != address(right):
                    continue
                modes_differ = left.get("requiredMode") is not None and right.get("requiredMode") is not None and left["requiredMode"] != right["requiredMode"]
                shifts_differ = left.get("shifted") is not None and right.get("shifted") is not None and left["shifted"] != right["shifted"]
                self.assertTrue(modes_differ or shifts_differ, profile["id"])
            self.assertLessEqual(len(profile["inputs"]), 512)
            self.assertLessEqual(len(profile["outputs"]), 128)

    def test_club_players_use_only_reviewed_model_facts(self):
        profiles = {item["id"]: item for item in cdj_profiles()}
        self.assertEqual(set(profiles), set(CDJ_REFERENCES))
        for name, item in profiles.items():
            self.assertEqual(item["role"], "player")
            self.assertTrue(item["autoSelect"])
            self.assertTrue(all(binding["anyChannel"] for binding in item["inputs"]))
            self.assertEqual(item["outputs"], [])
        nxs = profiles["Pioneer CDJ-2000NXS"]
        self.assertEqual(len([item for item in nxs["inputs"] if item["action"].startswith("hotcue")]), 3)
        compact = profiles["Pioneer CDJ-900NXS"]
        self.assertFalse(any(item["action"].startswith(("hotcue", "seek", "tempoReset")) for item in compact["inputs"]))
        self.assertEqual(len(CDJ_REFERENCES["Pioneer CDJ-2000NXS2"]["sha256"]), 64)

    def test_earlier_players_retain_generation_specific_controls(self):
        profiles = {item["id"]: item for item in player_profiles()}
        self.assertEqual(set(profiles), set(PLAYER_REFERENCES))
        for name, item in profiles.items():
            self.assertTrue(item["autoSelect"])
            self.assertEqual(item["role"], "player")
            self.assertTrue(all(binding["anyChannel"] for binding in item["inputs"]))
        for model in ["CDJ-2000", "CDJ-900", "CDJ-850", "CDJ-400"]:
            self.assertFalse(any(item["action"] == "syncA" for item in profiles["Pioneer " + model]["inputs"]))
        cdj400 = profiles["Pioneer CDJ-400"]["inputs"]
        self.assertEqual(next(item["encoding"] for item in cdj400 if item["action"] == "browse"), "binaryOffset")
        cdj350 = profiles["Pioneer CDJ-350"]["inputs"]
        self.assertEqual(next(item["encoding"] for item in cdj350 if item["action"] == "jogA"), "cdj350PlatterSpeed")
        old = profiles["Pioneer XDJ-1000"]["inputs"]
        mk2 = profiles["Pioneer XDJ-1000MK2"]["inputs"]
        self.assertEqual(next(item["argument"] for item in old if item["number"] == 0x39), 2)
        self.assertEqual(next(item["argument"] for item in mk2 if item["number"] == 0x39), -1)
        self.assertFalse(any(item["number"] == 0x3A for item in mk2))

    def test_controller_systems_keep_model_specific_pad_and_mixer_facts(self):
        profiles = {item["id"]: item for item in controller_profiles()}
        self.assertEqual(set(profiles), set(controller_references()))
        for item in profiles.values():
            self.assertTrue(item["autoSelect"])
            self.assertFalse(item["startup"])
            self.assertEqual({entry["targetDeck"] for entry in item["inputs"] if "targetDeck" in entry}, set("abcd"))
        az = profiles["AlphaTheta XDJ-AZ"]["inputs"]
        self.assertEqual([(item["channel"], item["number"]) for item in az if item["action"] == "hotcue8A"], [(9, 57), (11, 57)])
        self.assertTrue(all(item["inverted"] for item in az if item["action"] in {"levelA", "levelB"}))
        rx3 = profiles["Pioneer XDJ-RX3"]["inputs"]
        self.assertFalse(any(item["action"].startswith(("tempoReset", "jump")) for item in rx3))
        flx6 = profiles["Pioneer DDJ-FLX6"]["inputs"]
        self.assertFalse(any(item["action"].startswith("keylock") for item in flx6))
        for name, reference in controller_references().items():
            self.assertEqual(len(reference["sha256"]), 64)
            document = ROOT / "TestBuilds/r178/manufacturer" / (name.split(" ", 1)[1] + ".pdf")
            if document.exists():
                self.assertEqual(hashlib.sha256(document.read_bytes()).hexdigest(), reference["sha256"])

    def test_ddj_family_preserves_factory_differences_and_ambiguous_controls(self):
        profiles = {item["id"]: item for item in ddj_profiles()}
        self.assertEqual(set(profiles), set(ddj_references()))
        original = profiles["Pioneer DDJ-SX"]
        self.assertFalse(any(item["action"] == "filterKnobB" and item["targetDeck"] == "d" for item in original["inputs"]))
        self.assertIn("CC32/64", original["gaps"][0])
        for name, item in profiles.items():
            self.assertTrue(item["autoSelect"])
            self.assertEqual({entry["channel"] for entry in item["inputs"] if entry["action"] == "openGroup" and entry["number"] == 65},
                             set(range(4)) if name.endswith(("DDJ-RZ", "DDJ-RZX")) else set() if name.endswith(("DDJ-SZ", "DDJ-SZ2", "1000SRT")) else {6})
            self.assertEqual(any(entry["action"] == "seekA" for entry in item["inputs"]), not name.endswith(("RZX", "1000SRT")))
            self.assertEqual(any(entry["action"] == "fixedLoopA" for entry in item["inputs"]), not name.endswith(("DDJ-SX", "DDJ-RZX", "DDJ-SZ", "1000SRT")))
        for name, source in ddj_references().items():
            document = ROOT / "TestBuilds/r179/manufacturer" / (name.split(" ", 1)[1] + ".pdf")
            if document.exists():
                self.assertEqual(hashlib.sha256(document.read_bytes()).hexdigest(), source["sha256"])
        self.assertNotIn("Pioneer DDJ-SR2", profiles)
        pending = PENDING_DDJ["Pioneer DDJ-SR2"]
        self.assertIn("bank", pending["gap"])
        document = ROOT / "TestBuilds/r179/manufacturer/DDJ-SR2.pdf"
        if document.exists():
            self.assertEqual(hashlib.sha256(document.read_bytes()).hexdigest(), pending["source"]["sha256"])

    def test_serato_and_rx_models_keep_generation_specific_facts(self):
        srt = next(item for item in ddj_profiles() if item["id"].endswith("1000SRT"))
        self.assertEqual([item["argument"] for item in srt["inputs"] if item["action"] in {"loopA", "loopB"}], [4] * 4)
        old = legacy_xdj_profiles()[0]
        self.assertFalse(old["autoSelect"])
        self.assertFalse(old["outputs"])
        self.assertFalse(any(item["action"].startswith("load") for item in old["inputs"]))
        self.assertEqual(next(item["encoding"] for item in old["inputs"] if item["action"] == "jogA"), "cdjPlatterSpeed")
        self.assertEqual(sum(item["action"].startswith("hotcue") for item in old["inputs"]), 16)
        references = {**ddj_references(), **controller_references(), **LEGACY_XDJ_REFERENCES}
        for name in ["DDJ-1000SRT", "DDJ-SZ", "DDJ-SZ2", "XDJ-RX", "XDJ-RX2"]:
            document = ROOT / "TestBuilds/r180/manufacturer" / (name + ".pdf")
            if document.exists():
                self.assertEqual(hashlib.sha256(document.read_bytes()).hexdigest(), references["Pioneer " + name]["sha256"])

    def test_entry_models_keep_deck_counts_initialisation_and_release_messages(self):
        profiles = {item["id"]: item for item in entry_profiles()}
        for name, item in profiles.items():
            decks = {entry["targetDeck"] for entry in item["inputs"] if "targetDeck" in entry}
            self.assertEqual(decks, set("abcd") if name.endswith(("DDJ-SB2", "DDJ-RR")) else set("ab"))
            self.assertEqual(item["startup"], [[0x9B, 9, 127]] if name.endswith(("DDJ-SB", "DDJ-SB2", "DDJ-RR")) else [])
            self.assertEqual(sum(entry.get("releaseOnly", False) for entry in item["inputs"]), len(decks) if name.endswith(("DDJ-SB", "DDJ-SB2")) else 0)
        small = profiles["Pioneer DDJ-200"]
        self.assertFalse(any(entry["action"].startswith(("load", "browse", "loop", "keylock", "gain")) for entry in small["inputs"]))
        wego = profiles["Pioneer DDJ-WeGO4"]
        self.assertFalse(any(entry["action"].startswith(("mid", "gain", "keylock")) for entry in wego["inputs"]))
        for name, source in entry_references().items():
            document = ROOT / "TestBuilds/r181/manufacturer" / (name.split(" ", 1)[1] + ".pdf")
            if document.exists():
                self.assertEqual(hashlib.sha256(document.read_bytes()).hexdigest(), source["sha256"])

    def test_opus_quad_retains_its_distinct_controls_and_source(self):
        item = opus_profiles()[0]
        self.assertEqual(item["startup"], [])
        self.assertEqual(item["shutdown"], [])
        for deck in "abcd":
            inputs = [binding for binding in item["inputs"] if binding.get("targetDeck") == deck]
            self.assertEqual([binding["number"] for binding in inputs if binding["action"].startswith("hotcue")], [8, 11, 13, 15, 21, 23, 25, 27])
            encoder = next(binding for binding in inputs if binding["action"].startswith("loopSize"))
            self.assertEqual((encoder["number"], encoder["encoding"]), (46, "twosComplement"))
        document = ROOT / "TestBuilds/r183/manufacturer/OPUS-QUAD.pdf"
        if document.exists():
            self.assertEqual(hashlib.sha256(document.read_bytes()).hexdigest(), OPUS_REFERENCES[item["id"]]["sha256"])

    def test_legacy_ddj_profiles_keep_generation_specific_controls(self):
        profiles = {item["id"]: item for item in legacy_ddj_profiles()}
        self.assertEqual(set(profiles), set(legacy_ddj_references()))
        for name, item in profiles.items():
            ergo, wego3 = name.endswith("ERGO"), name.endswith("WeGO3")
            self.assertEqual(item["startup"], [])
            self.assertEqual({binding["targetDeck"] for binding in item["inputs"] if "targetDeck" in binding}, set("ab" if wego3 else "abcd"))
            plays = [binding for binding in item["inputs"] if binding["action"].startswith("play")]
            self.assertTrue(all(binding["number"] == (8 if wego3 else 11) for binding in plays))
            jogs = [binding for binding in item["inputs"] if binding["action"] in {"jogA", "jogB"}]
            self.assertTrue(all(binding["encoding"] == ("twosComplement" if ergo else "binaryOffset") for binding in jogs))
            document = ROOT / "TestBuilds/r184/manufacturer" / (("DDJ-ERGO-V" if ergo else name.split(" ", 1)[1]) + ".pdf")
            if document.exists():
                self.assertEqual(hashlib.sha256(document.read_bytes()).hexdigest(), legacy_ddj_references()[name]["sha256"])

    def test_s1_preserves_paired_relative_jogs_and_distinct_global_channel(self):
        item = s1_profiles()[0]
        self.assertEqual(item["startup"], [])
        self.assertEqual(sum(binding["encoding"] == "paired14BitRelative" for binding in item["inputs"]), 8)
        self.assertEqual(sum(binding["action"].startswith("hotcue") for binding in item["inputs"]), 10)
        self.assertEqual({binding["channel"] for binding in item["inputs"] if binding["action"].startswith("gain")}, {4})
        document = ROOT / "TestBuilds/r184/manufacturer/DDJ-S1.pdf"
        if document.exists():
            self.assertEqual(hashlib.sha256(document.read_bytes()).hexdigest(), S1_REFERENCES[item["id"]]["sha256"])

    def test_legacy_systems_keep_their_deck_browsers_and_real_hot_cues(self):
        profiles = {item["id"]: item for item in legacy_system_profiles()}
        for name, item in profiles.items():
            self.assertEqual(item["startup"], [])
            self.assertEqual({binding["channel"] for binding in item["inputs"] if binding["action"] == "browse"}, set(range(4)))
            self.assertEqual(sum(binding["action"].startswith("hotcue") for binding in item["inputs"]), 12 if name.endswith("R1") else 0)
            self.assertEqual({binding["number"] for binding in item["inputs"] if binding["action"].startswith("load")}, {66})
            document = ROOT / "TestBuilds/r186/manufacturer" / (name.split(" ", 1)[1] + ".pdf")
            if document.exists():
                self.assertEqual(hashlib.sha256(document.read_bytes()).hexdigest(), LEGACY_SYSTEM_REFERENCES[name]["sha256"])

    def test_numark_fx_retains_model_specific_setup_and_source_hashes(self):
        for item in numark_profiles():
            platinum = "Platinum" in item["id"]
            self.assertTrue(item["definition"].startswith("reviewed:"))
            self.assertEqual(item["startup"][1][-2], 0x13 if platinum else 3)
            self.assertEqual(item["shutdown"], [[0xF0, 0, 0x20, 0x7F, 2, 0xF7]])
            self.assertEqual({binding["targetDeck"] for binding in item["inputs"] if "targetDeck" in binding}, set("abcd" if platinum else "ab"))
            self.assertEqual(sum(binding["action"].startswith("hotcue") for binding in item["inputs"]), 0 if platinum else 16)
            for path, digest in NUMARK_SOURCES[item["id"]]:
                source = ROOT / "TestBuilds/r169/upstream/res/controllers" / path
                if source.exists():
                    self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(), digest)

    def test_pro_fx_hot_cues_require_the_initial_mode_and_bounded_selectors(self):
        item = next(item for item in numark_profiles() if "Pro FX" in item["id"])
        self.assertEqual(len(item["startup"]), 15)
        self.assertEqual(len(item["inputModes"]), 2)
        for mode in item["inputModes"]:
            self.assertEqual((mode["initial"], mode["numbers"]), (0, [0, 13, 7, 11, 2, 15]))
            cues = [binding for binding in item["inputs"] if binding["channel"] == mode["channel"] and binding["action"].startswith("hotcue")]
            self.assertEqual([binding["number"] for binding in cues], list(range(20, 28)))
            self.assertTrue(all(binding["requiredMode"] == 0 for binding in cues))
        self.assertNotIn("inputModes", next(item for item in numark_profiles() if "Platinum" in item["id"]))

    def test_mixtrack3_models_keep_shared_facts_and_independent_shift_channels(self):
        profiles = mixtrack3_profiles()
        self.assertEqual({item["id"] for item in profiles}, set(mixtrack3_references()))
        self.assertEqual(profiles[0]["inputs"], profiles[1]["inputs"])
        for item in profiles:
            self.assertEqual(item["startup"], [[0x91, 6, 127], [0x92, 6, 127]])
            for binding in item["inputs"]:
                if "targetDeck" in binding:
                    self.assertFalse(binding["shifted"])
                    self.assertEqual(binding["shiftChannel"], 1 if binding["targetDeck"] == "a" else 2)
        for path, digest in MIXTRACK3_SOURCES:
            source = ROOT / "TestBuilds/r169/upstream/res/controllers" / path
            if source.exists():
                self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(), digest)

    def test_original_platinum_keeps_its_explicit_tempo_pair_and_jog_contract(self):
        item = platinum_profiles()[0]
        tempos = [binding for binding in item["inputs"] if binding["action"].startswith("tempo")]
        self.assertEqual(len(tempos), 4)
        self.assertTrue(all((binding["number"], binding["lowNumber"], binding["inverted"]) == (9, 119, False) for binding in tempos))
        self.assertEqual(sum(binding["encoding"] == "numarkPlatinumJog" for binding in item["inputs"]), 4)
        self.assertFalse(any(binding["action"].startswith("hotcue") for binding in item["inputs"]))
        for path, digest in PLATINUM_SOURCES:
            source = ROOT / "TestBuilds/r169/upstream/res/controllers" / path
            if source.exists():
                self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(), digest)

    def test_mixtrack2_family_retains_shared_channel_and_distinct_shift_layers(self):
        profiles = mixtrack2_profiles()
        self.assertEqual({item["id"] for item in profiles}, set(mixtrack2_references()))
        self.assertEqual(profiles[0]["inputs"], profiles[1]["inputs"])
        for item in profiles:
            self.assertTrue(all(binding["channel"] == 0 for binding in item["inputs"]))
            self.assertTrue(all(output["onValue"] == 100 for output in item["outputs"]))
            self.assertTrue(all(binding["inverted"] for binding in item["inputs"] if binding["action"] in {"tempoA", "tempoB"}))
            self.assertLessEqual(len(item["startup"] + item["shutdown"]), 16)
        for path, digest in MIXTRACK2_SOURCES:
            source = ROOT / "TestBuilds/r169/upstream/res/controllers" / path
            if source.exists():
                self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(), digest)

    def test_mc4000_retains_factory_addresses_and_records_the_pitch_conflict(self):
        item = denon_profiles()[0]
        self.assertEqual(item["aliases"], ["Denon MC4000", "MC4000", "Denon DJ MC4000"])
        self.assertTrue(all(binding["inverted"] for binding in item["inputs"] if binding["action"] in {"tempoA", "tempoB"}))
        self.assertFalse(any(binding["action"].startswith("hotcue") for binding in item["inputs"]))
        self.assertIn("LSB/MSB", denon_references()["Denon MC4000"]["review"])
        self.assertEqual(item["startup"][0], [240, 0, 2, 11, 127, 1, 96, 0, 4, 4, 1, 0, 0, 247])
        for path, digest in MC4000_SOURCES:
            source = ROOT / "TestBuilds/r169/upstream/res/controllers" / path
            if source.exists():
                self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(), digest)

    def test_mc6000_keeps_banked_channels_and_trigger_leds(self):
        item = mc6000_profiles()[0]
        self.assertEqual([(x["channel"], x["targetDeck"]) for x in item["inputs"] if x["action"] in {"playA", "playB"}], [(0, "a"), (1, "c"), (2, "b"), (3, "d")])
        self.assertEqual([x["shiftInput"] for x in item["inputs"] if x["action"] == "shift"], [0, 0, 1, 1])
        self.assertTrue(all(x["kind"] == "pitch" and x["inverted"] for x in item["inputs"] if x["action"] in {"tempoA", "tempoB"}))
        self.assertTrue(all(x["offNumber"] != x["number"] and x["onValue"] == x["offValue"] for x in item["outputs"]))
        self.assertEqual(item["startup"], [[176 + n, 74, 6] for n in range(4)])
        for path, digest in MC6000_SOURCES:
            source = ROOT / "TestBuilds/r169/upstream/res/controllers" / path
            if source.exists():
                self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(), digest)

    def test_mc7000_retains_the_pinned_jog_rule_and_explicit_tempo_pair(self):
        item = mc7000_profiles()[0]
        self.assertEqual([x["encoding"] for x in item["inputs"] if x["action"] in {"jogA", "jogB"}], ["mc7000Jog"] * 4)
        self.assertTrue(all(x["number"] == 9 and x["lowNumber"] == 119 and not x["inverted"] for x in item["inputs"] if x["action"] in {"tempoA", "tempoB"}))
        self.assertIn("0x64", MC7000_REFERENCES["Denon MC7000"]["review"])
        self.assertTrue(all(x["offValue"] == 1 for x in item["outputs"]))
        for path, digest in MC7000_SOURCES:
            source = ROOT / "TestBuilds/r169/upstream/res/controllers" / path
            if source.exists():
                self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(), digest)

    def test_original_mixtrack_profiles_keep_generation_and_source_differences(self):
        profiles = original_mixtrack_profiles()
        self.assertEqual({p["id"] for p in profiles}, set(ORIGINAL_MIXTRACK_SOURCES))
        self.assertEqual(profiles[0]["aliases"], ["Numark MIXTRACK"])
        for item in profiles:
            self.assertEqual([x["number"] for x in item["inputs"] if x["action"] in {"levelA", "levelB"}], [8, 9])
            self.assertEqual([x["number"] for x in item["inputs"] if x["action"] in {"jogTouchA", "jogTouchB"}], [78, 77])
            self.assertTrue(next(x for x in item["inputs"] if x["action"] == "crossfader")["inverted"])
            self.assertTrue(all(x["onValue"] == 100 for x in item["outputs"]))
            self.assertEqual([x["inverted"] for x in item["inputs"] if x["action"] in {"tempoA", "tempoB"}], [item["id"].endswith(" Pro")] * 2)
        for sources in ORIGINAL_MIXTRACK_SOURCES.values():
            for path, digest in sources:
                source = ROOT / "TestBuilds/r169/upstream/res/controllers" / path
                if source.exists():
                    self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(), digest)

    def test_party_mix_keeps_sensorless_wheels_and_mode_gated_four_cues(self):
        item = party_mix_profiles()[0]
        self.assertFalse(any(x["action"].startswith("jogTouch") for x in item["inputs"]))
        self.assertEqual([x["action"] for x in item["inputs"] if x["encoding"] == "twosComplement"], ["wheelJogA", "wheelJogB", "browse"])
        cues = [x for x in item["inputs"] if x["action"].startswith("hotcue")]
        self.assertEqual(len(cues), 8)
        self.assertTrue(all(x["requiredMode"] == 0 for x in cues))
        self.assertEqual(item["startup"][:4], [[176, 64, 0], [176, 66, 0], [176, 67, 0], [240, 0, 1, 63, 56, 72, 247]])
        self.assertEqual(len(item["startup"] + item["shutdown"]), 16)
        for path, digest in PARTY_MIX_SOURCES:
            source = ROOT / "TestBuilds/r169/upstream/res/controllers" / path
            if source.exists():
                self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(), digest)

    def test_t1_retains_its_factory_jog_and_global_mixer_channels(self):
        item = t1_profiles()[0]
        self.assertEqual([x["number"] for x in item["inputs"] if x["action"] == "jogA"], [1, 6, 1, 6])
        self.assertTrue(all(x["channel"] == 6 for x in item["inputs"] if x["action"] in {"syncA", "syncB", "loadA", "loadB", "cueA", "cueB"}))
        self.assertFalse(any(x["action"].startswith(("seek", "hotcue")) for x in item["inputs"]))
        self.assertTrue(all(x["channel"] < 4 for x in item["outputs"]))
        self.assertEqual(item["startup"], [])
        source = ROOT / "TestBuilds/r198/manufacturer/DDJ-T1.pdf"
        if source.exists():
            self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(), T1_REFERENCES["Pioneer DDJ-T1"]["sha256"])

    def test_pad_accessories_preserve_distinct_pad_layouts_and_source_roles(self):
        profiles = pad_accessory_profiles()
        self.assertEqual([x["role"] for x in profiles], ["accessory"] * 3)
        for item in profiles:
            cues = [x for x in item["inputs"] if x["action"].startswith("hotcue")]
            self.assertEqual(len(cues), 32)
            self.assertEqual([x["number"] for x in cues[:8]], [12, 13, 14, 15, 8, 9, 10, 11] if item["id"].endswith("XP2") else list(range(8)))
            self.assertEqual([cues[i * 8]["channel"] for i in range(4)], [7, 8, 9, 10] if item["id"].endswith("SP1") else [7, 9, 11, 13])
            self.assertFalse(any(x["action"].startswith(("play", "tempo", "level")) for x in item["inputs"]))
            self.assertEqual(item["startup"], [[155, 9, 127]] if item["id"].endswith("SP1") else [])
        for name, reference in PAD_REFERENCES.items():
            suffix = "-new" if name.endswith("XP2") else ""
            source = ROOT / "TestBuilds/r199/manufacturer" / (name.split(" ", 1)[1] + suffix + ".pdf")
            if source.exists():
                self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(), reference["sha256"])

    def test_ddj_application_connect_is_limited_to_reviewed_tables(self):
        expected = {"DDJ-SX", "DDJ-SX2", "DDJ-RX", "DDJ-RZ", "DDJ-RZX", "DDJ-SZ", "DDJ-SZ2"}
        for item in ddj_profiles():
            self.assertEqual(item["startup"], [[0x9B, 9, 127]] if item["id"].split(" ", 1)[1] in expected else [])
            self.assertEqual(item["shutdown"], [])
        self.assertTrue(all(not item["startup"] for item in controller_profiles()))

    def test_feedback_range_preserves_reverse_polarity_and_cc_lights(self):
        output = "<output><group>[Channel1]</group><key>play</key><status>0xB0</status><midino>11</midino><minimum>0</minimum><maximum>0.1</maximum><on>127</on><off>1</off></output>"
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "fixture.midi.xml"
            path.write_text(f"<root><controller><outputs>{output}</outputs></controller></root>")
            result = convert_xml(path)
            self.assertEqual(result["outputs"][0]["kind"], "control")
            self.assertEqual(result["outputs"][0]["onValue"], 1)
            self.assertEqual(result["outputs"][0]["offValue"], 127)

    def test_fetch_checks_git_identity_and_cache_boundaries(self):
        data = b"<root/>"
        entry = {"type": "blob", "path": "res/controllers/example.midi.xml", "sha": git_blob_hash(data)}
        with tempfile.TemporaryDirectory() as directory:
            result = fetch({"tree": [entry]}, "a" * 40, Path(directory), lambda _: data)
            self.assertEqual(result["files"][0]["sha256"], hashlib.sha256(data).hexdigest())
            with self.assertRaises(ValueError):
                fetch({"tree": [{**entry, "sha": "0" * 40}]}, "a" * 40, Path(directory), lambda _: data)
            with self.assertRaises(ValueError):
                fetch({"tree": [{**entry, "path": "res/controllers/../../../../escape.xml"}]}, "a" * 40, Path(directory), lambda _: data)

    def test_reviewed_handler_uses_native_target_and_encoding_without_execution(self):
        record, reason = control_record(self.control("DJCi200.scratchWheel", "[Channel2]",
            "<options><script-binding/></options>", "0xB2", "10"), REVIEWED["Hercules_DJControl_Inpulse_200.midi.xml"]["handlers"])
        self.assertIsNone(reason)
        self.assertEqual((record["action"], record["targetDeck"], record["encoding"]), ("jogB", "b", "twosComplement"))
        record, reason = control_record(self.control("DJCi200.scratchPad", extra="<options><script-binding/></options>"),
            REVIEWED["Hercules_DJControl_Inpulse_200.midi.xml"]["handlers"])
        self.assertIsNone(record)
        self.assertEqual(reason, "script-behaviour")

    def test_theoretical_completion_does_not_require_physical_evidence(self):
        definition = {"sourceInputCount": 1, "sourceOutputCount": 0, "inputRecords": [{"disposition": "mapped"}], "outputRecords": [], "unresolved": []}
        support = theoretical_support("automatic-core-profile", True, [definition], lifecycle_reviewed=True,
            audio_routing_implemented=True, protocol_fixture_complete=True)
        model = {"isPhysicalModel": True, "hardwareAcceptance": "not-verified", "theoreticalSupport": support}
        self.assertTrue(support["complete"])
        self.assertTrue(theoretical_gate([model])["complete"])
        self.assertFalse(support["completionRequiresPhysicalTest"])
        self.assertFalse(theoretical_gate([model])["requiresPhysicalTestForEveryModel"])

    def test_theoretical_completion_requires_actual_implementation_and_fixtures(self):
        support = theoretical_support("partial-midi-profile", True, [{"sourceInputCount": 1,
            "inputRecords": [{"disposition": "script-behaviour"}], "outputRecords": []}], lifecycle_reviewed=True,
            audio_routing_implemented=True, protocol_fixture_complete=True)
        self.assertFalse(support["complete"])
        self.assertIn("documentedControlsComplete", support["remainingWork"])


class GeneratedCatalogueTests(unittest.TestCase):
    def test_source_inventory_and_generated_data(self):
        cache = ROOT / "TestBuilds/r169/upstream"
        if not cache.exists():
            self.skipTest("Fetch the locked public reference cache before checking regeneration.")
        catalogue, runtime = build(cache, None)
        self.assertEqual(catalogue, json.loads((ROOT / "docs/coordination/controller-catalogue.json").read_text()))
        self.assertEqual(runtime, json.loads((ROOT / "Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json").read_text()))
        self.assertEqual(report(catalogue, runtime), (ROOT / "docs/coordination/controller-catalogue.md").read_text())
        model_ids = {model["id"] for model in catalogue["models"]}
        for row in catalogue["benchmarkRows"]:
            for name in split_models(row["name"]):
                self.assertIn(canonical(name), model_ids)
        for definition in catalogue["definitions"]:
            if definition["sourceInputCount"] is not None:
                self.assertEqual(len(definition["inputRecords"]), definition["sourceInputCount"])
                self.assertEqual(len(definition["outputRecords"]), definition["sourceOutputCount"])
        self.assertTrue(catalogue["releaseGate"]["catalogueComplete"])
        self.assertFalse(catalogue["releaseGate"]["hardwareParityAccepted"])
        self.assertTrue(all(not model["releaseReady"] for model in catalogue["models"]))
        self.assertFalse(catalogue["releaseGate"]["theoreticalSupport"]["requiresPhysicalTestForEveryModel"])
        club = sorted((model for model in catalogue["models"] if model["priority"]["clubImplementationOrder"]),
                      key=lambda model: model["priority"]["clubImplementationOrder"])
        self.assertEqual([model["id"] for model in club], [canonical(name) for name in CLUB_PRIORITY + PLAYER_PRIORITY])
        self.assertTrue(all(model["playerSupport"]["automaticDeckAssignment"] for model in club))
        self.assertTrue(all(not model["playerSupport"]["hidImplemented"] for model in club))
        self.assertTrue(all(not model["theoreticalSupport"]["complete"] for model in club))
        profiles = {profile["id"]: profile for profile in runtime["profiles"]}
        for model in ["Hercules DJControl Inpulse 200", "Hercules DJControl Inpulse 300", "Hercules DJControl Starlight"]:
            self.assertTrue(profiles[model]["autoSelect"])
            self.assertIn([0xB0, 127, 127], profiles[model]["startup"])
            self.assertTrue(any(item["action"] == "jogTouchB" for item in profiles[model]["inputs"]))


if __name__ == "__main__":
    unittest.main()
