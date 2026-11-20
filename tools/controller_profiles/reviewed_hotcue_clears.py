"""Explicit clear opcodes already represented by qualified native negative guards."""
from copy import deepcopy

CLEAR_REFERENCES = {'Hercules DJControl Compact': {'path': 'res/controllers/Hercules DJControl Compact.midi.xml', 'url': 'https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Hercules%20DJControl%20Compact.midi.xml', 'git_blob': '75cb4f7b508190fd1bbeb8bee5435b2b57d37ae4', 'sha256': 'a598e43feda6b1d48efda26e33a41fa258e88bc15b4100ec6fae399dac1374dd', 'bytes': 46108}, 'Hercules DJControl Inpulse 200': {'path': 'res/controllers/Hercules_DJControl_Inpulse_200.midi.xml', 'url': 'https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Hercules_DJControl_Inpulse_200.midi.xml', 'git_blob': 'b9d10873f59606296be6c27f316734680140a8ca', 'sha256': 'c0927a1bbc75c1c1727034d2bd0f0f01d018ee264c1c63c203d3f9d8e06b6587', 'bytes': 65627}, 'Hercules DJControl Inpulse 300': {'path': 'res/controllers/Hercules_DJControl_Inpulse_300.midi.xml', 'url': 'https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Hercules_DJControl_Inpulse_300.midi.xml', 'git_blob': 'c1c0a58cdd6299909a593b5bfba005e28de6c09f', 'sha256': '43c8c84c8832af0c26d038851be8280ffb8b9a9c7c0e8b1d9811b520333114c4', 'bytes': 109415}, 'Hercules DJControl MIX': {'path': 'res/controllers/Hercules DJControl MIX.midi.xml', 'url': 'https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Hercules%20DJControl%20MIX.midi.xml', 'git_blob': 'f4a0e34d3c7751bfd4c15e5305976aaa5faedc7a', 'sha256': '7d64670a5235dcde14373a700f1aec70124f1f3880d1efa65ee2459faa32ee18', 'bytes': 54397}, 'Hercules DJControl Starlight': {'path': 'res/controllers/Hercules DJControl Starlight.midi.xml', 'url': 'https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Hercules%20DJControl%20Starlight.midi.xml', 'git_blob': '4d6a3a244526c4eea4e3079ad6a92a0bd41a330c', 'sha256': 'e47b766a85f4fa234c41c4bf91ae456ca35dacc507184f69d3b2d458bf35d6c1', 'bytes': 53608}, 'Korg KAOSS DJ': {'path': 'res/controllers/Korg-KAOSS-DJ.midi.xml', 'url': 'https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Korg-KAOSS-DJ.midi.xml', 'git_blob': 'ca502503245c940dc03c070edf941dc2167f78e9', 'sha256': '85d2555f1ff54adee404f0443df3f2af4363090f1cde762371d11413c8aa6285', 'bytes': 34494}, 'MixVibes U-Mix Control 2': {'path': 'res/controllers/MixVibes U-Mix Control 2.midi.xml', 'url': 'https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/MixVibes%20U-Mix%20Control%202.midi.xml', 'git_blob': '291507b777356ce42ee6478f5fb283a3c6f1fa40', 'sha256': '89a62e4ba79ded920dca67e16b2632b1e9020bdd7a79d78cb5f2feecdefa7b0a', 'bytes': 26114}, 'MixVibes U-Mix Control Pro 2': {'path': 'res/controllers/MixVibes U-Mix Control Pro 2.midi.xml', 'url': 'https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/MixVibes%20U-Mix%20Control%20Pro%202.midi.xml', 'git_blob': 'c9b62423c5d2785c5f4c5cbde85360ba21b2f5ff', 'sha256': 'd460da29d06de95265297711fadae4d55ea77ca08821a778ba055ce0452e7840', 'bytes': 31039}, 'Novation Dicer': {'path': 'res/controllers/Novation Dicer.midi.xml', 'url': 'https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Novation%20Dicer.midi.xml', 'git_blob': 'd080b82737dfc69535eb4dc14d90e27f88eb141d', 'sha256': '1ebe1d435a086e02e819b57f2ca6e61993269ed9971c5748f01726189baf5f46', 'bytes': 33611}, 'Reloop Beatmix 2/4 MK2': {'path': 'res/controllers/Reloop-Beatmix-2-4-MK2.midi.xml', 'url': 'https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Reloop-Beatmix-2-4-MK2.midi.xml', 'git_blob': '488960e2c7a48be27e68fe9607a0759388b69766', 'sha256': '9ad44392c28b9221126520cf1afb1fa7a379b2974a20cafcdcef5ae7a4bd6832', 'bytes': 122238}, 'Stanton DJC.4': {'path': 'res/controllers/Stanton-DJC-4.midi.xml', 'url': 'https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Stanton-DJC-4.midi.xml', 'git_blob': 'fa56a0511284bd2af5e6e97175028e0d8bcb203d', 'sha256': 'e7b4cca84354be02d3c627054e187d7e0b66cbfb51bbae6dced9b2b339c97f26', 'bytes': 92406}, 'Vestax VCI-100MKII': {'path': 'res/controllers/Vestax VCI-100MKII.midi.xml', 'url': 'https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Vestax%20VCI-100MKII.midi.xml', 'git_blob': '499c54e97061ef5d230e02d7f2ef3dd69c954526', 'sha256': 'ca8cd77428b7cf6133158b048a002e77f5db43a3aa27ab7e8195c71df35b9677', 'bytes': 54523}}

CLEAR_INPUTS = {
    'Hercules DJControl Compact': [(0, 5, 1, 'a'), (0, 6, 2, 'a'), (0, 7, 3, 'a'), (0, 8, 4, 'a'), (0, 53, 1, 'b'), (0, 54, 2, 'b'), (0, 55, 3, 'b'), (0, 56, 4, 'b')],
    'Hercules DJControl Inpulse 200': [(6, 8, 1, 'a'), (6, 9, 2, 'a'), (6, 10, 3, 'a'), (6, 11, 4, 'a'), (7, 8, 1, 'b'), (7, 9, 2, 'b'), (7, 10, 3, 'b'), (7, 11, 4, 'b')],
    'Hercules DJControl Inpulse 300': [(6, 8, 1, 'a'), (6, 9, 2, 'a'), (6, 10, 3, 'a'), (6, 11, 4, 'a'), (6, 12, 5, 'a'), (6, 13, 6, 'a'), (6, 14, 7, 'a'), (6, 15, 8, 'a'), (7, 8, 1, 'b'), (7, 9, 2, 'b'), (7, 10, 3, 'b'), (7, 11, 4, 'b'), (7, 12, 5, 'b'), (7, 13, 6, 'b'), (7, 14, 7, 'b'), (7, 15, 8, 'b')],
    'Hercules DJControl MIX': [(6, 8, 1, 'a'), (6, 9, 2, 'a'), (6, 10, 3, 'a'), (6, 11, 4, 'a'), (7, 8, 1, 'b'), (7, 9, 2, 'b'), (7, 10, 3, 'b'), (7, 11, 4, 'b')],
    'Hercules DJControl Starlight': [(6, 8, 1, 'a'), (6, 9, 2, 'a'), (6, 10, 3, 'a'), (6, 11, 4, 'a'), (7, 8, 1, 'b'), (7, 9, 2, 'b'), (7, 10, 3, 'b'), (7, 11, 4, 'b')],
    'Korg KAOSS DJ': [(7, 43, 1, 'a'), (8, 43, 1, 'b'), (7, 44, 2, 'a'), (8, 44, 2, 'b'), (7, 45, 3, 'a'), (8, 45, 3, 'b')],
    'MixVibes U-Mix Control 2': [(4, 127, 6, 'b'), (3, 127, 6, 'a'), (4, 10, 1, 'b'), (4, 11, 2, 'b'), (4, 12, 3, 'b'), (3, 10, 1, 'a'), (3, 11, 2, 'a'), (3, 12, 3, 'a'), (4, 24, 4, 'b'), (4, 25, 5, 'b'), (3, 24, 4, 'a'), (3, 25, 5, 'a')],
    'MixVibes U-Mix Control Pro 2': [(3, 9, 1, 'a'), (4, 9, 1, 'b'), (3, 10, 2, 'a'), (4, 10, 2, 'b'), (3, 11, 3, 'a'), (4, 11, 3, 'b'), (3, 12, 4, 'a'), (4, 12, 4, 'b')],
    'Novation Dicer': [(10, 65, 1, 'a'), (10, 66, 2, 'a'), (10, 67, 3, 'a'), (10, 68, 4, 'a'), (10, 69, 5, 'a'), (13, 65, 1, 'b'), (13, 66, 2, 'b'), (13, 67, 3, 'b'), (13, 68, 4, 'b'), (13, 69, 5, 'b')],
    'Reloop Beatmix 2/4 MK2': [(1, 8, 1, 'a'), (1, 9, 2, 'a'), (1, 10, 3, 'a'), (1, 11, 4, 'a'), (2, 8, 1, 'b'), (2, 9, 2, 'b'), (2, 10, 3, 'b'), (2, 11, 4, 'b'), (3, 8, 1, 'c'), (3, 9, 2, 'c'), (3, 10, 3, 'c'), (3, 11, 4, 'c'), (4, 8, 1, 'd'), (4, 9, 2, 'd'), (4, 10, 3, 'd'), (4, 11, 4, 'd')],
    'Stanton DJC.4': [(0, 58, 1, 'a'), (1, 58, 1, 'b'), (2, 58, 1, 'c'), (3, 58, 1, 'd'), (0, 59, 2, 'a'), (1, 59, 2, 'b'), (2, 59, 2, 'c'), (3, 59, 2, 'd'), (0, 60, 3, 'a'), (1, 60, 3, 'b'), (2, 60, 3, 'c'), (3, 60, 3, 'd'), (0, 61, 4, 'a'), (1, 61, 4, 'b'), (2, 61, 4, 'c'), (3, 61, 4, 'd')],
    'Vestax VCI-100MKII': [(0, 74, 1, 'a'), (1, 74, 1, 'b'), (2, 74, 1, 'c'), (3, 74, 1, 'd'), (0, 75, 2, 'a'), (1, 75, 2, 'b'), (2, 75, 2, 'c'), (3, 75, 2, 'd')],
}

CLEAR_REFERENCES['Korg KAOSS DJ (Audioless)'] = CLEAR_REFERENCES['Korg KAOSS DJ']
CLEAR_INPUTS['Korg KAOSS DJ (Audioless)'] = CLEAR_INPUTS['Korg KAOSS DJ']


def apply_reviewed_hotcue_clears(profiles):
    """Add only source-declared clear wires with one existing matching negative guard."""
    by={p['id']:p for p in profiles}
    for name,entries in CLEAR_INPUTS.items():
        p=by[name]
        if p.get('inputProtocol') is not None or p.get('inputModes') is not None:
            raise ValueError('Clear opcodes require a new protocol or mode review: '+name)
        inverses=[]
        for channel,number,slot,deck in entries:
            suffix='A' if deck in 'ac' else 'B';activate=f'hotcue{slot}{suffix}'
            same_wire=lambda r:r['kind']=='note' and r['channel']==channel and r['number']==number
            guards=[r for r in p['inputs'] if same_wire(r) and r.get('releaseOnly') and r['action']==activate and r.get('targetDeck')==deck]
            if len(guards)!=1 or any(same_wire(r) and not r.get('releaseOnly') for r in p['inputs']):
                raise ValueError('Clear opcode lost its unique negative guard or gained a positive collision: '+name)
            guard=guards[0]
            if guard['encoding']!='absolute' or guard['inverted'] or set(guard)-{'action','kind','channel','number','encoding','inverted','targetDeck','releaseOnly','shifted','shiftChannel'}:
                raise ValueError('Clear opcode needs a new input-field review: '+name)
            binding={k:deepcopy(v) for k,v in guard.items() if k not in {'releaseOnly','shifted','shiftChannel'}}
            binding['action']=f'clearHotcue{slot}{suffix}'
            activations=[r for r in p['inputs'] if r['action']==activate and r.get('targetDeck')==deck and r['kind']=='note' and not r.get('releaseOnly') and r.get('shifted')!=True]
            if len(activations)!=1 or set(activations[0])-{'action','kind','channel','number','encoding','inverted','targetDeck','shifted','shiftChannel'}:
                raise ValueError('Clear release needs a new activation-wire review: '+name)
            activation=activations[0]
            if activation['encoding']!='absolute' or activation['inverted']:
                raise ValueError('Clear release needs a new activation-encoding review: '+name)
            p['inputs'].append(binding)
            inverses.append({**binding,'channel':activation['channel'],'number':activation['number'],'releaseOnly':True})
        p['inputs'].extend(inverses)
        p.setdefault('gaps',[]).append('R482 adds the inverse negative alias for each dedicated clear. A release on the qualified normal Hot Cue wire rearms its clear action after hardware Shift changes. The activation wire is independently checked against the same own-model pinned XML. All previous inputs and positive roles remain unchanged.')
        ref=CLEAR_REFERENCES[name]
        p['scope']+=' Explicit dedicated Hot Cue clear opcodes are supported; full modes and physical acceptance remain open.'
        p.setdefault('gaps',[]).append('R478 adds only direct normal Note-On Hot Cue clear roles from '+ref['url']+' (SHA-256 '+ref['sha256']+'). Every wire already had a matching native negative guard and has no positive collision. Dedicated hardware clear opcodes do not require an inferred app Shift state. Existing negative guards, transport, output/setup/audio and all other controls remain unchanged. This does not qualify other pad modes, display/lifecycle, host routes or physical acceptance.')
    return profiles
