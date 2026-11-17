"""Manufacturer sources and model records for the controller catalogue."""

REVIEWED = "2026-11-17"
DENON_ENGINE = "https://support.denondj.com/en/support/solutions/articles/69000867689-engine-dj-hardware-supported-streaming-services"
RELOOP_COMPARISON = "https://www.reloop.com/djing-with-smart-devices-controllercomparisonchart"
MODELS = [
    ("Denon MC3000", "https://cdn.inmusicbrands.com/denondj/legacy/mc3000/MC3000EM_ENG_IM_v00.pdf"),
    ("AlphaTheta DJM-A7", "https://alphatheta.com/en/product/dj-mixer/djm-a7/black/"),
    ("AlphaTheta XDJ-AN", "https://alphatheta.com/en/product/all-in-one-dj-system/xdj-an/black/"),
    ("AlphaTheta RMX-IGNITE", "https://alphatheta.com/en/product/effector/rmx-ignite/black/"),
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
