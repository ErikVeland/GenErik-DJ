"""Focused checks for source identity, conversion and catalogue completeness."""
import hashlib
from itertools import combinations
import json
import plistlib
from pathlib import Path
import tempfile
import unittest
import xml.etree.ElementTree as ET

from build_catalogue import build
from report import report
from convert import control_record, convert_xml
from curated import curated_profiles
from fetch_reference import fetch, git_blob_hash
from sources import canonical, split_models
from reviewed import REVIEWED
from dj2go2 import dj2go2_profiles, DJ2GO2_SOURCES
from ns4fx import ns4fx_profiles, NS4FX_SOURCES
from mixstream import mixstream_profiles, MIXSTREAM_SOURCES
from flx10 import flx10_profiles, FLX10_REFERENCES
from ddj1000 import ddj1000_profiles, DDJ1000_REFERENCES
from manufacturer_inventory import MODELS as MANUFACTURER_MODELS
from jogvision import jogvision_profiles, JOGVISION_REFERENCES, JOGVISION_SOURCES
from inpulse300mk2 import inpulse300mk2_profiles, MK2_REFERENCES, MK2_SOURCES
from inpulse200mk2 import inpulse200mk2_profiles, INPULSE200_REFERENCES, INPULSE200_SOURCES
from beatmix import beatmix_profiles, BEATMIX_REFERENCES
from mc2000 import mc2000_profiles, MC2000_REFERENCES
from mixon4 import mixon4_profiles, MIXON4_REFERENCES
from dicer import dicer_profiles, DICER_SOURCES
from ns6ii import ns6ii_profiles, NS6II_SOURCES
from n4 import n4_profiles, N4_SOURCES
from neon import neon_profiles, NEON_REFERENCES
from vestax_compact import compact_profiles, COMPACT_SOURCES
from rp8000 import rp8000_profiles, RP8000_REFERENCES
from scratch import scratch_profiles, SCRATCH_SOURCES
from vci300 import vci300_profiles, VCI300_SOURCES
from vci100mk2 import vci100mk2_profiles, VCI100MK2_SOURCES
from hercules_portable import portable_profiles, PORTABLE_SOURCES
from inpulse200 import original200_profiles, ORIGINAL200_SOURCES
from vci400 import vci400_profiles, VCI400_SOURCES
from cmd_micro import cmd_micro_profiles, CMD_MICRO_SOURCES
from idj_live2 import idj_live2_profiles, IDJ2_SOURCES
from lc6000 import lc6000_profiles, LC6000_SOURCES
from vci100 import vci100_profiles, VCI100_SOURCES
from xone_k import xone_k_profiles, XONE_SOURCES
from ready import ready_profiles, READY_SOURCES
from mixer_one import mixer_one_profiles, MIXER_ONE_SOURCES
from umix_pro2 import umix_pro2_profiles, UMIX_PRO2_SOURCES
from instinct import instinct_profiles, INSTINCT_SOURCES
from hercules_compact import hercules_compact_profiles, HERCULES_COMPACT_SOURCES
from bcd3000 import bcd3000_profiles, BCD3000_SOURCES
from original_dj2go import original_dj2go_profiles, ORIGINAL_DJ2GO_SOURCES
from hercules_air import air_profiles, AIR_SOURCES
from sc2000 import sc2000_profiles, SC2000_SOURCES
from mixage import mixage_profiles, MIXAGE_SOURCES, MIXAGE_MODELS
from original300 import original300_profiles, ORIGINAL300_SOURCES
from total_omni import total_omni_profiles, TOTAL_OMNI_SOURCES
from xsession_pro import xsession_pro_profiles, XSESSION_SOURCES
from cmd_studio4a import studio4a_profiles, STUDIO4A_SOURCES
from stanton_djc4 import djc4_profiles, DJC4_SOURCES
from mc3000 import mc3000_profiles, MC3000_SOURCES
from rmx2 import rmx2_profiles, RMX2_SOURCES
from p32 import p32_profiles, P32_SOURCES
from kaoss_dj import kaoss_profiles, KAOSS_SOURCES
from firstmix import firstmix_profiles, FIRSTMIX_SOURCES
from ion_discover import discover_profiles, DISCOVER_SOURCES
from ion_discover_pro import discover_pro_profiles, DISCOVER_PRO_SOURCES
from djm101 import djm101_profiles, DJM101_SOURCES
from rdj2_ie import rdj2_ie_profiles, RDJ2_IE_SOURCES
from rdj2_controller import rdj2_controller_profiles, RDJ2_CONTROLLER_SOURCES
from radius2000 import radius_profiles, RADIUS_SOURCES, RADIUS_REFERENCES
from original_dj2go2 import original_dj2go2_profiles, ORIGINAL_DJ2GO2_ZIP_SHA, ORIGINAL_DJ2GO2_TSI_SHA
from terminal_mix8 import terminal_mix8_profiles, TM8_SOURCES
from mixtrack_quad import quad_profiles, QUAD_SOURCES
from imix_reload import imix_profiles, IMIX_SOURCES
from mcx8000 import mcx_profiles, MCX_SHA
from mix101 import mix101_profiles
from tek2 import tek2_profiles, TEK2_SOURCES
from kdj500 import kdj_profiles, KDJ_SOURCES
from umix_control2 import umix2_profiles, UMIX2_SHA
from original_umix_pro import original_umix_profiles, ORIGINAL_UMIX_SHA
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
from party_mix2 import party_mix2_profiles, PARTY2_REFERENCES, PARTY2_SOURCES
from terminal_mix import terminal_mix_profiles, terminal_mix_references, TERMINAL_MIX_SOURCES
from report import report

ROOT = Path(__file__).resolve().parents[2]


class ConversionTests(unittest.TestCase):
    def control(self, key="play", group="[Channel3]", extra="", status="0x92", address="11"):
        return ET.fromstring(f"<control><group>{group}</group><key>{key}</key><status>{status}</status><midino>{address}</midino>{extra}</control>")

    def test_ns6ii_preserves_source_pairs_resolution_and_usb_release_scopes(self):
        result = ns6ii_profiles()[0]
        self.assertEqual((len(result["inputs"]), len(result["outputs"])), (255, 12))
        self.assertEqual(len(result["bankChanges"]), 6)
        self.assertEqual([x.get("releaseShiftChannels") for x in result["bankChanges"][-2:]], [[0], [1]])
        self.assertTrue(all(row["encoding"] == "twosComplement" and row["argument"] == 1000 for row in result["inputs"] if row["action"] in {"jogA", "jogB"}))
        self.assertTrue(all(row["encoding"] == "paired14Bit" and row["number"] == 9 and not row["inverted"] for row in result["inputs"] if row["action"] in {"tempoA", "tempoB"}))
        self.assertTrue(all(row["requiredMode"] == 0 for row in result["inputs"] if row["action"].startswith("hotcue")))
        self.assertFalse(any(row["action"].startswith("hotcue") for row in result["outputs"]))
        for name, digest in NS6II_SOURCES:
            p = ROOT / "TestBuilds/r169/upstream/res/controllers" / name
            if p.exists():
                self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(), digest)

    def test_dicer_reuses_accessory_addresses_without_the_source_audio_effects(self):
        result = dicer_profiles()[0]
        self.assertEqual(result["role"], "accessory")
        self.assertEqual((len(result["inputs"]), len(result["outputs"])), (42, 20))
        self.assertEqual(result["startup"], [[186, 0, 0]])
        self.assertEqual(result["shutdown"], [[186, 0, 0]])
        self.assertEqual(sum(row.get("releaseOnly", False) for row in result["inputs"]), 10)
        self.assertFalse(any(row["channel"] in {11, 14} and row["number"] in range(60, 65) for row in result["inputs"]))
        for name, digest in DICER_SOURCES:
            p = ROOT / "TestBuilds/r169/upstream/res/controllers" / name
            if p.exists():
                self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(), digest)

    def test_mixon4_uses_separate_factory_channels_and_rgb_values(self):
        result = mixon4_profiles()[0]
        self.assertEqual((len(result["inputs"]), len(result["outputs"])), (154, 52))
        self.assertEqual(result["startup"], [[240, 0, 32, 127, 3, 1, 247]])
        self.assertEqual(len(result["bankChanges"]), 4)
        self.assertEqual({row["channel"] for row in result["inputs"] if row["action"] == "loadA"}, {4, 6})
        self.assertTrue(all(row["channel"] in {0, 1, 2, 3} and row["onValue"] == 3 and row["offValue"] == 67 for row in result["outputs"] if row["action"].startswith("hotcue")))
        self.assertFalse(any(row["action"] == "master" for row in result["inputs"]))
        self.assertTrue(all(row["encoding"] == "binaryStep" for row in result["inputs"] if row["action"] in {"loopSizeA", "loopSizeB"}))
        table = ROOT / "TestBuilds/r223/manufacturer/Mixon4-MIDI.pdf"
        if table.exists():
            self.assertEqual(hashlib.sha256(table.read_bytes()).hexdigest(), MIXON4_REFERENCES[result["id"]]["sha256"])

    def test_mc2000_factory_table_overrides_conflicting_community_entries(self):
        result = mc2000_profiles()[0]
        self.assertEqual((len(result["inputs"]), len(result["outputs"])), (55, 18))
        gain = next(row for row in result["inputs"] if row["action"] == "gainB")
        self.assertEqual((gain["channel"], gain["number"]), (1, 12))
        play = next(row for row in result["outputs"] if row["action"] == "playA")
        self.assertEqual((play["number"], play["offNumber"], play["onValue"], play["offValue"]), (74, 75, 39, 39))
        self.assertFalse(any(row["kind"] == "note" and row["number"] == 82 for row in result["inputs"]))
        self.assertTrue(all(row["encoding"] == "centredPitch" and row["inverted"] for row in result["inputs"] if row["action"] in {"tempoA", "tempoB"}))
        table = ROOT / "TestBuilds/r222/manufacturer/MC2000.pdf"
        if table.exists():
            self.assertEqual(hashlib.sha256(table.read_bytes()).hexdigest(), MC2000_REFERENCES[result["id"]]["sha256"])

    def test_beatmix_factory_facts_resolve_script_jog_and_led_address_differences(self):
        result = beatmix_profiles()[0]
        self.assertEqual((len(result["inputs"]), len(result["outputs"])), (148, 28))
        self.assertEqual(len(result["bankChanges"]), 4)
        jogs = [row for row in result["inputs"] if row["action"] in {"jogA", "jogB"}]
        self.assertTrue(all(row["encoding"] == "twosComplement" and row["argument"] == 800 for row in jogs))
        self.assertEqual({row["number"] for row in result["outputs"] if row["action"] in {"playA", "playB"}}, {35})
        self.assertEqual({row["number"] for row in result["inputs"] if row["action"] in {"playA", "playB"} and not row.get("releaseOnly")}, {36})
        self.assertEqual({row["number"] for row in result["outputs"] if row["action"] in {"syncA", "syncB"}}, {32})
        table = ROOT / "TestBuilds/r221/manufacturer/Beatmix-2-4-MIDI.pdf"
        if table.exists():
            self.assertEqual(hashlib.sha256(table.read_bytes()).hexdigest(), BEATMIX_REFERENCES[result["id"]]["sha256"])
        self.assertTrue(all(canonical(name) in {canonical(alias) for alias in result["aliases"]} for name in split_models(result["id"])))

    def test_inpulse200mk2_preserves_published_pad_pages_and_physical_two_band_eq(self):
        result = inpulse200mk2_profiles()[0]
        self.assertEqual((len(result["inputs"]), len(result["outputs"])), (57, 16))
        self.assertEqual(result["startup"], [])
        self.assertFalse(any(row["action"] in {"midA", "midB"} for row in result["inputs"]))
        self.assertEqual(sum(row.get("releaseOnly", False) for row in result["inputs"]), 8)
        tempos = [row for row in result["inputs"] if row["action"] in {"tempoA", "tempoB"}]
        self.assertTrue(all(row["encoding"] == "centreDetent" and row["inverted"] and row["shifted"] is False for row in tempos))
        self.assertTrue(all("argument" not in row for row in result["inputs"] if row["action"] in {"jogA", "jogB"}))
        cache = ROOT / "TestBuilds/r220/upstream"
        for name, (_, digest) in zip(["controller_notes.py", "jog_incremental.py", "tempo_reverse.py", "main-buttons.csv"], INPULSE200_SOURCES):
            if (cache / name).exists():
                self.assertEqual(hashlib.sha256((cache / name).read_bytes()).hexdigest(), digest)
        mapping = cache / "Inpulse-200-MK2.djayMidiMapping"
        if mapping.exists():
            import plistlib
            self.assertEqual(hashlib.sha256(mapping.read_bytes()).hexdigest(), INPULSE200_REFERENCES[result["id"]]["sha256"])
            controls = plistlib.loads(mapping.read_bytes())["controls"]
            self.assertTrue(any(row["keyPath"] == "turntable1.speed" and row["midiChannel"] == 1 and row["midiData"] == 8 and row["flipped"] for row in controls))
            self.assertTrue(any(row["keyPath"] == "turntable1.clearCuePoint1" and row["midiChannel"] == 6 and row["midiData"] == 8 for row in controls))

    def test_report_separates_factory_models_from_native_adapters(self):
        models = []
        for route, physical, automatic in [("automatic-profile", True, True),
                                            ("automatic-core-profile", True, True),
                                            ("native-accessory", True, True),
                                            ("partial-midi-profile", True, False),
                                            ("protocol-needed", False, True)]:
            models.append({"name": route, "implementation": route, "isPhysicalModel": physical,
                           "zeroConfig": {"automaticControls": automatic}, "priority": {},
                           "benchmark": False, "role": "primary", "sources": ["fixture"]})
        text = report({"models": models, "definitions": [], "benchmarkRows": [], "upstreamRevision": "fixture"},
                      {"profiles": [{"autoSelect": True}, {"autoSelect": False}]})
        self.assertIn("plus 1 existing code profiles", text)
        self.assertIn("2 factory profiles select core controls automatically for 2 physical models", text)
        self.assertIn("Existing native adapters provide automatic core controls for 1 other models", text)

    def test_inpulse300mk2_preserves_core_facts_without_ambiguous_pad_assignments(self):
        result = inpulse300mk2_profiles()[0]
        self.assertEqual(len(result["inputs"]), 47)
        self.assertEqual(len(result["outputs"]), 10)
        self.assertTrue(all(row.get("targetDeck") in {None, "a", "b"} for row in result["inputs"]))
        self.assertFalse(any(row["channel"] in {6, 7} for row in result["inputs"]))
        self.assertEqual([row["argument"] for row in result["inputs"] if row["action"] == "jogA"], [248, 62])
        cache = ROOT / "TestBuilds/r219/upstream"
        for name, (_, digest) in zip(["inpulse300mk2.xml", "inpulse300mk2.js"], MK2_SOURCES):
            if (cache / name).exists():
                self.assertEqual(hashlib.sha256((cache / name).read_bytes()).hexdigest(), digest)
        table = ROOT / "TestBuilds/r219/manufacturer/Inpulse-300-MK2.pdf"
        if table.exists():
            self.assertEqual(hashlib.sha256(table.read_bytes()).hexdigest(), MK2_REFERENCES[result["id"]]["relatedSources"][-1]["sha256"])

    def test_jogvision_uses_factory_setup_and_source_derived_jog_resolution(self):
        result = jogvision_profiles()[0]
        self.assertEqual(len(result["inputs"]), 61)
        self.assertEqual(len(result["outputs"]), 26)
        self.assertEqual(result["startup"], [[0xB0, 126, 127], [0x90, 70, 127], [0xB0, 127, 127]])
        self.assertEqual(result["shutdown"], [[0xB0, 126, 0], [0x90, 70, 0]])
        self.assertEqual([row["number"] for row in result["inputs"] if row["action"] == "shift"], [86, 87, 86, 87])
        self.assertTrue(all(row["argument"] == 400 for row in result["inputs"] if row["action"] in {"jogA", "jogB", "wheelJogA", "wheelJogB"}))
        cache = ROOT / "TestBuilds/r169/upstream/res/controllers"
        for name, digest in JOGVISION_SOURCES:
            if (cache / name).exists():
                self.assertEqual(hashlib.sha256((cache / name).read_bytes()).hexdigest(), digest)
        table = ROOT / "TestBuilds/r218/manufacturer/Jogvision-MIDI.pdf"
        if table.exists():
            self.assertEqual(hashlib.sha256(table.read_bytes()).hexdigest(), JOGVISION_REFERENCES[result["id"]]["sha256"])

    def test_original_ddj1000_uses_its_own_factory_addresses_and_bank_events(self):
        result = ddj1000_profiles()[0]
        self.assertEqual(result["id"], "DDJ-1000")
        self.assertEqual(len(result["inputs"]), 125)
        self.assertEqual(len(result["outputs"]), 48)
        self.assertEqual([(row["channel"], row["number"]) for row in result["bankChanges"]], [(2, 114), (3, 114)])
        for action, number in [("syncA", 88), ("tempoA", 0), ("toggleFixedLoopA", 20)]:
            self.assertTrue(any(row["action"] == action and row["number"] == number
                                and row["targetDeck"] == "a" and row["shifted"] is False for row in result["inputs"]))
        self.assertNotIn("DDJ-1000SRT", result["aliases"])
        root = Path(__file__).resolve().parents[2] / "TestBuilds/r215/manufacturer"
        for name, reference in [("DDJ-1000.pdf", DDJ1000_REFERENCES["DDJ-1000"]),
                                ("DDJ-1000-diagram.pdf", DDJ1000_REFERENCES["DDJ-1000"]["relatedSources"][0])]:
            if (root / name).exists():
                self.assertEqual(hashlib.sha256((root / name).read_bytes()).hexdigest(), reference["sha256"])

    def test_flx10_migration_preserves_identity_and_tracks_the_factory_tables(self):
        result = flx10_profiles()[0]
        self.assertEqual(result["id"], "DDJ-FLX10")
        self.assertEqual(result["catalogueName"], "Pioneer DDJ-FLX10")
        self.assertEqual(len(result["inputs"]), 145)
        self.assertEqual(len(result["outputs"]), 44)
        self.assertEqual([row["channel"] for row in result["bankChanges"]], [0, 1, 2, 3])
        self.assertEqual([row["shiftInput"] for row in result["inputs"] if row["action"] == "shift"], [0, 1, 0, 1])
        self.assertEqual({row["argument"] for row in result["inputs"] if row["action"].startswith("fixedJump")}, {-16, -4, 4, 16})
        root = Path(__file__).resolve().parents[2] / "TestBuilds/r214/manufacturer"
        for name, reference in [("DDJ-FLX10.pdf", FLX10_REFERENCES["DDJ-FLX10"]),
                                ("DDJ-FLX10-diagram.pdf", FLX10_REFERENCES["DDJ-FLX10"]["relatedSources"][0])]:
            if (root / name).exists():
                self.assertEqual(hashlib.sha256((root / name).read_bytes()).hexdigest(), reference["sha256"])

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
        for profile in curated_profiles() + cdj_profiles() + player_profiles() + controller_profiles() + ddj_profiles() + legacy_xdj_profiles() + entry_profiles() + opus_profiles() + legacy_ddj_profiles() + s1_profiles() + legacy_system_profiles() + numark_profiles() + mixtrack3_profiles() + platinum_profiles() + mixtrack2_profiles() + denon_profiles() + mc6000_profiles() + mc7000_profiles() + original_mixtrack_profiles() + party_mix_profiles() + t1_profiles() + pad_accessory_profiles() + party_mix2_profiles() + terminal_mix_profiles():
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
                self.assertEqual(hashlib.sha256(document.read_bytes()).hexdigest(), references["Pioneer " + name + (" legacy 7-bit" if name == "XDJ-RX" else "")]["sha256"])

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

    def test_party_mix2_separates_original_facts_and_pins_external_protocol_sources(self):
        original = party_mix_profiles()[0]
        item = party_mix2_profiles()[0]
        self.assertEqual(original["inputModes"][0]["numbers"], [0, 11, 14, 24])
        self.assertEqual(item["inputModes"][0]["numbers"], [0, 11, 14, 15])
        self.assertEqual([x["number"] for x in item["inputs"] if x["action"] == "openGroup"], [7])
        self.assertEqual([x["number"] for x in item["inputs"] if x["action"].startswith("jogTouch")], [6, 6])
        self.assertTrue(all(x["shifted"] is False for x in item["inputs"] if x["action"].startswith("hotcue")))
        self.assertEqual(len(item["startup"] + item["shutdown"]), 15)
        self.assertIn("AI-assisted", PARTY2_REFERENCES["Numark Party Mix II"]["review"])
        for path, _, digest in PARTY2_SOURCES:
            source = ROOT / "TestBuilds/r200/upstream" / path
            if source.exists():
                self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(), digest)

    def test_native_loop_pads_keep_model_specific_modes_and_sizes(self):
        cases = [(party_mix_profiles()[0], 11, [4, 8, 16, 32]),
                 (party_mix2_profiles()[0], 14, [2, 4, 8, 16]),
                 (next(p for p in numark_profiles() if p["id"] == "Numark Mixtrack Pro FX"), 13, [0.0625, 0.125, 0.25, 0.5, 1, 2, 4, 8])]
        for item, mode, sizes in cases:
            for channel in [4, 5]:
                loops = [x for x in item["inputs"] if x["action"].startswith("toggleFixedLoop") and x["channel"] == channel]
                self.assertEqual([x["argument"] for x in loops], sizes)
                self.assertEqual([x["requiredMode"] for x in loops], [mode] * len(sizes))
                self.assertEqual([x["number"] for x in loops], list(range(20, 20 + len(sizes))))
        self.assertFalse(any(x["action"].startswith("toggleFixedLoop") for x in next(p for p in numark_profiles() if p["id"] == "Numark Mixtrack Platinum FX")["inputs"]))

    def test_terminal_mix_replaces_the_shared_recipe_and_retains_exact_source_helpers(self):
        profiles = terminal_mix_profiles()
        self.assertEqual({p["id"] for p in profiles}, set(terminal_mix_references()))
        for item in profiles:
            self.assertEqual([x["encoding"] for x in item["inputs"] if x["action"].startswith("tempo")], ["centredPitch"] * 4)
            self.assertEqual(len([x for x in item["inputs"] if x["action"].startswith("hotcue")]), 32)
            self.assertEqual([x["encoding"] for x in item["inputs"] if x["action"].startswith("loopSize")], ["binaryStep"] * 4)
            self.assertEqual(len(item["shutdown"]), 16)
        for path, digest in TERMINAL_MIX_SOURCES:
            source = ROOT / "TestBuilds/r169/upstream/res/controllers" / path
            if source.exists():
                self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(), digest)

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


    def test_reviewed_numark_browser_rejects_non_library_groups(self):
        handlers = REVIEWED["Numark Total Control.midi.xml"]["handlers"]
        record, reason = control_record(self.control("NumarkTotalControl.selectKnob", "[Playlist]",
            "<options><script-binding/></options>", "0xB0", "26"), handlers)
        self.assertIsNone(reason)
        self.assertEqual(record["action"], "browse")
        self.assertEqual(record["encoding"], "twosComplement")
        for group in ["[Master]", "[Channel1]"]:
            record, reason = control_record(self.control("NumarkTotalControl.selectKnob", group,
                "<options><script-binding/></options>", "0xB0", "26"), handlers)
            self.assertIsNone(record)
            self.assertEqual(reason, "unsupported-script-target")

    def test_reviewed_numark_models_retain_opposite_jog_addresses(self):
        cache = ROOT / "TestBuilds/r169/upstream/res/controllers"
        if not cache.exists():
            self.skipTest("Fetch the locked public reference cache before checking mappings.")
        for model, numbers in [("Total", [25, 24]), ("Omni", [24, 25])]:
            filename = f"Numark {model} Control.midi.xml"
            result = convert_xml(cache / filename, REVIEWED[filename]["handlers"])
            jogs = sorted((i for i in result["inputs"] if i["action"].startswith("wheelJog")), key=lambda i: i["action"])
            self.assertEqual([i["number"] for i in jogs], numbers)
            self.assertTrue(all(i["argument"] == 128 and i["encoding"] == "twosComplement" for i in jogs))
            unresolved = {r["key"] for r in result["inputRecords"] if r["disposition"] != "mapped"}
            self.assertIn("NumarkTotalControl.toggleScratchMode", unresolved)
            self.assertNotIn("NumarkTotalControl.playFromCue", unresolved)


    def test_mix_shifted_wheel_uses_script_channel_routing_and_resolution(self):
        handlers = REVIEWED["Hercules DJControl MIX.midi.xml"]["handlers"]
        for status, deck, action in [("0xB4", "a", "jogA"), ("0xB5", "b", "jogB")]:
            record, reason = control_record(self.control("DJCMIX.scratchWheelShift", "[Channel1]",
                "<options><script-binding/></options>", status, "10"), handlers)
            self.assertIsNone(reason)
            self.assertEqual(record["targetDeck"], deck)
            self.assertEqual(record["action"], action)
            self.assertEqual(record["argument"], 62)
        record, reason = control_record(self.control("DJCMIX.scratchWheelShift", "[Channel1]",
            "<options><script-binding/></options>", "0xB3", "10"), handlers)
        self.assertIsNone(record)
        self.assertEqual(reason, "unsupported-script-target")


    def test_dj2go2_touch_retains_sources_and_disjoint_pad_ranges(self):
        cache = ROOT / "TestBuilds/r169/upstream/res/controllers"
        if not cache.exists():
            self.skipTest("Fetch the locked public reference cache before checking sources.")
        for path, digest in DJ2GO2_SOURCES:
            self.assertEqual(hashlib.sha256((cache / path).read_bytes()).hexdigest(), digest)
        profile = dj2go2_profiles()[0]
        self.assertEqual(len(profile["startup"]) + len(profile["shutdown"]), 15)
        self.assertFalse(any(i["action"] in {"levelA", "levelB", "filterKnobA", "filterKnobB"} for i in profile["inputs"]))
        for deck in "ab":
            inputs = [i for i in profile["inputs"] if i.get("targetDeck") == deck]
            self.assertEqual([i["number"] for i in inputs if i["action"].startswith("hotcue")], [1, 2, 3, 4])
            self.assertEqual([i["argument"] for i in inputs if i["action"].startswith("toggleFixedLoop")], [1, 2, 4, 8])
            self.assertFalse(any(i["channel"] in {4, 5} and i["number"] in {9, 10, 11, 12, 36} for i in inputs))


    def test_standard_cue_preview_requires_note_release_semantics(self):
        for status, opts, expected in [("0x90", "", "cuePreviewA"), ("0x80", "", "cuePreviewA"),
                ("0xB0", "", "cueReturnA"), ("0x90", "<options><invert/></options>", "cueReturnA")]:
            record, reason = control_record(self.control("cue_default", "[Channel1]", opts, status, "1"))
            self.assertIsNone(reason)
            self.assertEqual(record["action"], expected)


    def test_ns4fx_core_keeps_bank_scopes_and_pinned_facts(self):
        cache = ROOT / "TestBuilds/r169/upstream/res/controllers"
        if not cache.exists():
            self.skipTest("Fetch the locked public reference cache before checking sources.")
        for path, digest in NS4FX_SOURCES:
            self.assertEqual(hashlib.sha256((cache / path).read_bytes()).hexdigest(), digest)
        profile = ns4fx_profiles()[0]
        self.assertEqual([i["decks"] for i in profile["bankChanges"]], [["a", "c"], ["b", "d"], ["a", "c"], ["b", "d"]])
        self.assertEqual(len(profile["inputs"]), 64)
        self.assertEqual(len(profile["startup"]) + len(profile["shutdown"]), 9)
        self.assertTrue(all(i["argument"] == 1240 for i in profile["inputs"] if i["action"] in {"jogA", "jogB"}))
        self.assertFalse(any(i["action"].startswith("hotcue") for i in profile["inputs"]))


    def test_mc7000_bank_reports_and_shift_aliases_follow_physical_sides(self):
        item = mc7000_profiles()[0]
        shifts = [i for i in item["inputs"] if i["action"] == "shift"]
        self.assertEqual([(i["channel"], i["shiftChannel"], i["shiftInput"]) for i in shifts],
                         [(0, 0, 0), (1, 1, 1), (2, 0, 0), (3, 1, 1)])
        self.assertEqual([b["decks"] for b in item["bankChanges"]], [["a", "c"], ["b", "d"], ["a", "c"], ["b", "d"]])
        self.assertTrue(all(b["number"] == 8 and b["onValue"] == 127 for b in item["bankChanges"]))


    def test_mixstream_pro_uses_explicit_counter_and_pitch_pairs(self):
        cache = ROOT / "TestBuilds/r169/upstream/res/controllers"
        if not cache.exists():
            self.skipTest("Fetch the locked public reference cache before checking sources.")
        for path, digest in MIXSTREAM_SOURCES:
            self.assertEqual(hashlib.sha256((cache / path).read_bytes()).hexdigest(), digest)
        item = mixstream_profiles()[0]
        self.assertEqual(len(item["inputs"]), 36)
        self.assertEqual([(i["channel"], i["number"], i["lowNumber"], i["argument"]) for i in item["inputs"] if i["action"] in {"jogA", "jogB"}],
                         [(2, 55, 77, 180), (3, 55, 77, 180)])
        self.assertTrue(all(i["number"] == 31 and i["lowNumber"] == 75 and i["inverted"] for i in item["inputs"] if i["action"] in {"tempoA", "tempoB"}))
        self.assertEqual(item["startup"], [])
        self.assertFalse(any("Pro+" in alias or "Go" in alias for alias in item["aliases"]))


class GeneratedCatalogueTests(unittest.TestCase):
    def test_mixtour_generation_keeps_transport_cues_and_pro_identity_separate(self):
        runtime = json.loads((ROOT / "Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json").read_text())
        item = next((row for row in runtime["profiles"] if row["id"] == "Reloop Mixtour"), None)
        self.assertIsNotNone(item, "Original Mixtour needs its own factory recipe")
        self.assertTrue(item["autoSelect"])
        self.assertIn("Mixtour Pro", item["excludedAliases"])
        normal = [r for r in item["inputs"] if not r.get("releaseOnly")]
        self.assertEqual([(r["channel"], r["number"], r["targetDeck"]) for r in normal if r["action"] in {"playA", "playB"}],
                         [(0, 12, "a"), (1, 12, "b")])
        self.assertEqual([r["number"] for r in normal if r["action"] in {"cuePreviewA", "cuePreviewB"}], [11, 11])
        self.assertEqual([r["number"] for r in normal if r["action"].startswith("hotcue")], [13, 14, 15, 16] * 2)
        self.assertEqual(next(r["encoding"] for r in normal if r["action"] == "browse"), "twosComplement")
        self.assertLessEqual(len(item["startup"]) + len(item["shutdown"]), 64)
        self.assertNotIn("audioOutput", item)
        from mixtour import MIXTOUR_SOURCES
        for name, digest in MIXTOUR_SOURCES:
            path = ROOT / "TestBuilds/r289/manufacturer" / name
            if path.exists():
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), digest)

    def test_new_public_mapping_audits_do_not_claim_missing_native_custom_classes(self):
        from manufacturer_inventory import SOURCE_AUDITS
        expected = {"Hercules DJControl Inpulse T7": ("t7-mapping.xml", 402, 2, "HerculesDJControlInpulseT7"),
                    "Reloop Mixon 8 Pro": ("mixon8-sj1.djayMidiMapping", 895, 24, "ReloopMixon8")}
        catalogue = json.loads((ROOT / "docs/coordination/controller-catalogue.json").read_text())
        for name, (filename, controls, outputs, custom_class) in expected.items():
            audit = SOURCE_AUDITS[name]
            self.assertEqual((audit["inputRows"], audit["outputRows"], audit["declaredCustomClass"]), (controls, outputs, custom_class))
            self.assertFalse(audit["automaticSupportAdded"])
            model = next(row for row in catalogue["models"] if row["name"] == name)
            self.assertFalse(model["zeroConfig"]["automaticControls"])
            self.assertFalse(model["theoreticalSupport"]["complete"])
            self.assertIn(audit, model["sourceAudits"])
            path = ROOT / "TestBuilds/r286/manufacturer" / filename
            if path.exists():
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), audit["source"]["sha256"])
                data = plistlib.loads(path.read_bytes())
                self.assertEqual((len(data["controls"]), len(data["outputs"]), data["customClassName"]), (controls, outputs, custom_class))

    def test_original_umix_pro_retains_factory_touch_rim_load_and_split_audio(self):
        item, = original_umix_profiles()
        self.assertTrue(item["autoSelect"])
        self.assertEqual((len(item["inputs"]), len(item["outputs"])), (91, 28))
        self.assertEqual(len(item["startup"]) + len(item["shutdown"]), 62)
        self.assertEqual(item["audioOutput"], "masterAndHeadphones")
        self.assertEqual(next((r["kind"], r["number"]) for r in item["inputs"] if r["action"] == "loadA"), ("control", 5))
        self.assertEqual([r["number"] for r in item["inputs"] if r["action"].startswith("wheelJog")], [23, 23])
        self.assertTrue(all(r.get("requiresTouch") and "argument" not in r for r in item["inputs"] if r["action"] in {"jogA", "jogB"}))
        path = ROOT / "TestBuilds/r286/manufacturer/umix-pro-hardware-guide.pdf"
        if path.exists():
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), ORIGINAL_UMIX_SHA)

    def test_umix_control2_non_touch_core_uses_factory_loop_and_separate_source_load(self):
        item, = umix2_profiles()
        self.assertTrue(item["autoSelect"])
        self.assertEqual((len(item["inputs"]), len(item["outputs"])), (84, 28))
        self.assertEqual(len(item["startup"]) + len(item["shutdown"]), 62)
        self.assertFalse(any(r["action"].startswith("jogTouch") for r in item["inputs"]))
        self.assertEqual([(r["kind"], r["number"]) for r in item["inputs"] if r["action"].startswith("load") and not r.get("releaseOnly")], [("note", 5), ("note", 6)])
        self.assertEqual([r["number"] for r in item["inputs"] if r["action"].startswith("hotcue6")], [26, 26, 26, 127, 26, 127])
        self.assertNotIn("audioOutput", item)
        path = ROOT / "TestBuilds/r169/upstream/res/controllers/MixVibes U-Mix Control 2.midi.xml"
        if path.exists():
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), UMIX2_SHA)

    def test_kdj500_translated_midi_core_preserves_strict_inverted_encoder_rule(self):
        item, = kdj_profiles()
        self.assertFalse(item["autoSelect"])
        self.assertEqual((len(item["inputs"]), len(item["outputs"])), (27, 0))
        self.assertEqual(item["startup"] + item["shutdown"], [])
        self.assertEqual([(r["number"], r["inverted"]) for r in item["inputs"] if r["encoding"] == "signedStep"], [(40, True), (42, True), (44, True), (46, True)])
        self.assertEqual([r["argument"] for r in item["inputs"] if r["action"].startswith("toggleFixedLoop")], [8, 8])
        self.assertEqual([r["targetDeck"] for r in item["inputs"] if r["action"].startswith("load")], ["a", "b"])
        for name, digest in KDJ_SOURCES:
            path = ROOT / "TestBuilds/r169/upstream/res/controllers" / name
            if path.exists():
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), digest)

    def test_tek2_keeps_required_preset_manual_with_separate_touch_and_wheel_paths(self):
        item, = tek2_profiles()
        self.assertFalse(item["autoSelect"])
        self.assertEqual((len(item["inputs"]), len(item["outputs"])), (10, 0))
        self.assertEqual(item["startup"] + item["shutdown"], [])
        self.assertEqual([r["argument"] for r in item["inputs"] if r.get("requiresTouch")], [100, 100])
        self.assertEqual([r["argument"] for r in item["inputs"] if r["action"].startswith("wheelJog")], [160, 160])
        self.assertEqual([r["number"] for r in item["inputs"] if r["encoding"] == "fullVelocityGate"], [40, 41])
        for name, digest in TEK2_SOURCES:
            path = ROOT / "TestBuilds/r169/upstream/res/controllers" / name
            if path.exists():
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), digest)

    def test_mix101_source_encoders_and_distinct_play_led_stay_manual(self):
        item, = mix101_profiles()
        self.assertFalse(item["autoSelect"])
        self.assertEqual((len(item["inputs"]), len(item["outputs"])), (22, 4))
        self.assertEqual(len(item["startup"]) + len(item["shutdown"]), 8)
        self.assertEqual([(r["action"], r["number"]) for r in item["inputs"] if r["encoding"] == "rot64Fast"], [("monitor", 16), ("master", 18)])
        self.assertEqual(next(r["number"] for r in item["inputs"] if r["action"] == "playA"), 9)
        self.assertEqual(next(r["number"] for r in item["outputs"] if r["action"] == "playA"), 10)
        self.assertFalse(any(r["action"].startswith(("hotcue", "jogTouch", "tempo", "load")) for r in item["inputs"]))

    def test_mcx8000_factory_subset_keeps_unqualified_encoders_pads_and_connection_manual(self):
        item, = mcx_profiles()
        self.assertFalse(item["autoSelect"])
        self.assertEqual((len(item["inputs"]), len(item["outputs"])), (99, 24))
        self.assertEqual(len(item["startup"]) + len(item["shutdown"]), 48)
        self.assertNotIn("audioOutput", item)
        self.assertFalse(any(r["action"].startswith(("jog", "wheelJog", "tempo", "hotcue", "browse")) for r in item["inputs"]))
        self.assertEqual(sum(r.get("releaseOnly", False) for r in item["inputs"]), 12)
        self.assertEqual([r["targetDeck"] for r in item["inputs"] if r["action"].startswith("load")], list("abcd"))
        path = ROOT / "TestBuilds/r282/manufacturer/mcx8000-midi-v1.pdf"
        if path.exists():
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), MCX_SHA)

    def test_imix_source_variant_stays_manual_with_strict_note_encoder_contract(self):
        item, = imix_profiles()
        self.assertFalse(item["autoSelect"])
        self.assertEqual((len(item["inputs"]), len(item["outputs"])), (55, 16))
        self.assertEqual(len(item["startup"]) + len(item["shutdown"]), 54)
        self.assertNotIn("audioOutput", item)
        self.assertEqual([r["number"] for r in item["inputs"] if r["action"] in {"loadA", "loadB"}], [40, 46])
        steps = [r for r in item["inputs"] if r["encoding"] == "noteStep"]
        self.assertEqual(len(steps), 8)
        self.assertTrue(all(r["kind"] == "note" and r["argument"] == 148 for r in steps))
        self.assertEqual(sum(r.get("requiresTouch", False) for r in steps), 4)
        for name, digest in IMIX_SOURCES:
            path = ROOT / "TestBuilds/r169/upstream/res/controllers" / name
            if path.exists():
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), digest)

    def test_mixtrack_quad_uses_four_factory_channels_and_source600_count_calibration(self):
        item, = quad_profiles()
        self.assertTrue(item["autoSelect"])
        self.assertEqual((len(item["inputs"]), len(item["outputs"])), (106, 36))
        self.assertEqual(len(item["startup"]) + len(item["shutdown"]), 61)
        self.assertEqual(item["audioOutput"], "masterAndHeadphones")
        self.assertEqual([(r["channel"], r["number"], r["argument"], r["encoding"]) for r in item["inputs"] if r["action"] in {"jogA", "jogB"}], [(i, 37, 600, "twosComplement") for i in range(1, 5)])
        self.assertEqual({r["onValue"] for r in item["outputs"] if r["action"].startswith("hotcue")}, {5})
        self.assertTrue(all(r["inverted"] for r in item["inputs"] if r["action"].startswith("tempo")))
        self.assertFalse(any(r["action"].startswith("gain") for r in item["inputs"]))
        for name, (_, digest) in zip(["mixtrack-quad-vdj.zip", "mixtrack-quad-traktor.zip"], QUAD_SOURCES):
            path = ROOT / "TestBuilds/r280/manufacturer" / name
            if path.exists():
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), digest)

    def test_tm8_keeps_factory_bank_pitch_rgb_and_bounded_pickup_contract(self):
        item, = terminal_mix8_profiles()
        self.assertTrue(item["autoSelect"])
        self.assertEqual((len(item["inputs"]), len(item["outputs"])), (208, 52))
        self.assertEqual(len(item["startup"]) + len(item["shutdown"]), 61)
        self.assertNotIn("audioOutput", item)
        self.assertEqual([(r["channel"], r["number"], r["kind"]) for r in item["inputs"] if r["action"].startswith("tempo")], [(i, 0, "pitch") for i in range(4)])
        self.assertEqual({r["onValue"] for r in item["outputs"] if r["action"].startswith("hotcue")}, {19})
        self.assertTrue(all("releaseShiftChannels" not in r for r in item["bankChanges"]))
        self.assertEqual([(r["channel"], r["shiftChannel"], r["shiftInput"]) for r in item["inputs"] if r["action"] == "shift"], [(i, i % 2, i % 2) for i in range(4)])
        for name, (_, digest) in zip(["tm8-midi.pdf", "tm8-traktor-guide.pdf", "tm8-traktor.zip"], TM8_SOURCES):
            path = ROOT / "TestBuilds/r279/manufacturer" / name
            if path.exists():
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), digest)

    def test_original_dj2go2_uses_its_factory_signed_format_without_touch_or_audio_alias(self):
        item, = original_dj2go2_profiles()
        self.assertTrue(item["autoSelect"])
        self.assertEqual((len(item["inputs"]), len(item["outputs"])), (43, 16))
        self.assertEqual(len(item["startup"]) + len(item["shutdown"]), 32)
        self.assertNotIn("audioOutput", item)
        self.assertFalse(any(r["action"].startswith(("jogTouch", "level", "high", "mid", "low")) for r in item["inputs"]))
        self.assertEqual([(r["channel"], r["number"], r["encoding"]) for r in item["inputs"] if r["action"].startswith("wheelJog")], [(0, 6, "twosComplement"), (1, 6, "twosComplement")])
        self.assertTrue(all(not r["inverted"] for r in item["inputs"] if r["action"].startswith("tempo")))
        for name, digest in [("dj2go2-traktor.zip", ORIGINAL_DJ2GO2_ZIP_SHA), ("Numark DJ2GO2 Performance Map.tsi", ORIGINAL_DJ2GO2_TSI_SHA)]:
            path = ROOT / "TestBuilds/r278/manufacturer" / name
            if path.exists():
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), digest)

    def test_radius_player_preserves_factory_default_channel_and_tap_releases(self):
        item, = radius_profiles()
        self.assertTrue(item["autoSelect"])
        self.assertEqual(item["role"], "player")
        self.assertEqual((len(item["inputs"]), len(item["outputs"])), (41, 7))
        self.assertEqual(len(item["startup"]) + len(item["shutdown"]), 62)
        self.assertTrue(all(r["channel"] == 0 and not r.get("anyChannel") for r in item["inputs"]))
        self.assertEqual(sum(r.get("releaseOnly", False) for r in item["inputs"]), 18)
        jog, = [r for r in item["inputs"] if r["action"] == "jogA"]
        self.assertEqual((jog["encoding"], jog["argument"]), ("binaryOffset", 990))
        self.assertFalse(any(r["number"] == 19 and r["kind"] == "note" for r in item["inputs"]))
        for name, digest in RADIUS_SOURCES:
            path = ROOT / "TestBuilds/r169/upstream/res/controllers" / name
            if path.exists():
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), digest)
        factory = ROOT / "TestBuilds/r277/manufacturer/radius2000.pdf"
        if factory.exists():
            self.assertEqual(hashlib.sha256(factory.read_bytes()).hexdigest(), RADIUS_REFERENCES[item["id"]]["sha256"])

    def test_rdj2_controller_keeps_native_wheel_separate_from_touch_and_audio(self):
        item, = rdj2_controller_profiles()
        self.assertEqual(item["id"], "Reloop Digital Jockey 2 Controller")
        self.assertTrue(item["autoSelect"])
        self.assertEqual((len(item["inputs"]), len(item["outputs"])), (45, 10))
        self.assertEqual(len(item["startup"]) + len(item["shutdown"]), 60)
        self.assertNotIn("audioOutput", item)
        self.assertFalse(any(r["action"].startswith("jogTouch") for r in item["inputs"]))
        self.assertEqual([(r["channel"], r["number"], r["encoding"]) for r in item["inputs"] if r["action"].startswith("wheelJog")], [(0, 11, "binaryOffset"), (0, 71, "binaryOffset")])
        self.assertEqual([(r["channel"], r["number"], r["kind"], r["inverted"]) for r in item["inputs"] if r["action"].startswith("tempo")], [(0, 0, "pitch", True), (1, 0, "pitch", True)])
        for name, digest in RDJ2_CONTROLLER_SOURCES:
            path = ROOT / "TestBuilds/r169/upstream/res/controllers" / name
            if path.exists():
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), digest)

    def test_rdj2_interface_keeps_two_decks_source_jog_and_bounded_light_contract(self):
        item, = rdj2_ie_profiles()
        self.assertTrue(item["autoSelect"])
        self.assertEqual((len(item["inputs"]), len(item["outputs"])), (77, 12))
        self.assertEqual({r["targetDeck"] for r in item["inputs"] if "targetDeck" in r}, {"a", "b"})
        self.assertEqual(len(item["startup"]) + len(item["shutdown"]), 64)
        self.assertEqual(item["audioOutput"], "masterAndHeadphones")
        self.assertTrue(all(r["encoding"] == "denonJog" and r["argument"] == 148 for r in item["inputs"] if r["action"] in {"jogA", "jogB"}))
        self.assertFalse(any(r["action"].startswith("hotcue") for r in item["inputs"]))
        for name, digest in RDJ2_IE_SOURCES:
            path = ROOT / "TestBuilds/r169/upstream/res/controllers" / name
            if path.exists():
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), digest)

    def test_reloop_master_editions_keep_driver_connection_separate_from_interface_edition(self):
        cache = ROOT / "TestBuilds/r169/upstream"
        if not cache.exists():
            self.skipTest("Pinned source cache is unavailable")
        catalogue, _ = build(cache, None)
        for name in ["Reloop Jockey 3 ME", "Reloop Digital Jockey 2 Master Edition"]:
            model = next(m for m in catalogue["models"] if m["id"] == canonical(name))
            self.assertIn("desktop bridge", model["connection"])
            self.assertFalse(model["zeroConfig"]["automaticControls"])
            self.assertFalse(model["theoreticalSupport"]["complete"])
        interface = next(m for m in catalogue["models"] if m["id"] == canonical("Reloop Digital Jockey 2 Interface Edition"))
        self.assertNotIn("Non-class-compliant", interface["connection"])

    def test_rx221_resolves_load_pitch_and_feedback_without_changing_legacy_wire_recipe(self):
        legacy, current = legacy_xdj_profiles()
        self.assertFalse(legacy["autoSelect"])
        self.assertTrue(current["autoSelect"])
        self.assertEqual(legacy["catalogueName"], current["id"])
        self.assertEqual((len(current["inputs"]), len(current["outputs"])), (159, 24))
        self.assertEqual(len(current["startup"]) + len(current["shutdown"]), 56)
        self.assertEqual(len([r for r in current["inputs"] if r["action"].startswith("load")]), 4)
        self.assertTrue(all(r["number"] == 81 for r in current["inputs"] if r["action"].startswith("load")))
        self.assertEqual(sum(r.get("releaseOnly", False) for r in current["inputs"]), 44)
        self.assertNotIn("audioOutput", current)
        factory = ROOT / "TestBuilds/r272/manufacturer/XDJ-RX-221.pdf"
        if factory.exists():
            self.assertEqual(hashlib.sha256(factory.read_bytes()).hexdigest(), LEGACY_XDJ_REFERENCES[current["id"]]["sha256"])

    def test_djm101_retains_asymmetric_eq_and_does_not_infer_vtt_protocol(self):
        item, = djm101_profiles()
        self.assertTrue(item["autoSelect"])
        self.assertEqual(item["role"], "accessory")
        self.assertEqual((len(item["inputs"]), len(item["outputs"])), (16, 2))
        self.assertEqual(len(item["startup"]) + len(item["shutdown"]), 12)
        self.assertTrue(all(all(0 <= v < 128 for v in p[1:]) for p in item["startup"] + item["shutdown"]))
        controls = {r["action"]: r for r in item["inputs"]}
        self.assertEqual([controls[a]["number"] for a in ["gainA", "highA", "midA", "lowA"]], [72, 74, 78, 76])
        self.assertEqual([controls[a]["number"] for a in ["gainB", "highB", "midB", "lowB"]], [79, 77, 75, 73])
        self.assertNotIn("audioOutput", item)
        self.assertTrue(any(name == "DJ-Tech VTT-101" for name, _ in MANUFACTURER_MODELS))
        cache = ROOT / "TestBuilds/r169/upstream"
        if cache.exists():
            catalogue, runtime = build(cache, None)
            vtt = next(m for m in catalogue["models"] if m["id"] == canonical("DJ-Tech VTT-101"))
            self.assertEqual(vtt["implementation"], "protocol-needed")
            self.assertFalse(vtt["zeroConfig"]["automaticControls"])
            self.assertFalse(any("VTT" in alias for p in runtime["profiles"] for alias in p["aliases"]))
        for name, digest in DJM101_SOURCES:
            path = ROOT / "TestBuilds/r169/upstream/res/controllers" / name
            if path.exists():
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), digest)

    def test_discover_pro_normal_core_keeps_broken_source_modes_inactive(self):
        item, = discover_pro_profiles()
        self.assertTrue(item["autoSelect"])
        self.assertEqual((len(item["inputs"]), len(item["outputs"])), (34, 10))
        self.assertEqual((len(item["startup"]), len(item["shutdown"])), (30, 30))
        self.assertTrue(all(r["onValue"] == 100 and r["offValue"] == 0 for r in item["outputs"]))
        self.assertFalse(any(r["action"] in {"jogTouchA", "jogTouchB", "jogA", "jogB"} for r in item["inputs"]))
        self.assertFalse(any(r["action"].startswith(("loop", "tempoDown", "tempoUp")) for r in item["inputs"]))
        self.assertNotIn("audioOutput", item)
        for name, digest in DISCOVER_PRO_SOURCES:
            path = ROOT / "TestBuilds/r169/upstream/res/controllers" / name
            if path.exists():
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), digest)

    def test_original_discover_has_physical_volume_two_band_eq_and_permanent_tempo(self):
        item, = discover_profiles()
        self.assertTrue(item["autoSelect"])
        self.assertEqual((len(item["inputs"]), len(item["outputs"])), (25, 6))
        self.assertEqual(len(item["startup"]) + len(item["shutdown"]), 18)
        for side, deck in enumerate("AB"):
            controls = {r["action"]: r for r in item["inputs"] if r.get("targetDeck") == deck.lower()}
            self.assertEqual(controls["level" + deck]["number"], 8 + side)
            self.assertEqual(controls["low" + deck]["number"], 20 + side)
            self.assertNotIn("mid" + deck, controls)
            self.assertIn("tempoDown" + deck, controls)
            self.assertIn("tempoUp" + deck, controls)
            self.assertEqual(controls["jog" + deck]["argument"], 518.4)
        self.assertFalse(any(r["action"].startswith("pitchBend") for r in item["inputs"]))
        self.assertNotIn("audioOutput", item)
        for name, digest in DISCOVER_SOURCES:
            path = ROOT / "TestBuilds/r169/upstream/res/controllers" / name
            if path.exists():
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), digest)

    def test_original_firstmix_retains_source_wheel_mixer_and_light_contracts(self):
        item, = firstmix_profiles()
        self.assertTrue(item["autoSelect"])
        self.assertEqual((len(item["inputs"]), len(item["outputs"])), (25, 8))
        self.assertEqual(len(item["startup"]) + len(item["shutdown"]), 58)
        self.assertFalse(any(r["action"] in {"levelA", "levelB", "tempoA", "tempoB", "master"} for r in item["inputs"]))
        self.assertNotIn("audioOutput", item)
        self.assertTrue(all(r["requiresTouch"] and r["argument"] == 180 for r in item["inputs"] if r["action"] in {"jogA", "jogB"}))
        self.assertTrue(all(r["onValue"] == 100 and r["offValue"] == 0 for r in item["outputs"]))
        for name, digest in FIRSTMIX_SOURCES:
            path = ROOT / "TestBuilds/r169/upstream/res/controllers" / name
            if path.exists():
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), digest)

    def test_vms_external_mixer_audio_and_distinct_variants_remain_explicit(self):
        cache = ROOT / "TestBuilds/r169/upstream"
        if not cache.exists():
            self.skipTest("Pinned source cache is unavailable")
        catalogue, runtime = build(cache, None)
        for name in ["VMS2", "VMS4", "VMS4.1", "VMS4.1 Traktor", "VMS5"]:
            model = next(m for m in catalogue["models"] if m["id"] == canonical("American Audio " + name))
            self.assertFalse(model["zeroConfig"]["automaticControls"])
            self.assertFalse(model["theoreticalSupport"]["criteria"]["audioRoutingImplemented"])
            self.assertIn("separate deck outputs", model["audioRouting"])
            if name in {"VMS4.1 Traktor", "VMS5"}:
                self.assertEqual(model["implementation"], "protocol-needed")
                self.assertNotIn("profile", model)
        for name in ["American Audio VMS2", "American Audio VMS4/4.1"]:
            profile = next(p for p in runtime["profiles"] if p["id"] == name)
            self.assertFalse(profile["autoSelect"])
            self.assertNotIn("audioOutput", profile)
            self.assertIn("Post EQ", profile["hardwareMode"])
            self.assertIn("Pre EQ", profile["scope"])
            self.assertFalse(any("Traktor" in alias or "VMS5" in alias for alias in profile["aliases"]))

    def test_stealth_factory_inventory_does_not_infer_omni_runtime_compatibility(self):
        references = [url for name, url in MANUFACTURER_MODELS if name == "Numark Stealth Control"]
        self.assertEqual(len(references), 3)
        self.assertTrue(any(url.endswith(".zip") for url in references))
        cache = ROOT / "TestBuilds/r169/upstream"
        if cache.exists():
            catalogue, runtime = build(cache, None)
            model = next(row for row in catalogue["models"] if row["id"] == canonical("Numark Stealth Control"))
            self.assertEqual(model["implementation"], "protocol-needed")
            self.assertFalse(model["zeroConfig"]["automaticControls"])
            self.assertFalse(any("stealth" in alias.lower() for p in runtime["profiles"] for alias in p["aliases"]))
        factory = ROOT / "TestBuilds/r257/manufacturer"
        for name, digest in [
            ("Stealth-Control.zip", "5429b3d5a0d3340664f7982a74bd78f261ac2ca1461a1949d7c59dada34c7b17"),
            ("stealth_control_cue.xml", "fb961915199268c46c201ae84c1e2e595a40ff72b922c462d43cb69da8258dc1"),
            ("Setup-Instructions.pdf", "960a0d53067af96504064ba28f217756ee2c2272708fbc4f53b2b058a5b45a55"),
            ("Stealth-Control.pdf", "ddbe4bdc1c973ba7b5df170767ce0831d19a7659ffa85719b3620ace5f3af8a0"),
        ]:
            path = factory / name
            if path.exists():
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), digest)

    def test_catalogue_describes_the_selected_kaoss_recipe_instead_of_the_larger_manual_variant(self):
        cache = ROOT / "TestBuilds/r169/upstream"
        if not cache.exists():
            self.skipTest("Pinned source cache is unavailable")
        catalogue, runtime = build(cache, None)
        model = next(m for m in catalogue["models"] if m["id"] == canonical("Korg KAOSS DJ"))
        normal = next(p for p in runtime["profiles"] if p["id"] == "Korg KAOSS DJ")
        self.assertEqual(model["profile"], normal["id"])
        self.assertEqual(model["inputBindingCount"], len(normal["inputs"]))
        self.assertFalse({"master", "monitor", "cueMix"} & set(model["controlActions"]))
        self.assertEqual(model["audioRouting"], "Automatic master 1–2 / headphones 3–4")
        self.assertTrue(model["theoreticalSupport"]["criteria"]["audioRoutingImplemented"])
        self.assertFalse(model["theoreticalSupport"]["complete"])

    def test_kaoss_keeps_normal_hardware_gain_separate_from_manual_audioless_controls(self):
        audioless, normal = kaoss_profiles()
        self.assertEqual((len(normal["inputs"]), len(normal["outputs"])), (86, 20))
        self.assertEqual(len(audioless["inputs"]), 89)
        self.assertTrue(normal["autoSelect"])
        self.assertFalse(audioless["autoSelect"])
        self.assertEqual(audioless["catalogueName"], normal["id"])
        self.assertEqual(len(normal["startup"]) + len(normal["shutdown"]), 48)
        self.assertTrue(all(len(p) == 3 for p in normal["startup"] + normal["shutdown"]))
        self.assertFalse(any(r["action"] in {"master", "monitor", "cueMix"} for r in normal["inputs"]))
        self.assertTrue({"master", "monitor", "cueMix"} <= {r["action"] for r in audioless["inputs"]})
        self.assertNotIn("audioOutput", audioless)
        self.assertEqual(audioless["startup"] + audioless["shutdown"], [])
        for name, digest in KAOSS_SOURCES:
            path = ROOT / "TestBuilds/r169/upstream/res/controllers" / name
            if path.exists():
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), digest)

    def test_p32_keeps_native_cue_limit_source_steps_and_bounded_feedback(self):
        result = p32_profiles()[0]
        self.assertEqual((len(result["inputs"]), len(result["outputs"])), (105, 58))
        steps = [r["directionStep"] for r in result["inputs"] if "directionStep" in r]
        self.assertEqual(steps, [0.005, 0.005, 0.05])
        self.assertEqual(len(result["startup"]) + len(result["shutdown"]), 59)
        self.assertEqual(result["audioOutput"], "masterAndHeadphones")
        self.assertFalse(any(r["targetDeck"] in {"c", "d"} for r in result["inputs"] if "targetDeck" in r))
        self.assertEqual([r["number"] for r in result["inputs"] if r["action"].startswith("hotcue") and r["channel"] == 1], [96, 97, 98, 99, 92, 93, 94, 95])
        for name, digest in P32_SOURCES:
            path = ROOT / "TestBuilds/r169/upstream/res/controllers" / name
            if path.exists():
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), digest)

    def test_rmx2_keeps_adjacent_pairs_and_shift_cc_releases_separate_from_other_modes(self):
        result = rmx2_profiles()[0]
        self.assertEqual((len(result["inputs"]), len(result["outputs"])), (77, 16))
        pairs = [r for r in result["inputs"] if r["encoding"] == "paired14Bit"]
        self.assertEqual(len(pairs), 15)
        self.assertTrue(all(r["lowNumber"] == r["number"] + 1 for r in pairs))
        self.assertEqual(len([r for r in result["inputs"] if r.get("releaseOnly") and r["kind"] == "control"]), 16)
        self.assertEqual([r["argument"] for r in result["inputs"] if r["action"] == "toggleFixedLoopA" and not r.get("releaseOnly")], [4, 2, 1, 0.5])
        self.assertEqual(len(result["startup"]) + len(result["shutdown"]), 39)
        self.assertEqual(result["startup"][-1], [0xB0, 127, 127])
        self.assertFalse(any(r["action"] == "monitor" for r in result["inputs"]))
        for name, digest in RMX2_SOURCES:
            path = ROOT / "TestBuilds/r169/upstream/res/controllers" / name
            if path.exists():
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), digest)

    def test_mc3000_omits_phantom_hardware_gain_assignments_and_unqualified_load(self):
        result = mc3000_profiles()[0]
        self.assertFalse(result["autoSelect"])
        self.assertEqual((len(result["inputs"]), len(result["outputs"])), (124, 56))
        self.assertEqual(result["startup"] + result["shutdown"], [])
        self.assertFalse(any(r["action"] in {"master", "monitor", "cueMix", "loadA", "loadB"} for r in result["inputs"]))
        self.assertFalse(any(r["number"] in range(88, 93) for r in result["inputs"] if r["kind"] == "control"))
        self.assertEqual([r["targetDeck"] for r in result["inputs"] if r["kind"] == "pitch"], list("acbd"))
        for name, digest in MC3000_SOURCES:
            path = ROOT / "TestBuilds/r169/upstream/res/controllers" / name
            if path.exists():
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), digest)

    def test_djc4_uses_default_bank_explicit_shift_releases_and_safe_lifecycle(self):
        result = djc4_profiles()[0]
        self.assertEqual((len(result["inputs"]), len(result["outputs"])), (202, 40))
        self.assertEqual(len(result["startup"]) + len(result["shutdown"]), 48)
        self.assertEqual(len(result["bankChanges"]), 8)
        self.assertTrue(all(r["releaseShiftChannels"] == [] for r in result["bankChanges"]))
        self.assertTrue(all(r["number"] == 69 and r["releaseOnly"] for r in result["inputs"] if r["action"] in {"pitchBendDownA", "pitchBendDownB"} and r["shifted"]))
        self.assertFalse(any(r["action"] == "master" for r in result["inputs"]))
        self.assertEqual(result["audioOutput"], "masterAndHeadphones")
        for name, digest in DJC4_SOURCES:
            path = ROOT / "TestBuilds/r169/upstream/res/controllers" / name
            if path.exists():
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), digest)

    def test_studio4a_retains_source_deck_channels_and_reversed_right_loop_buttons(self):
        result = studio4a_profiles()[0]
        self.assertEqual((len(result["inputs"]), len(result["outputs"])), (124, 24))
        self.assertEqual(len(result["startup"]) + len(result["shutdown"]), 40)
        self.assertEqual(result["audioOutput"], "masterAndHeadphones")
        self.assertTrue(all(r["onValue"] == 1 for r in result["outputs"]))
        self.assertEqual([r["number"] for r in result["inputs"] if r["action"] == "loopInB"], [56, 56])
        self.assertEqual([r["number"] for r in result["inputs"] if r["action"] == "loopOutB"], [55, 55])
        self.assertTrue(all(r["argument"] == 600 for r in result["inputs"] if r["action"] in {"jogA", "jogB"}))
        for name, digest in STUDIO4A_SOURCES:
            path = ROOT / "TestBuilds/r169/upstream/res/controllers" / name
            if path.exists():
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), digest)

    def test_xsession_pro_uses_only_factory_normal_crossfader_and_qualified_controls(self):
        result = xsession_pro_profiles()[0]
        self.assertEqual((len(result["inputs"]), len(result["outputs"])), (22, 0))
        self.assertTrue(result["autoSelect"])
        self.assertEqual(result["startup"] + result["shutdown"], [])
        controls = {r["number"] for r in result["inputs"] if r["kind"] == "control"}
        self.assertFalse(controls & {20, 32})
        notes = {r["number"] for r in result["inputs"] if r["kind"] == "note"}
        self.assertEqual(notes, {44, 45, 58, 59, 69, 70})
        for name, digest in XSESSION_SOURCES:
            path = ROOT / "TestBuilds/r169/upstream/res/controllers" / name
            if path.exists():
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), digest)

    def test_total_omni_keep_opposite_jog_order_and_source_feedback(self):
        for result in total_omni_profiles():
            self.assertEqual((len(result["inputs"]), len(result["outputs"])), (46, 8))
            expected = [25, 24] if result["id"] == "Numark Total Control" else [24, 25]
            self.assertEqual([r["number"] for r in result["inputs"] if r["action"] in {"wheelJogA", "wheelJogB"}], expected)
            self.assertTrue(all(r["onValue"] == 100 and r["offValue"] == 0 for r in result["outputs"]))
            self.assertEqual(len(result["startup"]) + len(result["shutdown"]), 47)
            self.assertEqual([r["action"] for r in result["inputs"] if r["number"] == 73 and r["kind"] == "note"], ["loopDisableA", "loopInA"])
            self.assertNotIn("audioOutput", result)
            for name, digest in TOTAL_OMNI_SOURCES[result["id"]]:
                path = ROOT / "TestBuilds/r169/upstream/res/controllers" / name
                if path.exists():
                    self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), digest)

    def test_original300_keeps_factory_pairs_and_source_loop_layout_separate_from_mk2(self):
        result = original300_profiles()[0]
        self.assertEqual((len(result["inputs"]), len(result["outputs"])), (102, 8))
        self.assertEqual([r["argument"] for r in result["inputs"] if r["action"] in {"jogA", "jogB"}], [248, 62, 248, 62])
        self.assertEqual([r["number"] for r in result["inputs"] if r["action"] == "hotcue8A"], [7, 15])
        self.assertEqual(len([r for r in result["inputs"] if r["encoding"] == "paired14Bit"]), 29)
        self.assertEqual([r["argument"] for r in result["inputs"] if r["action"] in {"fixedLoopA", "fixedLoopB"}], [4, 4])
        self.assertEqual(result["startup"][-1], [0xB0, 127, 127])
        for name, digest in ORIGINAL300_SOURCES:
            path = ROOT / "TestBuilds/r169/upstream/res/controllers" / name
            if path.exists():
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), digest)

    def test_mixage_family_keeps_qualified_models_and_bounded_known_lights(self):
        result = mixage_profiles()[0]
        self.assertEqual((len(result["inputs"]), len(result["outputs"])), (108, 12))
        self.assertEqual(split_models("Reloop Mixage"), MIXAGE_MODELS)
        self.assertEqual(len(result["startup"]), 28)
        self.assertEqual(len(result["shutdown"]), 26)
        self.assertTrue(all(0 <= b < 128 for p in result["startup"] + result["shutdown"] for b in p[1:]))
        self.assertNotIn("audioOutput", result)
        self.assertTrue(all(r["argument"] == 620 for r in result["inputs"] if r["action"] in {"jogA", "jogB"}))
        for name, digest in MIXAGE_SOURCES:
            path = ROOT / "TestBuilds/r169/upstream/res/controllers" / name
            if path.exists():
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), digest)

    def test_sc2000_keeps_factory_trigger_leds_and_source_local_physical_shift(self):
        result = sc2000_profiles()[0]
        self.assertEqual((len(result["inputs"]), len(result["outputs"])), (120, 52))
        self.assertTrue(all(r["shiftInput"] == 0 for r in result["inputs"] if r["action"] == "shift"))
        self.assertEqual([r["channel"] for r in result["inputs"] if r["action"] == "shift"], list(range(8)))
        self.assertTrue(all(r["number"] == 74 and r["offNumber"] == 75 and r["onValue"] == r["offValue"] for r in result["outputs"]))
        self.assertEqual(len(result["shutdown"]), 52)
        self.assertEqual(result["startup"], [])
        self.assertFalse(any("USB Audio Device" in name for name in result["aliases"]))
        for name, digest in SC2000_SOURCES:
            path = ROOT / "TestBuilds/r169/upstream/res/controllers" / name
            if path.exists():
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), digest)

    def test_air_uses_factory_eight_bit_pairs_and_hardware_headphone_gain(self):
        result = air_profiles()[0]
        self.assertEqual((len(result["inputs"]), len(result["outputs"])), (43, 8))
        self.assertEqual([(r["number"], r["lowNumber"]) for r in result["inputs"] if r["encoding"] == "airTempo"], [(52, 88), (53, 89)])
        self.assertEqual(result["startup"][0], [0xB0, 127, 0])
        self.assertEqual(result["shutdown"], [[0xB0, 127, 0]])
        self.assertFalse(any(r["number"] in {59, 60} and r["kind"] == "note" for r in result["inputs"]))
        self.assertEqual(result["audioOutput"], "masterAndHeadphones")
        for name, digest in AIR_SOURCES:
            path = ROOT / "TestBuilds/r169/upstream/res/controllers" / name
            if path.exists():
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), digest)

    def test_original_dj2go_uses_factory_magnitude_and_direct_load(self):
        result = original_dj2go_profiles()[0]
        self.assertEqual((len(result["inputs"]), len(result["outputs"])), (26, 8))
        self.assertTrue(all(r["encoding"] == "twosComplement" for r in result["inputs"] if r["action"] in {"wheelJogA", "wheelJogB", "browse"}))
        self.assertFalse(any(r["action"] in {"jogTouchA", "jogTouchB", "loopInA", "loopInB"} for r in result["inputs"]))
        self.assertEqual([r["number"] for r in result["inputs"] if r["action"] in {"loadA", "loadB"}], [0x4B, 0x34])
        self.assertEqual(result["startup"], result["shutdown"])
        self.assertEqual(len(result["startup"]), 8)
        for name, digest in ORIGINAL_DJ2GO_SOURCES:
            path = ROOT / "TestBuilds/r169/upstream/res/controllers" / name
            if path.exists():
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), digest)

    def test_bcd3000_standard_mode_preserves_factory_leds_and_avoids_data4_master(self):
        result = bcd3000_profiles()[0]
        self.assertEqual((len(result["inputs"]), len(result["outputs"])), (32, 8))
        self.assertEqual(result["audioOutput"], "masterAndHeadphones")
        self.assertEqual(result["startup"][-2:], [[0xB0, 99, 127], [0xB0, 100, 127]])
        self.assertIn("Standard MIDI mode", result["hardwareMode"])
        self.assertEqual(result["shutdown"], [[0xB0, n, 0] for n in range(1, 26)])
        self.assertTrue(all(r["kind"] == "control" for r in result["outputs"]))
        self.assertEqual([r["number"] for r in result["outputs"] if r["action"] in {"cueA", "cueB"}], [2, 1])
        self.assertFalse(any(r["action"] in {"master", "monitor", "jogTouchA", "jogTouchB"} for r in result["inputs"]))
        for name, digest in BCD3000_SOURCES:
            path = ROOT / "TestBuilds/r169/upstream/res/controllers" / name
            if path.exists():
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), digest)

    def test_hercules_compact_keeps_factory_volume_and_skips_destructive_query(self):
        result = hercules_compact_profiles()[0]
        self.assertEqual((len(result["inputs"]), len(result["outputs"])), (55, 8))
        self.assertEqual([r["number"] for r in result["inputs"] if r["action"] in {"levelA", "levelB"}], [0x39, 0x3D])
        self.assertFalse(any(r["action"] in {"gainA", "gainB", "highA", "highB", "jogTouchA", "jogTouchB"} for r in result["inputs"]))
        self.assertTrue(all(r["encoding"] == "compactTempo" and r["inverted"] for r in result["inputs"] if r["action"] in {"tempoA", "tempoB"}))
        self.assertTrue(all(packet[0] == 0x90 for packet in result["startup"] + result["shutdown"]))
        self.assertEqual(result["startup"], result["shutdown"])
        for name, digest in HERCULES_COMPACT_SOURCES:
            path = ROOT / "TestBuilds/r169/upstream/res/controllers" / name
            if path.exists():
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), digest)

    def test_instinct_factory_rows_override_conflicting_legacy_jog_and_led_data(self):
        result = instinct_profiles()[0]
        self.assertEqual((len(result["inputs"]), len(result["outputs"])), (51, 6))
        self.assertEqual(result["audioOutput"], "masterAndHeadphones")
        self.assertEqual([r["number"] for r in result["inputs"] if r["action"] in {"wheelJogA", "wheelJogB"}], [48, 49])
        self.assertEqual([r["number"] for r in result["inputs"] if r["action"] in {"jogA", "jogB"}], [50, 51])
        self.assertTrue(all(r["requiresTouch"] and r["argument"] == 128 for r in result["inputs"] if r["action"] in {"jogA", "jogB"}))
        self.assertTrue(all(r["encoding"] == "signedStep" for r in result["inputs"] if r["action"] in {"tempoA", "tempoB"}))
        self.assertTrue(all(r["onValue"] == 0 and r["offValue"] == 127 for r in result["outputs"]))
        self.assertEqual(len(result["startup"]) + len(result["shutdown"]), 51)
        for name, digest in INSTINCT_SOURCES:
            path = ROOT / "TestBuilds/r169/upstream/res/controllers" / name
            if path.exists():
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), digest)

    def test_umix_pro2_keeps_touch_threshold_source_scale_and_sync_led_condition(self):
        result = umix_pro2_profiles()[0]
        self.assertEqual((len(result["inputs"]), len(result["outputs"])), (54, 20))
        self.assertTrue(all(r["encoding"] == "fullVelocityGate" for r in result["inputs"] if r["action"] in {"jogTouchA", "jogTouchB"}))
        self.assertTrue(all(r["argument"] == 340 for r in result["inputs"] if r["action"] in {"jogA", "jogB", "wheelJogA", "wheelJogB"}))
        self.assertTrue(all(r["encoding"] == "centredPitch" and r["inverted"] for r in result["inputs"] if r["action"] in {"tempoA", "tempoB"}))
        self.assertTrue(all(r["onValue"] == 100 and r["offValue"] == 0 for r in result["outputs"] if r["action"] in {"syncA", "syncB"}))
        self.assertEqual(len(result["startup"]) + len(result["shutdown"]), 32)
        for name, digest in UMIX_PRO2_SOURCES:
            path = ROOT / "TestBuilds/r169/upstream/res/controllers" / name
            if path.exists():
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), digest)

    def test_mixer_one_keeps_four_explicit_targets_and_source_meter_cleanup(self):
        result = mixer_one_profiles()[0]
        self.assertEqual((len(result["inputs"]), len(result["outputs"])), (32, 4))
        self.assertEqual([(r["channel"], r["targetDeck"], r["number"]) for r in result["inputs"] if r["action"] in {"levelA", "levelB"}], [(5, "a", 20), (6, "b", 25), (7, "c", 20), (8, "d", 25)])
        self.assertEqual({r["channel"] for r in result["inputs"] if r["action"] == "master"}, {5, 7})
        self.assertEqual(len(result["startup"]) + len(result["shutdown"]), 32)
        self.assertFalse(any(r["kind"] == "control" for r in result["outputs"]))
        for name, digest in MIXER_ONE_SOURCES:
            path = ROOT / "TestBuilds/r169/upstream/res/controllers" / name
            if path.exists():
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), digest)

    def test_ready_keeps_measured_ten_bit_travel_and_hardware_layer_addresses(self):
        result = ready_profiles()[0]
        self.assertEqual((len(result["inputs"]), len(result["outputs"])), (138, 8))
        self.assertTrue(all(r["number"] == 9 and r["lowNumber"] == 63 and r["inverted"] and r["encoding"] == "readyTempo" for r in result["inputs"] if r["action"] in {"tempoA", "tempoB"}))
        self.assertEqual([m["channel"] for m in result["inputModes"]], [4, 5])
        self.assertEqual(result["inputModes"][0]["numbers"], [0, 5, 14, 11, 15, 9, 8, 18])
        self.assertEqual(len(result["startup"]) + len(result["shutdown"]), 28)
        self.assertFalse(any(r["number"] == 32 and r["channel"] in {0, 1} for r in result["outputs"]))
        for name, digest in READY_SOURCES:
            path = ROOT / "TestBuilds/r244/upstream" / Path(name).name
            if path.exists():
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), digest)

    def test_xone_family_uses_factory_channel_and_separate_load_modifier(self):
        result = xone_k_profiles()[0]
        self.assertEqual((len(result["inputs"]), len(result["outputs"])), (53, 14))
        self.assertEqual({r["channel"] for r in result["inputs"]}, {14})
        self.assertTrue(all(r["shiftChannel"] == 2 and not r["shifted"] for r in result["inputs"] if r["action"] in {"playA", "playB"} and not r.get("releaseOnly")))
        self.assertTrue(all(r["shiftChannel"] == 1 and r["shifted"] for r in result["inputs"] if r["action"] in {"loadA", "loadB"} and not r.get("releaseOnly")))
        self.assertEqual(len(result["startup"]) + len(result["shutdown"]), 16)
        self.assertTrue(all(r["offValue"] == 127 and not r["offUsesNoteOn"] for r in result["outputs"]))
        self.assertEqual(split_models(result["catalogueName"]), ["Allen & Heath Xone:K1", "Allen & Heath Xone:K2", "Allen & Heath Xone:K3"])
        for name, digest in XONE_SOURCES:
            path = ROOT / "TestBuilds/r169/upstream/res/controllers" / name
            if path.exists():
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), digest)

    def test_original_vci100_keeps_cue_buttons_and_45rpm_scratch_time_scale(self):
        result = vci100_profiles()[0]
        self.assertEqual((len(result["inputs"]), len(result["outputs"])), (42, 0))
        self.assertEqual([r["number"] for r in result["inputs"] if r["action"] in {"cueGotoA", "cueGotoB"}], [51, 55])
        self.assertTrue(all(r["argument"] == 384 * 45 / (100 / 3) and r["requiresTouch"] for r in result["inputs"] if r["action"] in {"jogA", "jogB"}))
        self.assertTrue(all(not r["inverted"] for r in result["inputs"] if r["action"] in {"tempoA", "tempoB"}))
        self.assertFalse(any(r["number"] in {98, 99, 100} for r in result["inputs"]))
        for name, digest in VCI100_SOURCES:
            path = ROOT / "TestBuilds/r169/upstream/res/controllers" / name
            if path.exists():
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), digest)

    def test_lc6000_separates_control_port_and_direction_from_rotation(self):
        result = lc6000_profiles()[0]
        self.assertEqual(result["role"], "player")
        self.assertIn("LC6000 PR", result["portAliases"])
        self.assertFalse(any("WD" in name for name in result["portAliases"]))
        jog = next(r for r in result["inputs"] if r["action"] == "jogA")
        self.assertEqual((jog["number"], jog["lowNumber"], jog["encoding"], jog["argument"]), (55, 54, "lc6000Jog", 1024))
        self.assertFalse(any(r["number"] in {17, 49} and r["kind"] == "control" for r in result["inputs"]))
        self.assertEqual([r["argument"] for r in result["inputs"] if r["action"] == "toggleFixedLoopA"], [0.125, 0.25, 0.5, 1, 2, 4, 8, 16])
        self.assertEqual(len(result["startup"]) + len(result["shutdown"]), 14)
        for name, digest in LC6000_SOURCES:
            path = ROOT / "TestBuilds/r241" / name
            if path.exists():
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), digest)

    def test_idj_live2_keeps_contact_threshold_and_distinct_cue_buttons(self):
        result = idj_live2_profiles()[0]
        self.assertEqual((len(result["inputs"]), len(result["outputs"])), (27, 4))
        self.assertEqual([r["number"] for r in result["inputs"] if r["action"].startswith("cueSet")], [51, 60])
        self.assertEqual([r["number"] for r in result["inputs"] if r["action"].startswith("cueGoto")], [59, 66])
        jogs = [r for r in result["inputs"] if r["action"] in {"jogA", "jogB"}]
        self.assertTrue(all(r["argument"] == 640 and r["requiresTouch"] for r in jogs))
        self.assertEqual(result["startup"][0], [240, 0, 1, 63, 127, 46, 96, 0, 1, 1, 247])
        self.assertEqual(len(result["shutdown"]), 5)
        for name, digest in IDJ2_SOURCES:
            path = ROOT / "TestBuilds/r169/upstream/res/controllers" / name
            if path.exists():
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), digest)

    def test_cmd_micro_keeps_published_touch_loop_and_one_bit_led_facts(self):
        result = cmd_micro_profiles()[0]
        self.assertEqual((len(result["inputs"]), len(result["outputs"])), (32, 4))
        self.assertEqual({r["channel"] for r in result["inputs"]}, {0})
        self.assertEqual([r["number"] for r in result["inputs"] if r["action"] in {"pitchBendDownA", "pitchBendUpA", "pitchBendDownB", "pitchBendUpB"}], [16, 17, 32, 33])
        self.assertEqual([r["number"] for r in result["inputs"] if r["action"] == "toggleFixedLoopB"], [34, 36])
        self.assertTrue(all(r["onValue"] == 1 and r["offValue"] == 0 for r in result["outputs"]))
        self.assertTrue(all(r["argument"] == 128 for r in result["inputs"] if r["action"] in {"jogA", "jogB"}))
        for name, digest in CMD_MICRO_SOURCES:
            path = ROOT / "TestBuilds/r169/upstream/res/controllers" / name
            if path.exists():
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), digest)

    def test_vci400_guards_shared_pad_modes_and_retains_direct_load_channels(self):
        result = vci400_profiles()[0]
        self.assertEqual((len(result["inputs"]), len(result["outputs"])), (136, 16))
        self.assertEqual(len(result["startup"]) + len(result["shutdown"]), 32)
        self.assertEqual({r["channel"] for r in result["inputs"] if r["action"] in {"loadA", "loadB"}}, {2, 3, 4, 5})
        self.assertTrue(all(r["requiredMode"] == 21 for r in result["inputs"] if r["action"].startswith("hotcue")))
        self.assertEqual([r["argument"] for r in result["inputs"] if r["action"] == "fixedLoopA" and r["targetDeck"] == "a"], [0.125, 0.25, 0.5, 1, 2, 4, 8, 16])
        self.assertFalse(any(r["action"].startswith("hotcue") for r in result["outputs"]))
        for name, digest in VCI400_SOURCES:
            path = ROOT / "TestBuilds/r169/upstream/res/controllers" / name
            if path.exists():
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), digest)

    def test_original_inpulse200_uses_factory_pairs_and_native_loop_controls(self):
        result = original200_profiles()[0]
        self.assertEqual(result["audioOutput"], "masterAndHeadphones")
        self.assertFalse(any(r["action"] in {"master", "monitor", "midA", "midB"} for r in result["inputs"]))
        self.assertEqual([r["argument"] for r in result["inputs"] if r["action"] in {"fixedLoopA", "fixedLoopB"}], [4, 4])
        self.assertTrue(all(r["encoding"] == "paired14Bit" for r in result["inputs"] if r["action"] in {"levelA", "levelB", "gainA", "gainB", "crossfader"}))
        self.assertEqual([r["argument"] for r in result["inputs"] if r["action"] == "jogA"], [248, 62])
        for name, digest in ORIGINAL200_SOURCES:
            path = ROOT / "TestBuilds/r169/upstream/res/controllers" / name
            if path.exists():
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), digest)

    def test_rane_four_experimental_source_does_not_enable_automatic_selection(self):
        cache = ROOT / "TestBuilds/r169/upstream"
        if not cache.exists():
            self.skipTest("Pinned source cache is unavailable.")
        catalogue, runtime = build(cache, None)
        models = [m for m in catalogue["models"] if m["id"] == canonical("Rane FOUR")]
        self.assertEqual(len(models), 1)
        self.assertIn("https://github.com/ElectroDanceWorld-Radio/rane-four-mixxx-map/tree/f527e144d6246498fe3e45193fecbb20d8279ddd", models[0]["sources"])
        self.assertFalse(models[0].get("automaticControls", False))
        self.assertFalse(any(canonical(p["id"]) == canonical("Rane FOUR") and p["autoSelect"] for p in runtime["profiles"]))

    def test_mc3000_factory_audit_keeps_automatic_selection_disabled(self):
        cache = ROOT / "TestBuilds/r169/upstream"
        if not cache.exists():
            self.skipTest("Pinned source cache is unavailable.")
        catalogue, runtime = build(cache, None)
        model = next(m for m in catalogue["models"] if m["id"] == canonical("Denon MC3000"))
        self.assertIn("https://cdn.inmusicbrands.com/denondj/legacy/mc3000/MC3000EM_ENG_IM_v00.pdf", model["sources"])
        recipe = next(p for p in runtime["profiles"] if p["id"] == model["profile"])
        self.assertFalse(recipe["autoSelect"])
        self.assertFalse(model["theoreticalSupport"]["complete"])

    def test_portable_hercules_keep_distinct_loop_pages_and_lifecycle(self):
        star, mix = portable_profiles()
        self.assertEqual((len(star["inputs"]), len(mix["inputs"])), (58, 60))
        for result in [star, mix]:
            self.assertEqual(len(result["outputs"]), 22)
            self.assertEqual({r["number"] for r in result["inputs"] if r["action"] == "toggleFixedLoopA"}, set(range(48 if result is mix else 16, 52 if result is mix else 20)))
            self.assertFalse(any(r["action"].startswith("load") for r in result["inputs"]))
            self.assertTrue(all(r["argument"] == 248 and r["encoding"] == "signedStep" for r in result["inputs"] if r["action"] in {"jogA", "jogB", "wheelJogA", "wheelJogB"}))
            for name, digest in PORTABLE_SOURCES[result["id"]]:
                path = ROOT / "TestBuilds/r169/upstream/res/controllers" / name
                if path.exists():
                    self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), digest)
        self.assertIn([0x90, 36, 0], star["startup"])
        self.assertNotIn([0x90, 36, 0], mix["startup"])
        self.assertEqual(mix["shutdown"], [[0xB0, 127, 0]])

    def test_vci100mk2_keeps_four_targets_physical_shift_and_nonstandard_pairs(self):
        result = vci100mk2_profiles()[0]
        self.assertEqual((len(result["inputs"]), len(result["outputs"])), (126, 28))
        self.assertEqual(len(result["bankChanges"]), 4)
        self.assertEqual(len(result["shutdown"]), 16)
        self.assertEqual(len([r for r in result["inputs"] if r.get("releaseOnly")]), 40)
        self.assertTrue(all(r["lowNumber"] - r["number"] == 16 for r in result["inputs"] if r["encoding"] in {"paired14Bit", "vci100MK2Tempo"}))
        self.assertTrue(all(r["argument"] == 2400 for r in result["inputs"] if r["action"] in {"jogA", "jogB"}))
        for name, digest in VCI100MK2_SOURCES:
            path = ROOT / "TestBuilds/r169/upstream/res/controllers" / name
            if path.exists():
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), digest)

    def test_vci300_uses_cyclic_counts_nine_bit_pitch_and_composed_modifiers(self):
        result = vci300_profiles()[0]
        self.assertEqual((len(result["inputs"]), len(result["outputs"])), (61, 24))
        self.assertEqual(len([r for r in result["inputs"] if r["action"] == "shift"]), 7)
        self.assertEqual([(r["number"], r["lowNumber"], r["argument"], r["shiftChannel"])
                          for r in result["inputs"] if r["encoding"] == "cyclic14BitJog"],
                         [(28, 60, 1600, 3), (29, 61, 1600, 4)])
        self.assertEqual([(r["number"], r["lowNumber"]) for r in result["inputs"] if r["encoding"] == "vci300Tempo"], [(13, 45), (19, 51)])
        for name, digest in VCI300_SOURCES:
            path = ROOT / "TestBuilds/r169/upstream/res/controllers" / name
            if path.exists():
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), digest)

    def test_scratch_audio_output_uses_the_cited_master_and_headphone_layout(self):
        result = scratch_profiles()[0]
        self.assertEqual(result["audioOutput"], "masterAndHeadphones")
        cache = ROOT / "TestBuilds/r169/upstream"
        if cache.exists():
            catalogue, runtime = build(cache, None)
            model = next(row for row in catalogue["models"] if row["id"] == canonical("Numark Scratch"))
            self.assertEqual(model["audioRouting"], "Automatic master 1–2 / headphones 3–4")
            self.assertTrue(model["theoreticalSupport"]["criteria"]["audioRoutingImplemented"])
            self.assertFalse(model["theoreticalSupport"]["complete"])
            self.assertEqual({p["id"] for p in runtime["profiles"] if p.get("audioOutput")}, {"Numark Scratch", "Hercules DJControl Inpulse 200", "Hercules DJ Control Instinct", "Behringer BCD3000", "Hercules DJ Control AIR", "Behringer CMD STUDIO 4a", "Stanton DJC.4", "Hercules P32 DJ", "Korg KAOSS DJ", "Reloop Digital Jockey 2 Interface Edition", "Numark Mixtrack Quad", "MixVibes U-Mix Control Pro"})

    def test_scratch_requires_explicit_pulses_and_mode_guarded_shared_pads(self):
        result = scratch_profiles()[0]
        self.assertEqual((len(result["inputs"]), len(result["outputs"])), (45, 0))
        pulses = [row for row in result["inputs"] if row.get("pulse")]
        self.assertEqual(len(pulses), 8)
        self.assertEqual({row["action"] for row in result["inputs"] if row["number"] == 27}, {"cueStateA", "cueStateB"})
        self.assertEqual({row["action"] for row in result["inputs"] if row["number"] == 63 and not row["shifted"]}, {"loopA", "loopB"})
        self.assertTrue(all(row["kind"] == "note" and row["number"] in {52, 53} for row in pulses))
        self.assertTrue(all(row["requiredMode"] == 0 for row in result["inputs"] if row["action"].startswith("hotcue")))
        self.assertEqual(result["bankChanges"], [{"channel": 15, "number": 87, "onValue": 2, "decks": ["a"], "releaseShiftChannels": []}, {"channel": 15, "number": 96, "onValue": 2, "decks": ["b"], "releaseShiftChannels": []}])
        self.assertFalse(any(row["action"] in {"master", "monitor"} for row in result["inputs"]))
        for name, digest in SCRATCH_SOURCES:
            path = ROOT / "TestBuilds/r169/upstream/res/controllers" / name
            if path.exists():
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), digest)

    def test_original_rp8000_retains_factory_channels_loop_sizes_and_source_members(self):
        result = rp8000_profiles()[0]
        self.assertEqual((len(result["inputs"]), len(result["outputs"])), (136, 40))
        self.assertEqual(result["role"], "accessory")
        self.assertEqual(result["startup"], [])
        self.assertTrue(all(row["number"] == 64 and row["encoding"] == "binaryOffset" for row in result["inputs"] if row["action"] == "browse"))
        self.assertEqual([row["argument"] for row in result["inputs"] if row["action"] == "toggleFixedLoopA" and row["targetDeck"] == "a" and not row.get("releaseOnly")], [0.25, 0.5, 1, 2, 4, 8, 16, 32])
        refs = RP8000_REFERENCES[result["id"]]
        for name, digest in [("RP-8000.pdf", refs["sha256"]), ("RP-8000-Mapping.zip", refs["relatedSources"][0]["sha256"]), ("RP-8000-Serato.xml", refs["relatedSources"][0]["memberSHA256"]), ("RP-8000-Traktor.zip", refs["relatedSources"][1]["sha256"]), ("RP-8000.tsi", refs["relatedSources"][1]["memberSHA256"])]:
            path = ROOT / "TestBuilds/r230/manufacturer" / name
            if path.exists():
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), digest)

    def test_compact_vestax_profiles_keep_distinct_loops_and_dispatch(self):
        typhoon, spin = compact_profiles()
        self.assertEqual((len(typhoon["inputs"]), len(spin["inputs"])), (42, 36))
        self.assertTrue(all(row["encoding"] == "binaryOffset" and row["argument"] == 300 for p in [typhoon, spin] for row in p["inputs"] if row["action"] in {"jogA", "jogB"}))
        self.assertEqual({row["number"] for row in typhoon["inputs"] if row["action"] == "jogTouchA"}, {46, 47})
        self.assertEqual({row["number"] for row in spin["inputs"] if row["action"] == "jogTouchA"}, {46})
        self.assertEqual({row["action"] for row in typhoon["inputs"] if row["number"] == 33}, {"loopDownA", "loopDownB"})
        self.assertEqual({row["action"] for row in spin["inputs"] if row["number"] == 33}, {"loopInA", "loopInB"})
        for p in [typhoon, spin]:
            self.assertTrue(all(row["encoding"] == "centreDetent" and not row["inverted"] for row in p["inputs"] if row["action"] in {"tempoA", "tempoB"}))
            for name, digest in COMPACT_SOURCES[p["id"]]:
                path = ROOT / "TestBuilds/r169/upstream/res/controllers" / name
                if path.exists():
                    self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), digest)

    def test_neon_uses_distinct_factory_pages_without_context_free_encoders(self):
        result = neon_profiles()[0]
        self.assertEqual((len(result["inputs"]), len(result["outputs"])), (96, 0))
        self.assertEqual(result["role"], "accessory")
        self.assertEqual(result["startup"], [[240, 10, 0, 247]])
        cues = [row for row in result["inputs"] if row["action"].startswith("hotcue") and not row.get("releaseOnly")]
        self.assertEqual({row["channel"] for row in cues}, {7, 8, 9, 10})
        self.assertEqual({row["number"] for row in cues}, set(range(16, 24)))
        self.assertFalse(any(row["kind"] != "note" for row in result["inputs"]))
        self.assertEqual({row["number"] for row in result["inputs"] if row["action"] in {"loopA", "loopB"} and not row.get("releaseOnly")}, {120})
        refs = NEON_REFERENCES[result["id"]]
        for name, ref in [("NEON-MIDI.pdf", refs), ("NEON-Guide.pdf", refs["relatedSources"][0]), ("NEON-Serato.pdf", refs["relatedSources"][1])]:
            path = ROOT / "TestBuilds/r228/manufacturer" / name
            if path.exists():
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), ref["sha256"])

    def test_n4_keeps_dispatch_addresses_and_latched_headphone_state(self):
        result = n4_profiles()[0]
        self.assertIn("N4 MIDI 1", result["aliases"])
        self.assertEqual([row["number"] for row in result["inputs"] if row["action"] in {"gainA", "gainB"}], [12, 17, 23, 28])
        self.assertEqual([row["number"] for row in result["inputs"] if row["action"] in {"levelA", "levelB"}], [8, 13, 19, 24])
        self.assertEqual((len(result["inputs"]), len(result["outputs"])), (99, 36))
        self.assertTrue(all(row["kind"] == "control" and "onValue" not in row for row in result["bankChanges"]))
        self.assertEqual([row["number"] for row in result["inputs"] if row["action"] in {"cueStateA", "cueStateB"}], [49, 50, 51, 52])
        self.assertFalse(any(row["action"] in {"cueA", "cueB", "cueStateA", "cueStateB"} for row in result["outputs"]))
        self.assertTrue(all(row["number"] == 32 and row["argument"] == 600 for row in result["inputs"] if row["action"] in {"jogA", "jogB"}))
        self.assertTrue(all(row["number"] == 1 and row["encoding"] == "paired14Bit" and not row["inverted"] for row in result["inputs"] if row["action"] in {"tempoA", "tempoB"}))
        for name, digest in N4_SOURCES:
            path = ROOT / "TestBuilds/r169/upstream/res/controllers" / name
            if path.exists():
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), digest)

    def test_source_inventory_and_generated_data(self):
        cache = ROOT / "TestBuilds/r169/upstream"
        if not cache.exists():
            self.skipTest("Fetch the locked public reference cache before checking regeneration.")
        catalogue, runtime = build(cache, None)
        self.assertEqual(catalogue, json.loads((ROOT / "docs/coordination/controller-catalogue.json").read_text()))
        self.assertEqual(runtime, json.loads((ROOT / "Replica/Sources/TDJInterface/Resources/factory-controller-profiles.json").read_text()))
        self.assertEqual(report(catalogue, runtime), (ROOT / "docs/coordination/controller-catalogue.md").read_text())
        self.assertFalse(catalogue["releaseGate"]["manufacturerAuditComplete"])
        for name, source in MANUFACTURER_MODELS:
            model = next(item for item in catalogue["models"] if item["id"] == canonical(name))
            self.assertIn(source, model["sources"])
            self.assertEqual(model["zeroConfig"]["automaticControls"], name in {"Reloop Mixtour"})
            self.assertFalse(model["theoreticalSupport"]["complete"])
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
