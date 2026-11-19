"""Dedicated own-model clear opcodes with independently qualified activation pairs."""
from copy import deepcopy

PAIR_REFERENCES = {'Pioneer DDJ-SB3': {'path': 'res/controllers/Pioneer-DDJ-SB3.midi.xml',
                     'url': 'https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Pioneer-DDJ-SB3.midi.xml',
                     'git_blob': '589a539c2594726a8a884373f8c8ed9ae10cdfd2',
                     'sha256': '67efe99432c2f3818df865b93f097591145941f68b951d8a950576b499f944c5',
                     'bytes': 174029},
 'Reloop Terminal Mix 2/4': {'path': 'res/controllers/Reloop Terminal Mix 2-4.midi.xml',
                             'url': 'https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Reloop%20Terminal%20Mix%202-4.midi.xml',
                             'git_blob': '3f49eddf271b79477c3e082b33a6f3f26966508e',
                             'sha256': '75ec007d96620b4665d7435c8c7a86bae8a4fae6146542a5c37ae3ac32b01c40',
                             'bytes': 92007},
 'Hercules DJControl Jogvision': {'path': 'res/controllers/Hercules_DJControl_Jogvision.midi.xml',
                                  'url': 'https://raw.githubusercontent.com/mixxxdj/mixxx/20f2c218ae1b762ac39fd76ff408c8428056f4f7/res/controllers/Hercules_DJControl_Jogvision.midi.xml',
                                  'git_blob': '9ead402712ca9ba863bad5c37f03298cb2a6eb74',
                                  'sha256': '8e0499c69c0b91494b8af06da6c722d80c39efc978d7f56c8536c47fc226c7fe',
                                  'bytes': 61520}}

PAIRED_CLEAR_INPUTS = {'Pioneer DDJ-SB3': [(7, 8, 7, 0, 1, 'a'),
                     (8, 8, 8, 0, 1, 'b'),
                     (9, 8, 9, 0, 1, 'c'),
                     (10, 8, 10, 0, 1, 'd'),
                     (7, 9, 7, 1, 2, 'a'),
                     (8, 9, 8, 1, 2, 'b'),
                     (9, 9, 9, 1, 2, 'c'),
                     (10, 9, 10, 1, 2, 'd'),
                     (7, 10, 7, 2, 3, 'a'),
                     (8, 10, 8, 2, 3, 'b'),
                     (9, 10, 9, 2, 3, 'c'),
                     (10, 10, 10, 2, 3, 'd'),
                     (7, 11, 7, 3, 4, 'a'),
                     (8, 11, 8, 3, 4, 'b'),
                     (9, 11, 9, 3, 4, 'c'),
                     (10, 11, 10, 3, 4, 'd'),
                     (7, 12, 7, 4, 5, 'a'),
                     (8, 12, 8, 4, 5, 'b'),
                     (9, 12, 9, 4, 5, 'c'),
                     (10, 12, 10, 4, 5, 'd'),
                     (7, 13, 7, 5, 6, 'a'),
                     (8, 13, 8, 5, 6, 'b'),
                     (9, 13, 9, 5, 6, 'c'),
                     (10, 13, 10, 5, 6, 'd'),
                     (7, 14, 7, 6, 7, 'a'),
                     (8, 14, 8, 6, 7, 'b'),
                     (9, 14, 9, 6, 7, 'c'),
                     (10, 14, 10, 6, 7, 'd'),
                     (7, 15, 7, 7, 8, 'a'),
                     (8, 15, 8, 7, 8, 'b'),
                     (9, 15, 9, 7, 8, 'c'),
                     (10, 15, 10, 7, 8, 'd')],
 'Reloop Terminal Mix 2/4': [(0, 86, 0, 16, 1, 'a'),
                             (0, 87, 0, 17, 2, 'a'),
                             (0, 88, 0, 18, 3, 'a'),
                             (0, 89, 0, 19, 4, 'a'),
                             (0, 94, 0, 24, 5, 'a'),
                             (0, 95, 0, 25, 6, 'a'),
                             (0, 96, 0, 26, 7, 'a'),
                             (0, 97, 0, 27, 8, 'a'),
                             (1, 86, 1, 16, 1, 'b'),
                             (1, 87, 1, 17, 2, 'b'),
                             (1, 88, 1, 18, 3, 'b'),
                             (1, 89, 1, 19, 4, 'b'),
                             (1, 94, 1, 24, 5, 'b'),
                             (1, 95, 1, 25, 6, 'b'),
                             (1, 96, 1, 26, 7, 'b'),
                             (1, 97, 1, 27, 8, 'b'),
                             (2, 86, 2, 16, 1, 'c'),
                             (2, 87, 2, 17, 2, 'c'),
                             (2, 88, 2, 18, 3, 'c'),
                             (2, 89, 2, 19, 4, 'c'),
                             (2, 94, 2, 24, 5, 'c'),
                             (2, 95, 2, 25, 6, 'c'),
                             (2, 96, 2, 26, 7, 'c'),
                             (2, 97, 2, 27, 8, 'c'),
                             (3, 86, 3, 16, 1, 'd'),
                             (3, 87, 3, 17, 2, 'd'),
                             (3, 88, 3, 18, 3, 'd'),
                             (3, 89, 3, 19, 4, 'd'),
                             (3, 94, 3, 24, 5, 'd'),
                             (3, 95, 3, 25, 6, 'd'),
                             (3, 96, 3, 26, 7, 'd'),
                             (3, 97, 3, 27, 8, 'd')],
 'Hercules DJControl Jogvision': [(0, 24, 0, 16, 1, 'a'),
                                  (0, 25, 0, 17, 2, 'a'),
                                  (0, 26, 0, 18, 3, 'a'),
                                  (0, 27, 0, 19, 4, 'a'),
                                  (0, 28, 0, 20, 5, 'a'),
                                  (0, 29, 0, 21, 6, 'a'),
                                  (0, 30, 0, 22, 7, 'a'),
                                  (0, 31, 0, 23, 8, 'a'),
                                  (1, 24, 1, 16, 1, 'b'),
                                  (1, 25, 1, 17, 2, 'b'),
                                  (1, 26, 1, 18, 3, 'b'),
                                  (1, 27, 1, 19, 4, 'b'),
                                  (1, 28, 1, 20, 5, 'b'),
                                  (1, 29, 1, 21, 6, 'b'),
                                  (1, 30, 1, 22, 7, 'b'),
                                  (1, 31, 1, 23, 8, 'b')]}


def apply_reviewed_hotcue_pairs(profiles):
    """Add explicit clear roles and both negative aliases after exact activation proof."""
    by={p['id']:p for p in profiles}
    for name,pairs in PAIRED_CLEAR_INPUTS.items():
        p=by[name]
        if p.get('inputProtocol') is not None or p.get('inputModes') is not None:
            raise ValueError('Hot Cue pair needs a new protocol or mode review: '+name)
        for cc,cn,ac,an,slot,deck in pairs:
            suffix='A' if deck in 'ac' else 'B';action=f'hotcue{slot}{suffix}'
            same=lambda r,ch,n:r['kind']=='note' and r['channel']==ch and r['number']==n
            activations=[r for r in p['inputs'] if same(r,ac,an) and r['action']==action and r.get('targetDeck')==deck and not r.get('releaseOnly')]
            if len(activations)!=1 or any(same(r,cc,cn) and not r.get('releaseOnly') for r in p['inputs']):
                raise ValueError('Hot Cue pair lost activation proof or gained a positive collision: '+name)
            cue=activations[0]
            if cue['encoding']!='absolute' or cue['inverted'] or set(cue)-{'action','kind','channel','number','encoding','inverted','targetDeck','shifted','shiftChannel'}:
                raise ValueError('Hot Cue pair needs a new input-field review: '+name)
            clear={k:deepcopy(v) for k,v in cue.items() if k not in {'shifted','shiftChannel'}}
            clear.update(action=f'clearHotcue{slot}{suffix}',channel=cc,number=cn)
            cue_release={**clear,'action':action,'releaseOnly':True}
            clear_release={**clear,'channel':ac,'number':an,'releaseOnly':True}
            p['inputs'].extend([clear,cue_release,clear_release])
        ref=PAIR_REFERENCES[name]
        p['scope']+=' Dedicated Hot Cue clear opcodes and paired negative aliases are supported; full modes and physical acceptance remain open.'
        p.setdefault('gaps',[]).append('R479 adds dedicated normal Note-On Hot Cue clears from '+ref['url']+' (SHA-256 '+ref['sha256']+'). Every paired activation wire matches an existing native own-model Hot Cue. Clear roles have no positive collision. Both negative aliases rearm their own action without an inferred app Shift requirement. Previous inputs, output/setup/audio and aliases remain unchanged. This does not qualify other modes, display/lifecycle, host routes or physical acceptance.')
    return profiles
