#!/usr/bin/env python3
"""Build the complete source catalogue and separate bounded runtime profiles."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path

from convert import convert_xml
from curated import curated_profiles, REFERENCES
from sources import canonical, manufacturer, read_serato, read_djay, split_models
from virtualdj_inventory import read_virtualdj
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
from manufacturer_inventory import MODELS as MANUFACTURER_MODELS, REVIEWED as INVENTORY_REVIEWED, DRIVER_REQUIRED, SOURCE_AUDITS
from jogvision import jogvision_profiles, JOGVISION_REFERENCES
from inpulse300mk2 import inpulse300mk2_profiles, MK2_REFERENCES
from inpulse200mk2 import inpulse200mk2_profiles, INPULSE200_REFERENCES
from beatmix import beatmix_profiles, BEATMIX_REFERENCES
from mc2000 import mc2000_profiles, MC2000_REFERENCES
from mixon4 import mixon4_profiles, MIXON4_REFERENCES
from dicer import dicer_profiles, DICER_REFERENCES
from ns6ii import ns6ii_profiles, NS6II_REFERENCES
from n4 import n4_profiles, N4_REFERENCES
from neon import neon_profiles, NEON_REFERENCES
from vestax_compact import compact_profiles, COMPACT_REFERENCES
from rp8000 import rp8000_profiles, RP8000_REFERENCES
from scratch import scratch_profiles, SCRATCH_REFERENCES
from vci300 import vci300_profiles, VCI300_REFERENCES
from vci100mk2 import vci100mk2_profiles, VCI100MK2_REFERENCES
from hercules_portable import portable_profiles, PORTABLE_REFERENCES
from inpulse200 import original200_profiles, ORIGINAL200_REFERENCES
from vci400 import vci400_profiles, VCI400_REFERENCES
from cmd_micro import cmd_micro_profiles, CMD_MICRO_REFERENCES
from idj_live2 import idj_live2_profiles, IDJ2_REFERENCES
from lc6000 import lc6000_profiles, LC6000_REFERENCES
from vci100 import vci100_profiles, VCI100_REFERENCES
from xone_k import xone_k_profiles, XONE_REFERENCES
from ready import ready_profiles, READY_REFERENCES
from mixer_one import mixer_one_profiles, MIXER_ONE_REFERENCES
from umix_pro2 import umix_pro2_profiles, UMIX_PRO2_REFERENCES
from instinct import instinct_profiles, INSTINCT_REFERENCES
from hercules_compact import hercules_compact_profiles, HERCULES_COMPACT_REFERENCES
from bcd3000 import bcd3000_profiles, BCD3000_REFERENCES
from original_dj2go import original_dj2go_profiles, ORIGINAL_DJ2GO_REFERENCES
from hercules_air import air_profiles, AIR_REFERENCES
from sc2000 import sc2000_profiles, SC2000_REFERENCES
from mixage import mixage_profiles, MIXAGE_REFERENCES
from original300 import original300_profiles, ORIGINAL300_REFERENCES
from total_omni import total_omni_profiles, TOTAL_OMNI_REFERENCES
from xsession_pro import xsession_pro_profiles, XSESSION_REFERENCES
from cmd_studio4a import studio4a_profiles, STUDIO4A_REFERENCES
from stanton_djc4 import djc4_profiles, DJC4_REFERENCES
from mc3000 import mc3000_profiles, MC3000_REFERENCES
from rmx2 import rmx2_profiles, RMX2_REFERENCES
from p32 import p32_profiles, P32_REFERENCES
from kaoss_dj import kaoss_profiles, KAOSS_REFERENCES
from firstmix import firstmix_profiles, FIRSTMIX_REFERENCES
from ion_discover import discover_profiles, DISCOVER_REFERENCES
from ion_discover_pro import discover_pro_profiles, DISCOVER_PRO_REFERENCES
from djm101 import djm101_profiles, DJM101_REFERENCES
from rdj2_ie import rdj2_ie_profiles, RDJ2_IE_REFERENCES
from rdj2_controller import rdj2_controller_profiles, RDJ2_CONTROLLER_REFERENCES
from radius2000 import radius_profiles, RADIUS_REFERENCES
from original_dj2go2 import original_dj2go2_profiles, ORIGINAL_DJ2GO2_REFERENCES
from terminal_mix8 import terminal_mix8_profiles, TM8_REFERENCES
from mixtrack_quad import quad_profiles, QUAD_REFERENCES
from imix_reload import imix_profiles, IMIX_REFERENCES
from mcx8000 import mcx_profiles, MCX_REFERENCES
from mix101 import mix101_profiles, MIX101_REFERENCES
from tek2 import tek2_profiles, TEK2_REFERENCES
from kdj500 import kdj_profiles, KDJ_REFERENCES
from umix_control2 import umix2_profiles, UMIX2_REFERENCES
from original_umix_pro import original_umix_profiles, ORIGINAL_UMIX_REFERENCES
from mixtour import mixtour_profiles, MIXTOUR_REFERENCES
from beatpad2 import beatpad2_profiles, BEATPAD2_REFERENCES
from mixtour_pro import mixtour_pro_profiles, MIXTOUR_PRO_REFERENCES
from electrix_tweaker import tweaker_profiles, TWEAKER_REFERENCES
from hercules_t7 import t7_profiles, T7_REFERENCES
from buddy import buddy_profiles, BUDDY_REFERENCES
from gemini_slate import slate_profiles, SLATE_REFERENCES
from ndx500 import ndx500_profiles, NDX500_REFERENCES
from rane_four import rane_four_profiles, FOUR_REFERENCES
from party_mix_live import party_mix_live_profiles, LIVE_REFERENCES
from g2v import g2v_profiles, G2V_REFERENCES
from rmp4 import rmp4_profiles, RMP4_REFERENCES
from idj3 import idj3_profiles, IDJ3_REFERENCES
from studio2a import studio2a_profiles, STUDIO2A_REFERENCES
from reloop_touch import touch_profiles, TOUCH_REFERENCES
from rane_seventy import seventy_profiles, SEVENTY_REFERENCES
from numark_nv import nv_profiles, NV_REFERENCES
from faderfox_dj3 import dj3_profiles, DJ3_REFERENCES
from reloop_rmx90 import rmx90_profiles, RMX90_REFERENCES
from roland_dj505 import dj505_profiles, DJ505_REFERENCES
from cmd_mm1 import mm1_profiles, MM1_REFERENCES
from fixed_midi_mixers import fixed_mixer_profiles, FIXED_MIXER_REFERENCES
from smk25ii import smk25_profiles, SMK25_REFERENCES
from midi_fighter import fighter_profiles, FIGHTER_REFERENCES
from launchpad_mini import mini_profiles, MINI_REFERENCES
from launchpad_rgb import rgb_profiles, RGB_REFERENCES
from cdj101 import cdj101_profiles, CDJ101_REFERENCES
from ddj_sr2 import sr2_profiles, SR2_REFERENCES
from keylab import keylab_profiles, KEYLAB_REFERENCES
from kontrol_one import kontrol_one_profiles, KONTROL_ONE_REFERENCES
from spectra import spectra_profiles, SPECTRA_REFERENCES
from mixars_duo import duo_profiles, DUO_REFERENCES
from p1nano import p1nano_profiles, P1_REFERENCES
from ddm4000 import ddm4000_profiles, DDM_REFERENCES
from scs3m import scs3m_profiles, SCS3M_REFERENCES
from bcr2000 import bcr2000_profiles, BCR_REFERENCES
from sc5000m import sc5000m_profiles, SC5000M_REFERENCES
from prime_players import prime_player_profiles, PRIME_REFERENCES
from rane_one_mk2 import rane_one_mk2_profiles, ONE2_REFERENCES
from nanokontrol2 import nanokontrol2_profiles, NANO2_REFERENCES
from nanopad2 import nanopad2_profiles, PAD2_REFERENCES
from prime4 import prime4_profiles, PRIME4_REFERENCES
from mp2015 import mp2015_profiles, MP2015_REFERENCES
from rane_one import rane_one_profiles, ONE_REFERENCES
from prime_all_in_one import prime_aio_profiles, PRIME_AIO_REFERENCES
from fixed_engine_consoles import fixed_engine_profiles, ENGINE_FIXED_REFERENCES
from rdj2_master import rdj2_master_profiles, MASTER_REFERENCES
from sp404mk2 import sp404_profiles, SP404_REFERENCES
from euphonia import euphonia_profiles, EUPHONIA_REFERENCES
from numark_2026 import numark_2026_profiles, NUMARK_2026_REFERENCES
from nanokontrol_scene import nanokontrol_scene_profiles, SCENE_REFERENCES
from plx_crss12 import plx_crss12_profiles, CRSS_REFERENCES
from hercules_mk4 import mk4_profiles, MK4_REFERENCES
from djm_a9 import a9_profiles, A9_REFERENCES
from slab import slab_profiles, SLAB_REFERENCES
from djm_a7 import a7_profiles, A7_REFERENCES
from xdj_an import an_profiles, AN_REFERENCES
from rev7 import rev7_profiles, REV7_REFERENCES
from rmx_ignite import ignite_profiles, IGNITE_REFERENCES
from mix_ultra import ultra_profiles, ULTRA_REFERENCES
from djm900nxs2 import nxs2_profiles, NXS2_REFERENCES
from djm_s9 import s9_profiles, S9_REFERENCES
from djm_v10 import v10_profiles, V10_REFERENCES
from djm450 import djm450_profiles, DJM450_REFERENCES
from air_plus import air_plus_profiles, AIR_PLUS_REFERENCES
from dj4set import dj4set_profiles, DJ4SET_REFERENCES
from original_ns6 import ns6_profiles, NS6_REFERENCES
from original_mc6000 import original_mc6000_profiles, ORIGINAL_MC6000_REFERENCES
from spin2_xwj1 import spin2_xwj1_profiles, SPIN2_REFERENCES
from primo import primo_profiles, PRIMO_REFERENCES
from beatmix_original import original_beatmix_profiles, BEATMIX_ORIGINAL_REFERENCES
from vcm100 import vcm100_profiles, VCM100_REFERENCES
from xwdj1 import xwdj1_profiles, XWDJ1_REFERENCES
from inpulse200mk3 import inpulse200mk3_profiles, MK3_REFERENCES
from hercules_t10 import t10_profiles, T10_REFERENCES
from xone96 import xone96_profiles, XONE96_REFERENCES
from xone_faders import xone_fader_profiles, XONE_FADER_REFERENCES
from vms5 import vms5_profiles, VMS5_REFERENCES
from vms41_traktor import vms41_traktor_profiles, VMS41_TRAKTOR_REFERENCES
from promixer_public import promixer_public_profiles, PROMIXER_REFERENCES
from djms3 import djms3_profiles, S3_REFERENCES
from legacy_djay_docks import legacy_djay_dock_profiles, DOCK_REFERENCES
from vci300_mkii import vci300_mkii_profiles, VCI300_MKII_REFERENCES
from legacy_djm_mixers import legacy_djm_mixer_profiles, LEGACY_DJM_REFERENCES
from mixdeck import mixdeck_profiles, MIXDECK_REFERENCES
from mixon8 import mixon8_profiles, MIXON8_REFERENCES
from stealth_control import stealth_profiles, STEALTH_REFERENCES
from djm_s11 import s11_profiles, S11_REFERENCES
from pioneer_manual_mixers import manual_mixer_profiles, MIXER_REFERENCES

VMS_MODELS = {canonical("American Audio " + name) for name in ["VMS2", "VMS4", "VMS4.1", "VMS4.1 Traktor", "VMS5"]}
VMS_AUDIO_GAP = "Integrated hardware mixing needs separate deck outputs. This audio route is not implemented."
VMS_EQ_GAP = "The factory Pre EQ mode applies hardware EQ. Software EQ requires Post EQ mode to avoid applying EQ twice."

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


def encode_runtime(value):
    """Keep the generated UTF-8 resource within the native loader's limit."""
    text = json.dumps(value, ensure_ascii=False, separators=(",", ":")) + "\n"
    if len(text.encode("utf-8")) > 4 * 1024 * 1024:
        raise ValueError("The controller catalogue exceeds the 4 MiB limit.")
    return text


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


def build(cache, serato_html, djay_html=None):
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
    djay = locked["djay"]
    if not 200 <= djay["rowCount"] <= 512 or djay["rowCount"] != len(djay["rows"]) or len({canonical(row["name"]) for row in djay["rows"]}) != djay["rowCount"]:
        raise ValueError("The locked djay inventory is incomplete or contains duplicate models.")
    if djay_html is not None:
        if hashlib.sha256(djay_html.read_bytes()).hexdigest() != djay["sha256"] or read_djay(djay_html.read_text()) != djay["rows"]:
            raise ValueError("The djay inventory differs from the reviewed lock file.")
    virtualdj = locked["virtualdj"]
    if not 400 <= virtualdj["rowCount"] <= 1024 or virtualdj["rowCount"] != len(virtualdj["rows"]) or len({row["url"] for row in virtualdj["rows"]}) != virtualdj["rowCount"]:
        raise ValueError("The locked VirtualDJ inventory is incomplete or contains duplicate product URLs.")
    virtualdj_html = Path(__file__).resolve().parents[2] / "TestBuilds/r392/upstream/virtualdj-hardware.html"
    if virtualdj_html.exists():
        if hashlib.sha256(virtualdj_html.read_bytes()).hexdigest() != virtualdj["sha256"] or read_virtualdj(virtualdj_html.read_text()) != virtualdj["rows"]:
            raise ValueError("The cached VirtualDJ inventory does not match the pinned source.")
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

    reviewed = curated_profiles() + cdj_profiles() + player_profiles() + controller_profiles() + ddj_profiles() + legacy_xdj_profiles() + entry_profiles() + opus_profiles() + legacy_ddj_profiles() + s1_profiles() + legacy_system_profiles() + numark_profiles() + mixtrack3_profiles() + platinum_profiles() + mixtrack2_profiles() + denon_profiles() + mc6000_profiles() + mc7000_profiles() + original_mixtrack_profiles() + party_mix_profiles() + t1_profiles() + pad_accessory_profiles() + party_mix2_profiles() + terminal_mix_profiles() + dj2go2_profiles() + ns4fx_profiles() + mixstream_profiles() + flx10_profiles() + ddj1000_profiles() + jogvision_profiles() + inpulse300mk2_profiles() + inpulse200mk2_profiles() + beatmix_profiles() + mc2000_profiles() + mixon4_profiles() + dicer_profiles() + ns6ii_profiles() + n4_profiles() + neon_profiles() + compact_profiles() + rp8000_profiles() + scratch_profiles() + vci300_profiles() + vci100mk2_profiles() + portable_profiles() + original200_profiles() + vci400_profiles() + cmd_micro_profiles() + idj_live2_profiles() + lc6000_profiles() + vci100_profiles() + xone_k_profiles() + ready_profiles() + mixer_one_profiles() + umix_pro2_profiles() + instinct_profiles() + hercules_compact_profiles() + bcd3000_profiles() + original_dj2go_profiles() + air_profiles() + sc2000_profiles() + mixage_profiles() + original300_profiles() + total_omni_profiles() + xsession_pro_profiles() + studio4a_profiles() + djc4_profiles() + mc3000_profiles() + rmx2_profiles() + p32_profiles() + kaoss_profiles() + firstmix_profiles() + discover_profiles() + discover_pro_profiles() + djm101_profiles() + rdj2_ie_profiles() + rdj2_controller_profiles() + radius_profiles() + original_dj2go2_profiles() + terminal_mix8_profiles() + quad_profiles() + imix_profiles() + mcx_profiles() + mix101_profiles() + tek2_profiles() + kdj_profiles() + umix2_profiles() + original_umix_profiles() + mixtour_profiles() + beatpad2_profiles() + mixtour_pro_profiles() + tweaker_profiles() + t7_profiles() + buddy_profiles() + slate_profiles() + ndx500_profiles() + rane_four_profiles() + party_mix_live_profiles() + mixdeck_profiles() + mixon8_profiles() + stealth_profiles() + s11_profiles() + manual_mixer_profiles() + g2v_profiles() + rmp4_profiles() + idj3_profiles() + studio2a_profiles() + touch_profiles() + seventy_profiles() + nv_profiles() + dj3_profiles() + rmx90_profiles() + dj505_profiles() + mm1_profiles() + fixed_mixer_profiles() + smk25_profiles() + fighter_profiles() + mini_profiles() + rgb_profiles() + cdj101_profiles() + sr2_profiles() + keylab_profiles() + kontrol_one_profiles() + spectra_profiles() + duo_profiles() + p1nano_profiles() + ddm4000_profiles() + scs3m_profiles() + bcr2000_profiles() + sc5000m_profiles() + prime_player_profiles() + rane_one_mk2_profiles() + nanokontrol2_profiles() + nanopad2_profiles() + prime4_profiles() + mp2015_profiles() + rane_one_profiles() + prime_aio_profiles() + fixed_engine_profiles() + rdj2_master_profiles() + sp404_profiles() + euphonia_profiles() + numark_2026_profiles() + nanokontrol_scene_profiles() + plx_crss12_profiles() + mk4_profiles() + a9_profiles() + slab_profiles() + a7_profiles() + an_profiles() + rev7_profiles() + ignite_profiles() + ultra_profiles() + nxs2_profiles() + s9_profiles() + v10_profiles() + djm450_profiles() + air_plus_profiles() + dj4set_profiles() + ns6_profiles() + original_mc6000_profiles() + spin2_xwj1_profiles() + primo_profiles() + original_beatmix_profiles() + vcm100_profiles() + xwdj1_profiles() + inpulse200mk3_profiles() + t10_profiles() + xone96_profiles() + xone_fader_profiles() + vms5_profiles() + vms41_traktor_profiles() + promixer_public_profiles() + djms3_profiles() + legacy_djay_dock_profiles() + vci300_mkii_profiles() + legacy_djm_mixer_profiles()
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
        if definition_id in {"American Audio VMS2.midi.xml", "American Audio VMS4.midi.xml"}:
            profile.update(autoSelect=False, hardwareMode="Post EQ for software EQ controls",
                           scope="Manual controls only. " + VMS_AUDIO_GAP + " " + VMS_EQ_GAP,
                           gaps=[VMS_AUDIO_GAP, VMS_EQ_GAP])
        profiles.append(profile)
    for item in reviewed:
        for name in split_models(item.get("catalogueName", item["id"])):
            model = add_model(name, item["source"], "accessory" if item.get("role") == "accessory" else "primary")
            if item["id"] in PLAYER_REFERENCES or item["id"] in VCI100_REFERENCES or item["id"] in BCD3000_REFERENCES:
                model["name"] = item["id"]
            model.update(implementation="automatic-core-profile" if item["autoSelect"] else "partial-midi-profile",
                         profile=item["id"], automaticControls=item["autoSelect"])
            model["definitions"].append(item["definition"])
        reference = REFERENCES.get(item["id"])
        source = CDJ_REFERENCES.get(item["id"]) or PLAYER_REFERENCES.get(item["id"]) or controller_references().get(item["id"]) or ddj_references().get(item["id"]) or LEGACY_XDJ_REFERENCES.get(item["id"]) or entry_references().get(item["id"]) or OPUS_REFERENCES.get(item["id"]) or legacy_ddj_references().get(item["id"]) or S1_REFERENCES.get(item["id"]) or LEGACY_SYSTEM_REFERENCES.get(item["id"]) or numark_references().get(item["id"]) or mixtrack3_references().get(item["id"]) or PLATINUM_REFERENCES.get(item["id"]) or mixtrack2_references().get(item["id"]) or denon_references().get(item["id"]) or MC6000_REFERENCES.get(item["id"]) or MC7000_REFERENCES.get(item["id"]) or original_mixtrack_references().get(item["id"]) or PARTY_MIX_REFERENCES.get(item["id"]) or T1_REFERENCES.get(item["id"]) or PAD_REFERENCES.get(item["id"]) or PARTY2_REFERENCES.get(item["id"]) or terminal_mix_references().get(item["id"]) or DJ2GO2_REFERENCES.get(item["id"]) or NS4FX_REFERENCES.get(item["id"]) or MIXSTREAM_REFERENCES.get(item["id"]) or FLX10_REFERENCES.get(item["id"]) or DDJ1000_REFERENCES.get(item["id"]) or JOGVISION_REFERENCES.get(item["id"]) or MK2_REFERENCES.get(item["id"]) or INPULSE200_REFERENCES.get(item["id"]) or BEATMIX_REFERENCES.get(item["id"]) or MC2000_REFERENCES.get(item["id"]) or MIXON4_REFERENCES.get(item["id"]) or DICER_REFERENCES.get(item["id"]) or NS6II_REFERENCES.get(item["id"]) or N4_REFERENCES.get(item["id"]) or NEON_REFERENCES.get(item["id"]) or COMPACT_REFERENCES.get(item["id"]) or RP8000_REFERENCES.get(item["id"]) or SCRATCH_REFERENCES.get(item["id"]) or VCI300_REFERENCES.get(item["id"]) or VCI100MK2_REFERENCES.get(item["id"]) or PORTABLE_REFERENCES.get(item["id"]) or ORIGINAL200_REFERENCES.get(item["id"]) or VCI400_REFERENCES.get(item["id"]) or CMD_MICRO_REFERENCES.get(item["id"]) or IDJ2_REFERENCES.get(item["id"]) or LC6000_REFERENCES.get(item["id"]) or VCI100_REFERENCES.get(item["id"]) or XONE_REFERENCES.get(item["id"]) or READY_REFERENCES.get(item["id"]) or MIXER_ONE_REFERENCES.get(item["id"]) or UMIX_PRO2_REFERENCES.get(item["id"]) or INSTINCT_REFERENCES.get(item["id"]) or HERCULES_COMPACT_REFERENCES.get(item["id"]) or BCD3000_REFERENCES.get(item["id"]) or ORIGINAL_DJ2GO_REFERENCES.get(item["id"]) or AIR_REFERENCES.get(item["id"]) or SC2000_REFERENCES.get(item["id"]) or MIXAGE_REFERENCES.get(item["id"]) or ORIGINAL300_REFERENCES.get(item["id"]) or TOTAL_OMNI_REFERENCES.get(item["id"]) or XSESSION_REFERENCES.get(item["id"]) or STUDIO4A_REFERENCES.get(item["id"]) or DJC4_REFERENCES.get(item["id"]) or MC3000_REFERENCES.get(item["id"]) or RMX2_REFERENCES.get(item["id"]) or P32_REFERENCES.get(item["id"]) or KAOSS_REFERENCES.get(item["id"]) or FIRSTMIX_REFERENCES.get(item["id"]) or DISCOVER_REFERENCES.get(item["id"]) or DISCOVER_PRO_REFERENCES.get(item["id"]) or DJM101_REFERENCES.get(item["id"]) or RDJ2_IE_REFERENCES.get(item["id"]) or RDJ2_CONTROLLER_REFERENCES.get(item["id"]) or RADIUS_REFERENCES.get(item["id"]) or ORIGINAL_DJ2GO2_REFERENCES.get(item["id"]) or TM8_REFERENCES.get(item["id"]) or QUAD_REFERENCES.get(item["id"]) or IMIX_REFERENCES.get(item["id"]) or MCX_REFERENCES.get(item["id"]) or MIX101_REFERENCES.get(item["id"]) or TEK2_REFERENCES.get(item["id"]) or KDJ_REFERENCES.get(item["id"]) or UMIX2_REFERENCES.get(item["id"]) or ORIGINAL_UMIX_REFERENCES.get(item["id"]) or MIXTOUR_REFERENCES.get(item["id"]) or BEATPAD2_REFERENCES.get(item["id"]) or MIXTOUR_PRO_REFERENCES.get(item["id"]) or TWEAKER_REFERENCES.get(item["id"]) or T7_REFERENCES.get(item["id"]) or BUDDY_REFERENCES.get(item["id"]) or SLATE_REFERENCES.get(item["id"]) or NDX500_REFERENCES.get(item["id"]) or FOUR_REFERENCES.get(item["id"]) or LIVE_REFERENCES.get(item["id"]) or G2V_REFERENCES.get(item["id"]) or RMP4_REFERENCES.get(item["id"]) or IDJ3_REFERENCES.get(item["id"]) or STUDIO2A_REFERENCES.get(item["id"]) or TOUCH_REFERENCES.get(item["id"]) or SEVENTY_REFERENCES.get(item["id"]) or NV_REFERENCES.get(item["id"]) or DJ3_REFERENCES.get(item["id"]) or RMX90_REFERENCES.get(item["id"]) or DJ505_REFERENCES.get(item["id"]) or MM1_REFERENCES.get(item["id"]) or FIXED_MIXER_REFERENCES.get(item["id"]) or SMK25_REFERENCES.get(item["id"]) or FIGHTER_REFERENCES.get(item["id"]) or MINI_REFERENCES.get(item["id"]) or RGB_REFERENCES.get(item["id"]) or CDJ101_REFERENCES.get(item["id"]) or SR2_REFERENCES.get(item["id"]) or KEYLAB_REFERENCES.get(item["id"]) or KONTROL_ONE_REFERENCES.get(item["id"]) or SPECTRA_REFERENCES.get(item["id"]) or DUO_REFERENCES.get(item["id"]) or P1_REFERENCES.get(item["id"]) or DDM_REFERENCES.get(item["id"]) or SCS3M_REFERENCES.get(item["id"]) or BCR_REFERENCES.get(item["id"]) or SC5000M_REFERENCES.get(item["id"]) or PRIME_REFERENCES.get(item["id"]) or ONE2_REFERENCES.get(item["id"]) or NANO2_REFERENCES.get(item["id"]) or PAD2_REFERENCES.get(item["id"]) or PRIME4_REFERENCES.get(item["id"]) or MP2015_REFERENCES.get(item["id"]) or ONE_REFERENCES.get(item["id"]) or PRIME_AIO_REFERENCES.get(item["id"]) or ENGINE_FIXED_REFERENCES.get(item["id"]) or MASTER_REFERENCES.get(item["id"]) or SP404_REFERENCES.get(item["id"]) or EUPHONIA_REFERENCES.get(item["id"]) or NUMARK_2026_REFERENCES.get(item["id"]) or SCENE_REFERENCES.get(item["id"]) or CRSS_REFERENCES.get(item["id"]) or MK4_REFERENCES.get(item["id"]) or A9_REFERENCES.get(item["id"]) or SLAB_REFERENCES.get(item["id"]) or A7_REFERENCES.get(item["id"]) or AN_REFERENCES.get(item["id"]) or REV7_REFERENCES.get(item["id"]) or IGNITE_REFERENCES.get(item["id"]) or ULTRA_REFERENCES.get(item["id"]) or NXS2_REFERENCES.get(item["id"]) or S9_REFERENCES.get(item["id"]) or V10_REFERENCES.get(item["id"]) or DJM450_REFERENCES.get(item["id"]) or AIR_PLUS_REFERENCES.get(item["id"]) or DJ4SET_REFERENCES.get(item["id"]) or NS6_REFERENCES.get(item["id"]) or ORIGINAL_MC6000_REFERENCES.get(item["id"]) or SPIN2_REFERENCES.get(item["id"]) or PRIMO_REFERENCES.get(item["id"]) or BEATMIX_ORIGINAL_REFERENCES.get(item["id"]) or VCM100_REFERENCES.get(item["id"]) or XWDJ1_REFERENCES.get(item["id"]) or MK3_REFERENCES.get(item["id"]) or T10_REFERENCES.get(item["id"]) or XONE96_REFERENCES.get(item["id"]) or XONE_FADER_REFERENCES.get(item["id"]) or VMS5_REFERENCES.get(item["id"]) or VMS41_TRAKTOR_REFERENCES.get(item["id"]) or PROMIXER_REFERENCES.get(item["id"]) or S3_REFERENCES.get(item["id"]) or DOCK_REFERENCES.get(item["id"]) or VCI300_MKII_REFERENCES.get(item["id"]) or LEGACY_DJM_REFERENCES.get(item["id"]) or MIXDECK_REFERENCES.get(item["id"]) or MIXON8_REFERENCES.get(item["id"]) or STEALTH_REFERENCES.get(item["id"]) or S11_REFERENCES.get(item["id"]) or MIXER_REFERENCES.get(item["id"]) or {"url": item["source"],
            "sha256": reference[1] if reference else "b1274a096816e795f0d35183527fc69a170d6d21a4f0e9151a1dae7810e3aee7"}
        definitions.append({"id": item["definition"], "name": item["id"], "transport": "midi",
                            "source": source,
                            "implementedInputCount": len(item["inputs"]), "implementedOutputCount": len(item["outputs"]),
                            "sourceInputCount": None, "sourceOutputCount": None,
                            "unresolved": [{"reason": gap} for gap in item.get("gaps", CDJ_GAPS)] if item.get("role") == "player" else
                            [{"reason": reason} for reason in [("Additional modes, FX, displays and input audio routing remain unimplemented." if item.get("audioOutput") else "Additional modes, FX, displays and audio routing remain unimplemented.")] + item.get("gaps", [])]})
    for name, pending in PENDING_DDJ.items():
        if canonical(name) in reviewed_ids:
            continue
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
    for entry in djay["rows"]:
        model = add_model(entry["name"], entry["url"])
        model["comparisonSupport"] = {"djay": {"sourceName": entry["sourceName"], "platforms": entry["platforms"],
                                               "limitations": entry["limitations"], "source": entry["url"]}}
    for entry in virtualdj["rows"]:
        if entry["role"] == "dvs-medium":
            continue
        model = add_model(entry["name"], entry["url"], entry["role"])
        model.setdefault("comparisonSupport", {})["virtualDJ"] = {
            "sourceName": entry["sourceName"], "category": entry["category"], "source": entry["url"]}
    for model in models.values():
        candidates = [profile for profile in profiles if profile["definition"] in model["definitions"]]
        profile = next((item for item in candidates if item["id"] == model.get("profile")), None)
        if profile is None:
            profile = max(candidates, key=lambda item: len(item["inputs"])) if candidates else None
        if profile and model["implementation"] == "partial-midi-profile":
            model.update(profile=profile["id"], automaticControls=profile["autoSelect"])
        model["controlActions"] = sorted({item["action"] + (":" + item["targetDeck"] if item.get("targetDeck") else "")
                                          for item in profile["inputs"]}) if profile else []
        model["inputBindingCount"] = len(profile["inputs"]) if profile else None
        model["feedbackBindingCount"] = len(profile["outputs"]) if profile else None
        automatic = model["implementation"] in {"automatic-profile", "automatic-core-profile", "native-accessory", "native-midi"}
        model["connection"] = "Linux USB bridge" if model["implementation"] == "linux-bridge" else "USB MIDI" if profile or model["implementation"] == "automatic-profile" else "Existing native adapter" if automatic else "Protocol and iPad connection route require review"
        if model["id"] in {canonical(name) for name in DOCK_REFERENCES}:
            model["connection"] = "Manual exposed MIDI port only. Legacy dock authentication, CoreMIDI exposure and direct iPad connection remain unimplemented or unqualified."
        if model["id"] == canonical("Kontrol DJ KDJ500"):
            model["connection"] = "Native USB needs its driver and Konverter to produce MIDI. Direct iPad USB and a qualified bridge remain unimplemented."
        if model["id"] == canonical("Behringer BCD2000"):
            model["connection"] = "Non-class-compliant USB. Separate driver or MIDI bridge required."
        if model["id"] in {canonical(name) for name in DRIVER_REQUIRED}:
            model["connection"] = "Non-class-compliant USB. Windows/macOS drivers translate controls to MIDI. A desktop bridge is required for iPad; direct USB control is not implemented."
        model["audioRouting"] = "Automatic master 1–2 / headphones 3–4" if model["id"] in {canonical("Pioneer DDJ-FLX4"), canonical("Pioneer DDJ-400")} or bool(profile and profile.get("audioOutput") == "masterAndHeadphones") else "Existing native routing. Physical acceptance is open." if model["implementation"] in {"native-accessory", "native-midi"} else "Unverified. Automatic channel assignment is not enabled."
        if model["id"] in VMS_MODELS:
            model["audioRouting"] = VMS_AUDIO_GAP
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
        audits = [audit for name, audit in SOURCE_AUDITS.items() if model["id"] == canonical(name)]
        if audits:
            model["sourceAudits"] = audits
            for audit in audits:
                model["gaps"].extend(audit["gaps"])
                if audit["source"]["url"] not in model["sources"]:
                    model["sources"].append(audit["source"]["url"])

        if model["id"] in {canonical(name) for name in DRIVER_REQUIRED}:
            model["gaps"].append("Implement and qualify a driver-backed desktop MIDI bridge. A stored virtual-MIDI recipe does not provide direct iPad USB support.")
        for name, pending in PENDING_DDJ.items():
            if model["id"] == canonical(name):
                model["gaps"].append(pending["gap"])
        if model["implementation"] == "protocol-needed":
            if model.get("comparisonSupport", {}).get("virtualDJ", {}).get("category") == "Sound cards":
                model["gaps"].append("Audio interface or DVS kit. Native audio input/DVS routing and OS compatibility require review. A MIDI controller mapping is not implied.")
            else:
                model["gaps"].append("No implemented protocol is present in the pinned references. Manufacturer protocol work is required.")
        elif model["implementation"] == "adapter-needed":
            model["gaps"].append("A controller-specific protocol adapter is required.")
        elif model["implementation"] == "partial-midi-profile":
            model["gaps"].append("Untranslated controls and script behaviour remain in the linked definition records.")
        if profile and profile.get("role") == "player":
            model["playerSupport"] = {"requiredHardwareMode": profile.get("hardwareMode", "Software Control / USB-MIDI"), "midiInputImplemented": True,
                                      "recognisedNames": profile["aliases"],
                                      "automaticDeckAssignment": True, "hidImplemented": False, "displayFeedbackImplemented": False,
                                      "ledFeedbackImplemented": bool(profile["outputs"]), "automaticMultiDeviceAudioImplemented": False}
            model["gaps"].extend(profile.get("gaps", CDJ_GAPS))
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
                 "djaySource": {key: value for key, value in djay.items() if key != "rows"}, "djayRows": djay["rows"],
                 "virtualDJSource": {key: value for key, value in virtualdj.items() if key != "rows"}, "virtualDJRows": virtualdj["rows"],
                 "benchmarkRows": benchmark, "manufacturerInventoryReviewed": INVENTORY_REVIEWED, "models": ordered, "definitions": definitions,
                 "releaseGate": {"catalogueCompletionScope": "Pinned Serato, djay, VirtualDJ and Mixxx sources and listed manufacturer additions. Passive timecode media are source evidence, not digital devices. The wider manufacturer audit remains open.",
                                 "manufacturerAuditComplete": False, "catalogueComplete": all(all(canonical(name) in models for name in split_models(row["name"])) for row in benchmark)
                     and all(canonical(row["name"]) in models for row in djay["rows"])
                     and all(canonical(row["name"]) in models for row in virtualdj["rows"] if row["role"] != "dvs-medium")
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
    parser.add_argument("--djay", type=Path)
    parser.add_argument("--catalogue", type=Path, required=True)
    parser.add_argument("--runtime", type=Path, required=True)
    args = parser.parse_args()
    catalogue, runtime = build(args.cache, args.serato, args.djay)
    runtime_text = encode_runtime(runtime)
    write_json(args.catalogue, catalogue)
    args.runtime.parent.mkdir(parents=True, exist_ok=True)
    args.runtime.write_text(runtime_text, encoding="utf-8")
    print(json.dumps({"benchmarkRows": len(catalogue["benchmarkRows"]), "models": len(catalogue["models"]),
                      "definitions": len(catalogue["definitions"]), "runtimeProfiles": len(runtime["profiles"]),
                      "automaticControlCandidates": sum(profile["autoSelect"] for profile in runtime["profiles"]),
                      "implementation": dict(Counter(model["implementation"] for model in catalogue["models"]))}))


if __name__ == "__main__":
    main()
