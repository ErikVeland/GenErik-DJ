"""Convert documented MIDI facts to bounded GenErik DJ control data."""
from collections import Counter
import math
import re
import xml.etree.ElementTree as ET

DECK_KEYS = {
    "play": "play", "cue_default": "cueReturn", "pfl": "cue", "beatsync": "sync",
    "sync_enabled": "sync", "keylock": "keylock", "volume": "level", "pregain": "gain",
    "rate": "tempo", "filterLow": "low", "filterMid": "mid", "filterHigh": "high",
    "reloop_toggle": "loop", "reloop_exit": "loop", "loop_halve": "loopDown", "loop_double": "loopUp",
    "beatjump_backward": "jumpBack", "beatjump_forward": "jumpForward", "LoadSelectedTrack": "load",
}
MASTER_KEYS = {"crossfader": "crossfader", "headMix": "cueMix", "headGain": "monitor",
               "headVolume": "monitor", "gain": "master", "volume": "master"}
LIBRARY_KEYS = {"MoveVertical": "browse", "SelectTrackKnob": "browse", "SelectPlaylist": "browseGroups",
                "MoveFocusForward": "openGroup", "MoveFocusBackward": "openGroup", "MoveFocus": "openGroup"}
RELATIVE_OPTIONS = {"selectknob": "twosComplement", "spread64": "binaryOffset", "rot64": "binaryOffset"}
FEEDBACK = {prefix + deck for prefix in ["play", "sync", "keylock", "cue", "loop"] for deck in "AB"}
FEEDBACK |= {f"hotcue{slot}{deck}" for slot in range(1, 9) for deck in "AB"}
SAFE_OPTIONS = {"normal", "button", "soft-takeover", "invert", "fourteen-bit-msb", "fourteen-bit-lsb"}


def operation(group, key):
    deck = re.fullmatch(r"\[Channel([1-4])\]", group)
    if deck:
        number = int(deck[1])
        suffix = "A" if number % 2 == 1 else "B"
        if key in DECK_KEYS:
            return DECK_KEYS[key] + suffix, None
        hotcue = re.fullmatch(r"hotcue_([1-8])_activate", key)
        if hotcue:
            return "hotcue" + hotcue[1] + suffix, None
    if group in {"[Master]", "[Main]"} and key in MASTER_KEYS:
        return MASTER_KEYS[key], None
    if group in {"[Library]", "[Playlist]"} and key in LIBRARY_KEYS:
        return LIBRARY_KEYS[key], None
    equalizer = re.fullmatch(r"\[EqualizerRack1_\[Channel([1-4])\]_Effect1\]", group)
    if equalizer and key in {"parameter1", "parameter2", "parameter3"}:
        return {"parameter1": "low", "parameter2": "mid", "parameter3": "high"}[key] + ("A" if int(equalizer[1]) % 2 == 1 else "B"), None
    quick = re.fullmatch(r"\[QuickEffectRack1_\[Channel([1-4])\]\]", group)
    if quick and key == "super1":
        return "filterKnob" + ("A" if int(quick[1]) % 2 == 1 else "B"), None
    return None, "unsupported-operation"


def number(text):
    return int(text.strip(), 0)


def options(control):
    parent = control.find("options")
    return {child.tag.lower() for child in parent} if parent is not None else set()


def control_record(control):
    group, key = control.findtext("group", ""), control.findtext("key", "")
    opts = options(control)
    if "script-binding" in opts:
        return None, "script-behaviour"
    action, reason = operation(group, key)
    if action is None:
        return None, reason
    unknown = opts - SAFE_OPTIONS - RELATIVE_OPTIONS.keys()
    if unknown:
        return None, "unsupported-encoding: " + ",".join(sorted(unknown))
    try:
        status = number(control.findtext("status", ""))
        kind = {0x80: "note", 0x90: "note", 0xA0: "polyPressure", 0xB0: "control", 0xC0: "program", 0xD0: "pressure", 0xE0: "pitch"}.get(status & 0xF0)
        if not 0x80 <= status <= 0xEF or kind is None:
            raise ValueError()
        address = number(control.findtext("midino", "0"))
        if not 0 <= address < 128:
            raise ValueError()
    except ValueError:
        return None, "invalid-address"
    if "fourteen-bit-lsb" in opts:
        return None, "paired-low-byte"
    encoding = next((value for option, value in RELATIVE_OPTIONS.items() if option in opts), "absolute")
    if "fourteen-bit-msb" in opts:
        encoding = "paired14Bit"
        if kind != "control" or address >= 32:
            return None, "unsupported-high-resolution-pair"
    if action in {"browse", "browseGroups"} and encoding == "absolute":
        return None, "unspecified-relative-encoding"
    if "button" in opts or "switch" in opts:
        return None, "nonstandard-button-semantics"
    record = {"action": action, "kind": kind, "channel": status & 15, "number": address,
              "encoding": encoding, "inverted": "invert" in opts}
    target = re.search(r"\[Channel([1-4])\]", group)
    if target:
        record["targetDeck"] = "abcd"[int(target[1]) - 1]
    return record, None


def convert_xml(path):
    root = ET.parse(path).getroot()
    controls = root.findall(".//control")
    inputs, unresolved, input_records = [], [], []
    low_bytes = {(number(control.findtext("status", "0")), number(control.findtext("midino", "0")), control.findtext("group", ""),
                  control.findtext("key", "").replace(".inputLSB", "").replace(".inputMSB", ""))
                 for control in controls if "fourteen-bit-lsb" in options(control)
                 or control.findtext("key", "").endswith(".inputLSB")}
    for control in controls:
        binding, reason = control_record(control)
        if binding and binding["encoding"] == "paired14Bit":
            status = 0xB0 | binding["channel"]
            pair_key = control.findtext("key", "").replace(".inputLSB", "").replace(".inputMSB", "")
            if (status, binding["number"] + 32, control.findtext("group", ""), pair_key) not in low_bytes:
                binding, reason = None, "missing-paired-low-byte"
        record = {"group": control.findtext("group", ""), "key": control.findtext("key", ""),
                  "status": control.findtext("status", ""), "number": control.findtext("midino", ""),
                  "disposition": "mapped" if binding else reason}
        if binding:
            record["binding"] = binding
            if binding not in inputs:
                inputs.append(binding)
        elif reason != "paired-low-byte":
            unresolved.append({"group": control.findtext("group", ""), "key": control.findtext("key", ""),
                               "status": control.findtext("status", ""), "number": control.findtext("midino", ""),
                               "reason": reason})
        input_records.append(record)
    outputs, output_records = [], []
    for output in root.findall(".//output"):
        key = output.findtext("key", "").removesuffix("_indicator")
        if re.fullmatch(r"hotcue_[1-8]_enabled", key):
            key = key.removesuffix("_enabled") + "_activate"
        action, reason = operation(output.findtext("group", ""), key)
        source_record = {"group": output.findtext("group", ""), "key": output.findtext("key", ""),
                         "status": output.findtext("status", ""), "number": output.findtext("midino", ""),
                         "minimum": output.findtext("minimum"), "maximum": output.findtext("maximum"),
                         "on": output.findtext("on"), "off": output.findtext("off")}
        record = None
        if action not in FEEDBACK:
            reason = "unsupported-feedback-operation"
        else:
            try:
                status, address = number(output.findtext("status", "")), number(output.findtext("midino", ""))
                on, off = number(output.findtext("on", "0x7f")), number(output.findtext("off", "0"))
                lower = float(output.findtext("minimum", "0"))
                upper = float(output.findtext("maximum", "1"))
                if not all(math.isfinite(value) for value in [lower, upper]) or lower > upper:
                    raise ValueError()
                if status & 0xF0 not in {0x90, 0xB0} or not all(0 <= value < 128 for value in [address, on, off]):
                    raise ValueError()
                record = {"action": action, "kind": "note" if status & 0xF0 == 0x90 else "control", "channel": status & 15, "number": address,
                          "onValue": on if lower <= 1 <= upper else off,
                          "offValue": on if lower <= 0 <= upper else off, "offUsesNoteOn": True}
                target = re.search(r"\[Channel([1-4])\]", output.findtext("group", ""))
                if target:
                    record["targetDeck"] = "abcd"[int(target[1]) - 1]
            except ValueError:
                reason = "unsupported-feedback-encoding"
        source_record["disposition"] = "mapped" if record else reason
        if record:
            source_record["binding"] = record
            if record not in outputs:
                outputs.append(record)
        output_records.append(source_record)
    conflicts = Counter((entry["kind"], entry["channel"], entry["number"]) for entry in inputs)
    ambiguous = {address for address, count in conflicts.items() if count > 1}
    if ambiguous:
        unresolved.extend({"reason": "conflicting-input-actions", "address": list(address)} for address in sorted(ambiguous))
        inputs = [entry for entry in inputs if (entry["kind"], entry["channel"], entry["number"]) not in ambiguous]
    for record in input_records:
        binding = record.get("binding")
        if binding and binding not in inputs:
            record["disposition"] = "conflicting-input-actions"
            del record["binding"]
    output_addresses = Counter((entry["kind"], entry["channel"], entry["number"]) for entry in outputs)
    outputs = [entry for entry in outputs if output_addresses[(entry["kind"], entry["channel"], entry["number"])] == 1]
    for record in output_records:
        if record.get("binding") and record["binding"] not in outputs:
            record["disposition"] = "conflicting-feedback-actions"
            del record["binding"]
    return {"name": root.findtext("info/name", path.stem),
            "identifiers": [controller.get("id", "") for controller in root.findall("controller")],
            "scripts": [file.get("filename") for file in root.findall(".//scriptfiles/file")],
            "inputs": inputs, "outputs": outputs, "unresolved": unresolved,
            "inputRecords": input_records, "outputRecords": output_records,
            "inputCount": len(controls), "outputCount": len(root.findall(".//output"))}
