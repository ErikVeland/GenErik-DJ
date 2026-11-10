import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

from configure_midi_gadget import setup


class GadgetSetupChecks(unittest.TestCase):
    def test_creates_a_gadget_with_its_own_functions_and_configs(self):
        self.check_gadget(s4_mk3=False)

    def test_creates_a_four_channel_audio_and_midi_gadget_for_s4_mk3(self):
        self.check_gadget(s4_mk3=True)

    def test_creates_named_modular_gadgets_with_audio_only_for_the_z1(self):
        self.check_gadget(s4_mk3=False, traktor="z1-mk2", expected_product="GenErik Z1 Mk2 Bridge")
        self.check_gadget(s4_mk3=False, traktor="x1-mk3", expected_product="GenErik X1 Mk3 Bridge")

    def check_gadget(self, s4_mk3, traktor=None, expected_product=None):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            configfs_root = root / "usb_gadget"
            udc_root = root / "udc"
            configfs_root.mkdir()
            udc_root.mkdir()
            (udc_root / "dummy-udc").mkdir()
            name = "generik_s4mk3" if s4_mk3 else "generik_z1"
            gadget = configfs_root / name
            configuration = gadget / "configs/c.1"
            original_mkdir = Path.mkdir

            def create_configfs_directory(path, mode=0o777, parents=False, exist_ok=False):
                result = original_mkdir(path, mode=mode, parents=parents, exist_ok=exist_ok)
                if path == gadget:
                    for name in ("strings", "configs", "functions"):
                        original_mkdir(gadget / name)
                elif path == configuration:
                    original_mkdir(configuration / "strings")
                return result

            args = SimpleNamespace(
                name=name,
                s4_mk3=s4_mk3,
                traktor=traktor,
                manufacturer="GenErik",
                product="Z1 MIDI Bridge",
                serial="bridge-001",
                configfs_root=configfs_root,
                udc_root=udc_root,
                udc="dummy-udc",
                apply=True,
                vendor_id=0x1234,
                product_id=0x0001,
            )

            with patch("configure_midi_gadget.sys.platform", "linux"), \
                    patch("configure_midi_gadget.os.geteuid", return_value=0), \
                    patch.object(Path, "mkdir", new=create_configfs_directory):
                setup(args)

            self.assertTrue((gadget / "functions/midi.usb0").is_dir())
            self.assertTrue((gadget / "configs/c.1/midi.usb0").is_symlink())
            self.assertEqual((gadget / "UDC").read_text(encoding="ascii"), "dummy-udc\n")
            self.assertFalse((configfs_root / "functions").exists())
            self.assertFalse((configfs_root / "configs").exists())

            audio = gadget / "functions/uac2.usb0"
            product = gadget / "strings/0x409/product"
            if expected_product:
                self.assertEqual(product.read_text().strip(), expected_product)
            if s4_mk3 or traktor == "z1-mk2":
                self.assertTrue((configuration / "uac2.usb0").is_symlink())
                self.assertEqual((audio / "c_chmask").read_text().strip(), "0x33")
                self.assertEqual((audio / "p_chmask").read_text().strip(), "0")
                self.assertEqual((audio / "c_srate").read_text().strip(), "48000")
                if s4_mk3:
                    self.assertEqual(product.read_text().strip(), "GenErik S4 Mk3 Bridge")
            else:
                self.assertFalse(audio.exists())

    def test_without_apply_does_not_create_a_gadget(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            configfs_root = root / "usb_gadget"
            udc_root = root / "udc"
            configfs_root.mkdir()
            udc_root.mkdir()
            (udc_root / "dummy-udc").mkdir()
            args = SimpleNamespace(
                name="generik_z1",
                manufacturer="GenErik",
                product="Z1 MIDI Bridge",
                serial="bridge-001",
                configfs_root=configfs_root,
                udc_root=udc_root,
                udc="dummy-udc",
                apply=False,
                vendor_id=0x1234,
                product_id=0x0001,
            )

            with patch("configure_midi_gadget.sys.platform", "linux"), \
                    patch("configure_midi_gadget.os.geteuid", return_value=0):
                with self.assertRaisesRegex(RuntimeError, "Add --apply"):
                    setup(args)

            self.assertFalse((configfs_root / "generik_z1").exists())


if __name__ == "__main__":
    unittest.main()
