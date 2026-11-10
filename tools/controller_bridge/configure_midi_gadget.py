#!/usr/bin/env python3
"""Create a GenErik USB MIDI gadget with optional four-channel audio."""
import argparse
import os
from pathlib import Path
import re
import sys


LANGUAGE = "0x409"
S4_MK3_PRODUCT = "GenErik S4 Mk3 Bridge"
MODULAR_PRODUCTS = {
    "z1-mk2": "GenErik Z1 Mk2 Bridge",
    "x1-mk3": "GenErik X1 Mk3 Bridge",
    "s2-mk1": "GenErik S2 Mk1 Bridge",
    "s4-mk1": "GenErik S4 Mk1 Bridge",
}
GADGETS = Path("/sys/kernel/config/usb_gadget")
UDC_ROOT = Path("/sys/class/udc")


def parse_id(value):
    try:
        parsed = int(value, 0)
    except ValueError as error:
        raise argparse.ArgumentTypeError("Use a numeric USB ID, such as 0x1234.") from error
    if not 0 < parsed <= 0xffff:
        raise argparse.ArgumentTypeError("USB IDs must be from 0x0001 to 0xffff.")
    return parsed


def safe_text(value, label):
    if not value or any(ord(character) < 32 or ord(character) > 126 for character in value):
        raise ValueError(f"{label} must contain printable ASCII characters.")
    if len(value.encode("ascii")) > 126:
        raise ValueError(f"{label} must not exceed 126 bytes.")
    return value


def write_attribute(path, value):
    path.write_text(f"{value}\n", encoding="ascii")


def setup(args):
    if not sys.platform.startswith("linux"):
        raise RuntimeError("Configure the USB MIDI gadget on Linux bridge hardware.")
    if os.geteuid() != 0:
        raise RuntimeError("Run this command as root on the bridge hardware.")
    if not re.fullmatch(r"[A-Za-z0-9_.-]{1,32}", args.name):
        raise ValueError("The gadget name can use letters, numbers, dots, underscores and hyphens.")
    manufacturer = safe_text(args.manufacturer, "Manufacturer")
    s4_mk3 = getattr(args, "s4_mk3", False)
    modular = getattr(args, "traktor", None)
    product = safe_text(S4_MK3_PRODUCT if s4_mk3 else MODULAR_PRODUCTS.get(modular, args.product), "Product")
    has_audio = s4_mk3 or modular in {"z1-mk2", "s2-mk1", "s4-mk1"}
    serial = safe_text(args.serial, "Serial number")
    config_root = args.configfs_root
    gadget = config_root / args.name
    udc_names = {entry.name for entry in args.udc_root.iterdir()} if args.udc_root.is_dir() else set()

    if not config_root.is_dir():
        raise RuntimeError("USB gadget configfs is unavailable. Mount configfs and load the composite gadget support first.")
    if args.udc not in udc_names:
        raise RuntimeError(f"USB device controller {args.udc!r} was not found under {args.udc_root}.")
    if not args.apply:
        raise RuntimeError("No gadget was changed. Add --apply to create the USB MIDI gadget.")
    if gadget.exists():
        raise RuntimeError(f"Gadget path already exists: {gadget}. No existing gadget was changed.")

    function = gadget / "functions/midi.usb0"
    configuration = gadget / "configs/c.1"
    audio = gadget / "functions/uac2.usb0"
    directories = [
        gadget,
        gadget / f"strings/{LANGUAGE}",
        configuration,
        configuration / f"strings/{LANGUAGE}",
        function,
    ]
    if has_audio:
        directories.append(audio)
    links = []
    bound = False
    try:
        for directory in directories:
            directory.mkdir()
        write_attribute(gadget / "idVendor", f"0x{args.vendor_id:04x}")
        write_attribute(gadget / "idProduct", f"0x{args.product_id:04x}")
        write_attribute(gadget / "bcdDevice", "0x0100")
        write_attribute(gadget / "bcdUSB", "0x0200")
        write_attribute(gadget / f"strings/{LANGUAGE}/serialnumber", serial)
        write_attribute(gadget / f"strings/{LANGUAGE}/manufacturer", manufacturer)
        write_attribute(gadget / f"strings/{LANGUAGE}/product", product)
        write_attribute(configuration / "MaxPower", "100")
        write_attribute(configuration / f"strings/{LANGUAGE}/configuration", "USB MIDI and Audio" if has_audio else "USB MIDI")
        write_attribute(function / "in_ports", "1")
        write_attribute(function / "out_ports", "1")
        function_link = configuration / "midi.usb0"
        function_link.symlink_to(Path("../../functions/midi.usb0"))
        links.append(function_link)
        if has_audio:
            # Capture is from the Linux gadget's perspective. The iPad sends four channels.
            write_attribute(audio / "c_chmask", "0x33")
            write_attribute(audio / "c_srate", "48000")
            write_attribute(audio / "c_ssize", "4")
            if modular == "s4-mk1":
                write_attribute(audio / "p_chmask", "0x33")
                write_attribute(audio / "p_srate", "48000")
                write_attribute(audio / "p_ssize", "4")
                write_attribute(gadget / "bcdDevice", "0x0101")
            else:
                write_attribute(audio / "p_chmask", "0")
            if (audio / "function_name").exists():
                write_attribute(audio / "function_name", product)
            audio_link = configuration / "uac2.usb0"
            audio_link.symlink_to(Path("../../functions/uac2.usb0"))
            links.append(audio_link)
        write_attribute(gadget / "UDC", args.udc)
        bound = True
        print(f"USB MIDI gadget {args.name!r} is bound to {args.udc}.")
        if has_audio:
            print("The gadget exposes four audio channels and two-way MIDI.")
        else:
            print("The gadget carries MIDI only.")
        print(f"Run the relay with the ALSA raw MIDI node created for {args.name!r}.")
    except BaseException:
        if bound:
            try:
                write_attribute(gadget / "UDC", "")
            except OSError:
                pass
        for link in reversed(links):
            try:
                link.unlink()
            except OSError:
                pass
        for directory in reversed(directories):
            try:
                directory.rmdir()
            except OSError:
                pass
        raise


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--name", help="New configfs gadget name")
    model = parser.add_mutually_exclusive_group()
    model.add_argument("--s4-mk3", action="store_true", help="Expose the S4 Mk3 composite audio and MIDI bridge")
    model.add_argument("--traktor", choices=MODULAR_PRODUCTS, help="Expose a named Traktor bridge")
    parser.add_argument("--vendor-id", required=True, type=parse_id, help="USB vendor ID assigned to this bridge")
    parser.add_argument("--product-id", required=True, type=parse_id, help="USB product ID assigned to this bridge")
    parser.add_argument("--manufacturer", required=True, help="USB manufacturer string")
    parser.add_argument("--product", default="GenErik Z1 MIDI Bridge", help="USB product string")
    parser.add_argument("--serial", required=True, help="Unique USB serial string")
    parser.add_argument("--udc", required=True, help="USB device controller name from /sys/class/udc")
    parser.add_argument("--apply", action="store_true", help="Create and bind the gadget")
    parser.add_argument("--configfs-root", type=Path, default=GADGETS, help=argparse.SUPPRESS)
    parser.add_argument("--udc-root", type=Path, default=UDC_ROOT, help=argparse.SUPPRESS)
    args = parser.parse_args()
    default_name = "generik_s4mk3" if args.s4_mk3 else "generik_z1"
    args.name = args.name or (f"generik_{args.traktor}" if args.traktor else default_name)
    setup(args)


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, ValueError) as error:
        sys.exit(str(error))
