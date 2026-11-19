"""Reuse the MIDI contract explicitly shared by VCI-300 and VCI-300MKII."""
from copy import deepcopy
from vci300 import vci300_profiles, VCI300_REFERENCES

MKII_MANUAL = 'https://manual.mixxx.org/2.4/en_gb/hardware/controllers/vestax_vci_300'
MKII_MANUAL_SHA = 'db1c1ef0247057ef6d76364904fb2cee14a6ad29d3ed3133990e236f23f2d73f'
VCI300_MKII_REFERENCES = {'Vestax VCI-300MKII': {
    'url': MKII_MANUAL, 'sha256': MKII_MANUAL_SHA,
    'relatedSources': [VCI300_REFERENCES['Vestax VCI-300']],
    'review': 'The primary software mapping project explicitly states in its versioned manual that VCI-300 MKII does not change the original MIDI mapping. Reuse the existing reviewed61-input/24-lamp contract, paired1600-count cyclic jogs, exact nine-bit tempo, scoped modifiers and five startup/shutdown bytes. Keep a distinct MKII identity. No downloaded code executes. The manual separately describes higher analogue gain with DC7 power, optional digital crossfader, direct audio thru, jog-sensor adjusters and an extra headphone socket. Those changes do not establish native audio routing, hardware gain/sensitivity calibration, complete mode/lifecycle parity or physical/iPad/A10X acceptance. The old wiki qualified its statement with AFAIK. The cited versioned manual states compatibility explicitly. This remains a primary software-project claim, not independent manufacturer wire verification.'
}}


def vci300_mkii_profiles():
    result = deepcopy(vci300_profiles()[0])
    result.update(id='Vestax VCI-300MKII', definition='reviewed:vci-300mkii-documented-shared-midi',
                  aliases=['Vestax VCI-300MKII', 'VCI-300MKII', 'VCI-300 MKII', 'Vestax VCI-300 MKII', 'VCI-300MK2', 'VCI-300 MK2'],
                  excludedAliases=['VCI-100', 'VCI-100MK2', 'VCI-300', 'VCI-400', 'VFX-1'],
                  source=MKII_MANUAL,
                  hardwareMode='VCI-300MKII raw USB MIDI core. The Mixxx project explicitly documents the same MIDI mapping as VCI-300. Configure app audio separately. Hardware jog sensitivity and analogue gain need qualification.',
                  scope='Automatic61-input native two-deck core with24 steady lamps, paired cyclic jogs, exact nine-bit tempo, three cues, native loops and Scroll/PFL loading. Documented shared MIDI contract. Audio and full parity remain open.',
                  gaps=['Compatibility is explicitly documented by the primary software mapping project, not independently verified against a manufacturer MKII wire table. Analogue gain/DC7 supply, direct audio thru, optional digital fader and jog-sensor sensitivity remain hardware-specific. Complete modes/feedback/lifecycle, audio routing/calibration and physical/iPad/A10X acceptance remain open.'])
    return [result]
