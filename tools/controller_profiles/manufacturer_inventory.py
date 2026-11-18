"""Manufacturer sources and model records for the controller catalogue."""
from mixtour_pro import MIXTOUR_PRO_AUDIT

REVIEWED = "2026-11-17"
DENON_ENGINE = "https://support.denondj.com/en/support/solutions/articles/69000867689-engine-dj-hardware-supported-streaming-services"
RELOOP_COMPARISON = "https://www.reloop.com/djing-with-smart-devices-controllercomparisonchart"
DRIVER_REQUIRED = {"Reloop Jockey 3 ME", "Reloop Digital Jockey 2 Master Edition"}

SOURCE_AUDITS = {'Hercules DJControl Inpulse T7': {'source': {'url': 'https://drive.google.com/file/d/1ApFMGZpGgrtDCpAZ6vo4VdpAszKgEfnZ/view',
                                              'sha256': 'a6c14da8d8d8f660e4903a4070c92b9820f8dbf07e89583443b468b1004b93d3'},
                                   'discussion': 'https://community.algoriddim.com/t/hercules-inpulse-t7-support/20172/186',
                                   'format': 'Apple property list',
                                   'mappingVersion': 3,
                                   'inputRows': 402,
                                   'outputRows': 2,
                                   'declaredCustomClass': 'HerculesDJControlInpulseT7',
                                   'automaticSupportAdded': False,
                                   'gaps': ['Motor/platter reports, initialisation and lifecycle depend on '
                                            'absent HerculesDJControlInpulseT7 app code. The XML is not a '
                                            'complete controller protocol.']},
 'Reloop Mixon 8 Pro': {'source': {'url': 'https://community.algoriddim.com/uploads/short-url/2kUpIX9bPTVPo7qTr9egISBVAbm.djayMidiMa',
                                   'sha256': '47c43bcc1c78ae87d450bb3bba8caa3264ab51f2361b09204432b78a9081cd77'},
                        'discussion': 'https://community.algoriddim.com/t/reloop-mixon-8-ultimate-stems-mapping/20579',
                        'format': 'Apple property list',
                        'mappingVersion': 2,
                        'inputRows': 895,
                        'outputRows': 24,
                        'declaredCustomClass': 'ReloopMixon8',
                        'automaticSupportAdded': False,
                        'gaps': ['The custom ReloopMixon8 app class is absent. Shared XML does not establish '
                                 'jog/pitch dispatch or cold-start lifecycle.',
                                 'This custom version2 map predates firmware49.36. Its author reports '
                                 'incompatibility with that update. Current firmware and dispatch need '
                                 'independent qualification.']}}

SOURCE_AUDITS["Reloop Mixtour Pro"] = MIXTOUR_PRO_AUDIT

MODELS = [
    ('Hercules DJControl Inpulse T7', 'https://community.algoriddim.com/t/hercules-inpulse-t7-support/20172/186'),
    ('Reloop Mixon 8 Pro', 'https://community.algoriddim.com/t/reloop-mixon-8-ultimate-stems-mapping/20579'),

    ("Reloop Jockey 3 ME", "https://manual.mixxx.org/2.5/en/hardware/controllers/reloop_jockey_3_master_edition"),
    ("Reloop Digital Jockey 2 Master Edition", "https://www.reloop.com/reloop-digital-jockey-2-master-edition"),
    ("Reloop Digital Jockey 2 Master Edition", "https://manual.mixxx.org/2.5/en/hardware/controllers/reloop_digital_jockey_2_master_edition"),
    ("DJ-Tech VTT-101", "https://asset.conrad.com/media10/add/160267/c1/-/gl/000092385ML01/mode-demploi-092385-mini-controleur-usb-dj-tech-vtt101.pdf"),
    ("American Audio VMS2", "https://cdn-docs.av-iq.com/other/VMS2_User%20Manual.pdf"),
    ("American Audio VMS4", "https://manual.mixxx.org/2.5/en/hardware/controllers/american_audio_vms4"),
    ("American Audio VMS4.1", "https://manual.mixxx.org/2.5/en/hardware/controllers/american_audio_vms4"),
    ("American Audio VMS4.1 Traktor", "https://www.adj.eu/vms4-1-traktor"),
    ("American Audio VMS5", "https://www.adj.com/products/vms5"),
    ("Numark Stealth Control", "https://www.numark.com/product/stealthcontrol"),
    ("Numark Stealth Control", "https://www.numark.com/images/product_downloads/numark_stealth_control_xml_file_for_cue_5_and_virtual_vinyl_5.zip"),
    ("Numark Stealth Control", "https://www.numark.com/images/product_downloads/stealth_control___quickstart_manual___v1.4.pdf"),
    ("Behringer BCD2000", "https://github.com/anyc/snd-bcd2000"),
    ("Denon MC3000", "https://cdn.inmusicbrands.com/denondj/legacy/mc3000/MC3000EM_ENG_IM_v00.pdf"),
    ("AlphaTheta DJM-A7", "https://alphatheta.com/en/product/dj-mixer/djm-a7/black/"),
    ("AlphaTheta XDJ-AN", "https://alphatheta.com/en/product/all-in-one-dj-system/xdj-an/black/"),
    ("AlphaTheta RMX-IGNITE", "https://alphatheta.com/en/product/effector/rmx-ignite/black/"),
    ("Rane PERFORMER", "https://www.rane.com/downloads/?product=Rane+Performer"),
    ("Rane FOUR", "https://support.rane.com/en/support/solutions/articles/69000828752-rane-four-frequently-asked-questions"),
    ("Rane FOUR", "https://github.com/ElectroDanceWorld-Radio/rane-four-mixxx-map/tree/f527e144d6246498fe3e45193fecbb20d8279ddd"),
    ("Reloop Buddy", "https://www.reloop.com/reloop-buddy"),
    ("Reloop Mixtour Pro", "https://www.reloop.com/reloop-mixtour-pro"),
    ("Reloop Mixtour", RELOOP_COMPARISON),
    ("Reloop Beatpad 2", RELOOP_COMPARISON),
    *[("Denon DJ " + name, DENON_ENGINE) for name in [
        "PRIME 2", "PRIME GO", "PRIME GO+", "SC6000 PRIME", "SC6000M PRIME", "SC5000 PRIME", "SC5000M PRIME",
    ]],
]
