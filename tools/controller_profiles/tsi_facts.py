"""Inspect TSI binding facts without executing or rewriting a controller mapping.

Frame reference: https://github.com/ivanz/TraktorMappingFileFormat/wiki/File-Format-Specification
Encoder mode0 is3F/41. Mode1 is7F/01. Unknown fields remain uninterpreted.
This tool does not generate runtime recipes or infer MIDI from generic templates.
"""
import argparse
import base64
import binascii
import json
import math
import struct
import xml.etree.ElementTree as ET
from pathlib import Path

LIMIT = 4 * 1024 * 1024


def _uint(data, offset=0):
    if offset < 0 or offset + 4 > len(data):
        raise ValueError("Truncated TSI field")
    return struct.unpack_from(">I", data, offset)[0]


def _string(data, offset=0):
    length = _uint(data, offset)
    end = offset + 4 + length * 2
    if length > 256 or end > len(data):
        raise ValueError("Invalid TSI string length")
    return data[offset + 4:end].decode("utf-16-be"), end


def _frames(data):
    result = []
    offset = 0
    while offset < len(data):
        if offset + 8 > len(data) or len(result) >= 8192:
            raise ValueError("Invalid TSI frame count or header")
        tag = data[offset:offset + 4].decode("ascii")
        size = _uint(data, offset + 4)
        end = offset + 8 + size
        if not all("A" <= c <= "Z" for c in tag) or end > len(data):
            raise ValueError("Invalid TSI frame tag or size")
        result.append((tag, data[offset + 8:end]))
        offset = end
    return result


def _one(frames, tag):
    matches = [data for name, data in frames if name == tag]
    if len(matches) != 1:
        raise ValueError("Missing or repeated TSI frame: " + tag)
    return matches[0]


def _array(data, tag):
    count = _uint(data)
    frames = _frames(data[4:])
    if count > 8192 or count != len(frames) or any(name != tag for name, _ in frames):
        raise ValueError("Invalid TSI array")
    return [payload for _, payload in frames]


def _definitions(data):
    result = {}
    for payload in _array(data, "DCDT"):
        name, offset = _string(payload)
        if name in result or len(payload) - offset != 20:
            raise ValueError("Invalid or repeated TSI MIDI definition")
        result[name] = _uint(payload, offset + 12)
    return result


def _device(payload, include_unassigned=False):
    name, offset = _string(payload)
    fields = _frames(_one(_frames(payload[offset:]), "DDAT"))
    definitions = _frames(_one(fields, "DDDC"))
    inputs = _definitions(_one(definitions, "DDCI"))
    outputs = _definitions(_one(definitions, "DDCO"))
    container = _frames(_one(fields, "DDCB"))
    bindings = {}
    for binding in _array(_one(container, "DCBM"), "DCBM"):
        index = _uint(binding)
        signal, end = _string(binding, 4)
        if index in bindings or end != len(binding):
            raise ValueError("Invalid or repeated TSI binding")
        bindings[index] = signal
    rows = []
    for mapping in _array(_one(container, "CMAS"), "CMAI"):
        index, direction, command = (_uint(mapping, at) for at in [0, 4, 8])
        signal = bindings.get(index)
        available = inputs if direction == 0 else outputs
        settings = _one(_frames(mapping[12:]), "CMAD")
        unassigned = index not in bindings
        if (direction not in [0, 1] or len(settings) < 52
                or (unassigned and not include_unassigned)
                or (not unassigned and signal not in available)):
            raise ValueError("Invalid TSI mapping reference or settings")
        comment_end = 52 + 2 * _uint(settings, 48)
        if comment_end + 24 > len(settings):
            raise ValueError("Truncated TSI mapping comment or conditions")
        sensitivity, acceleration = struct.unpack_from(">ff", settings, 28)
        if not math.isfinite(sensitivity) or not math.isfinite(acceleration):
            raise ValueError("Non-finite TSI encoder setting")
        rows.append({
            "bindingID": index, "signal": signal, "direction": direction, "commandID": command,
            "controllerType": _uint(settings, 4), "interactionMode": _uint(settings, 8),
            "target": _uint(settings, 12), "inverted": _uint(settings, 20),
            "rotarySensitivity": sensitivity, "rotaryAcceleration": acceleration,
            "encoderMode": None if unassigned else available[signal],
            "unassigned": unassigned,
            "comment": settings[52:comment_end].decode("utf-16-be"),
            "settingsHex": settings.hex(),
            "conditions": [[_uint(settings, comment_end + at), _uint(settings, comment_end + at + 8)]
                           for at in [0, 12]],
        })
    return {"name": name, "mappings": rows}


def inspect_tsi(source, *, include_unassigned=False):
    """Return used binding facts from a bounded XML/base64 TSI document."""
    if len(source) > LIMIT or b"<!DOCTYPE" in source.upper() or b"<!ENTITY" in source.upper():
        raise ValueError("Unsupported TSI size or document declaration")
    try:
        root = ET.fromstring(source)
        entries = [node for node in root.iter("Entry") if node.get("Name") == "DeviceIO.Config.Controller"]
        if root.tag != "NIXML" or len(entries) != 1:
            raise ValueError("Missing or repeated TSI controller document")
        blob = base64.b64decode("".join(entries[0].get("Value", "").split()), validate=True)
        if not blob or len(blob) > LIMIT:
            raise ValueError("Invalid TSI binary size")
        root_frames = _frames(blob)
        if len(root_frames) != 1:
            raise ValueError("Repeated TSI root frame")
        contents = _frames(_one(root_frames, "DIOM"))
        return [_device(data, include_unassigned) for data in _array(_one(contents, "DEVS"), "DEVI")]
    except (ET.ParseError, binascii.Error, UnicodeError, struct.error) as error:
        raise ValueError("Invalid TSI document") from error


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("path", type=Path)
    parser.add_argument("--include-unassigned", action="store_true",
                        help="Report unassigned records without inferring MIDI signals")
    args = parser.parse_args()
    if args.path.stat().st_size > LIMIT:
        parser.error("TSI file exceeds4 MiB")
    print(json.dumps(inspect_tsi(args.path.read_bytes(), include_unassigned=args.include_unassigned), indent=2, allow_nan=False))
