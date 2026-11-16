"""Manufacturer-confirmed model records beyond the pinned software inventories."""

REVIEWED = "2026-11-17"
DENON_ENGINE = "https://support.denondj.com/en/support/solutions/articles/69000867689-engine-dj-hardware-supported-streaming-services"
RELOOP_COMPARISON = "https://www.reloop.com/djing-with-smart-devices-controllercomparisonchart"
MODELS = [
    ("Rane PERFORMER", "https://www.rane.com/downloads/?product=Rane+Performer"),
    ("Rane FOUR", "https://support.rane.com/en/support/solutions/articles/69000828752-rane-four-frequently-asked-questions"),
    ("Reloop Buddy", "https://www.reloop.com/reloop-buddy"),
    ("Reloop Mixtour Pro", "https://www.reloop.com/reloop-mixtour-pro"),
    ("Reloop Mixtour", RELOOP_COMPARISON),
    ("Reloop Beatpad 2", RELOOP_COMPARISON),
    *[("Denon DJ " + name, DENON_ENGINE) for name in [
        "PRIME 2", "PRIME GO", "PRIME GO+", "SC6000 PRIME", "SC6000M PRIME", "SC5000 PRIME", "SC5000M PRIME",
    ]],
]
