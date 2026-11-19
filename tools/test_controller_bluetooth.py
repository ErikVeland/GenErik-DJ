"""Check the purpose strings required before the system Bluetooth MIDI browser opens."""
import plistlib
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class ControllerBluetoothPrivacyTests(unittest.TestCase):
    def test_each_ios_host_explains_bluetooth_access(self):
        for name in ["iPad", "iPadValidation"]:
            with self.subTest(host=name):
                with (ROOT / "Replica" / name / "Info.plist").open("rb") as source:
                    purpose = plistlib.load(source).get("NSBluetoothAlwaysUsageDescription")
                self.assertTrue(isinstance(purpose, str) and purpose.strip(),
                                "The system Bluetooth browser requires an app purpose string.")


if __name__ == "__main__":
    unittest.main()
