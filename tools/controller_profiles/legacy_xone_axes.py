"""Separate manufacturer Map2 axes with explicit native four-target layouts."""
from curated import add, profile

BASE = 'https://www.allen-heath.com/content/uploads/2023/07/'
XONE_AXIS_REFERENCES = {
    'Allen & Heath XONE 1D': {'url': BASE+'XONE1D_UG_AP7080_3.pdf', 'sha256': '41b4d3742bc9fdf4bedbee353bc38a93e0c1eea6f7dc5928109f0d38c5df3efb', 'cachePath': 'TestBuilds/r425/upstream/xone1d.pdf', 'reviewedPages': [6, 8, 13, 14],
        'review': 'Own guide gives Map2 top encoders CC32..35, two pot rows9/11/13/15 and8/10/12/14, faders19/18/17/16, encoder36 and wheel37. Default MIDI channel16. Encoders/wheel are twos-complement; pot/fader positions are0..127. Native deliberately assigns four columns to A/B/C/D gain/high/low/level, encoder36 to A loop size and wheel37 to library browse. These are explicit native assignments, not manufacturer DJ-software actions. The documented generic USB Audio Device/Xone MIDI Device names do not establish an exclusive model identity; manual selection is required. Button note-number convention, Map1, all lights/state/lifecycle/USB/OS and physical acceptance remain open. No audio interface or touch-sensitive platter is invented.'},
    'Allen & Heath XONE 2D': {'url': BASE+'XONE2D_UG_AP6908_2.pdf', 'sha256': '83b9a8c9ed67b17bbdd992b6598c9c96bb6ea9d25276bf5a85dedb3ec7ca9c85', 'cachePath': 'TestBuilds/r425/upstream/xone2d-primary.pdf', 'reviewedPages': [9, 12, 27, 28],
        'review': 'Own normal Map2 chart uses top encoders40..43, pots21/23/25/27 and20/22/24/26, faders31/30/29/28, encoder44, wheel45 and crossfader5. It does not use the1D normal address family. Default MIDI channel16. Native four-column gain/high/low/level, A loop size, library and crossfader are explicit assignments. Hardware Shift uses the left-family addresses32..37/8..19 on the same channel; those alternate controls remain inactive. The Mac guide requires a driver. Button note numbers, full map/Shift/clock/monitor/digital audio, USB host/driver and lifecycle remain open. No driver or stored setting runs; manual selection and separate app audio are required.'},
    'Allen & Heath XONE 4D': {'url': BASE+'Xone4D_User_Guide_AP7265_3.pdf', 'sha256': 'b244df319946354feb1f4d007ca7a8d35d28f816f9e39b22288e8cd40e979660', 'cachePath': 'TestBuilds/r425/upstream/xone4d.pdf', 'reviewedPages': [11, 12, 38, 39],
        'review': 'Own two-pod Map2 chart independently supplies both CC families, wheels37/45 and MIDI crossfader5. Default MIDI channel16; hardware Shift uses channel15, unlike2D address shifting. Both pods deliberately address the same four native A/B/C/D gain/high/low/level targets with independent pickup. Wheels browse the library. The hardware analogue channel-strip controls are not claimed as MIDI controls. Native does not map channel15, ambiguous musical-note button labels, top fifth encoders, joystick/footswitch, clock/LFO or motor/display behaviour. Manual selection and separate app audio prevent an automatic hardware/software mixing claim. Complete modes/feedback/state/lifecycle/audio/USB/OS and physical acceptance remain open.'}}


def xone_axis_profiles():
    """Return only confirmed continuous controls; note conventions remain unresolved."""
    result = []
    for model in ['1D', '2D', '4D']:
        name = f'Allen & Heath XONE {model}'; ref = XONE_AXIS_REFERENCES[name]
        p = profile(name, ref['url'])
        p.update(definition='manufacturer:xone-axes-'+model.lower(), autoSelect=False,
            aliases=[name, f'Allen & Heath Xone:{model}', f'Xone:{model}', f'Xone {model}'],
            excludedAliases=['Xone MIDI Device', 'USB Audio Device']+[f'Xone:{other}' for other in ['1D', '2D', '4D', 'K1', 'K2', 'K3'] if other != model],
            hardwareMode='Select manually in Map2 on MIDI channel16. Each four-column pod addresses native A/B/C/D gain/high/low/level. Enable C/D separately. Configure app audio separately. Alternate Shift controls remain inactive.',
            scope='Manual confirmed Map2 continuous-control subset. Native four-target mixer axes and library;1D/2D also provide A loop size. Buttons and lamps remain inactive until their numeric note contract is qualified.',
            gaps=[ref['review'], 'Full theoretical support and physical/iPad/A10X acceptance remain open. No firmware, driver, channel/map/light-pipe setting, vendor program, MIDI clock or audio route is written.'])
        pods = [0] if model == '1D' else [1] if model == '2D' else [0, 1]
        for pod in pods:
            for i, deck in enumerate('abcd'):
                for action, number, encoding in [('gain', 32+8*pod+i, 'twosComplement'), ('high', 9+12*pod+2*i, 'absolute'), ('low', 8+12*pod+2*i, 'absolute'), ('level', 19+12*pod-i, 'absolute')]:
                    add(p, action, 15, number, 'control', encoding, deck)
            add(p, 'browse', 15, 37+8*pod, 'control', 'twosComplement')
            if model != '4D': add(p, 'loopSize', 15, 36+8*pod, 'control', 'twosComplement', 'a')
        if model != '1D': add(p, 'crossfader', 15, 5, 'control')
        result.append(p)
    return result
