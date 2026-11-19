"""Separate RMP-3 and RMP-2.5 Alpha manufacturer preset button contracts."""
from curated import add, profile

RMP_ROWS = [
    {'name': 'Reloop RMP-3', 'definition': 'reviewed:rmp3-preset-buttons',
     'url': 'https://www.reloop.com/media/catalog/product/pdf/2/2/2/222609_Reloop_IM.pdf',
     'path': 'TestBuilds/r447/upstream/rmp3-manual.pdf', 'sha': '09e1e9c755e2543c27e46b4510fa8d47ccdf3b03acb5fcff360bc639a8d34c33',
     'page': 44, 'product': 'https://www.reloop.com/reloop-rmp-3',
     'names': ['RMP-3', 'RMP-3B', 'RMP-3C', 'RMP-3D', 'RMP-3F', 'RMP-3G', 'RMP-3H'],
     'buttons': [('play',1,64),('cuePreview',7,70),('loopIn',22,85),('loopOut',46,109),('reloop',34,97),('keylock',20,83),('pitchBendDown',8,71),('pitchBendUp',2,65)],
     'hotcues': [(28,91),(10,73),(16,79),(15,78)], 'folders': [13,19]},
    {'name': 'Reloop RMP-2.5a', 'definition': 'reviewed:rmp25-preset-buttons',
     'url': 'https://www.reloop.com/media/catalog/product/pdf/2/2/4/224803_Reloop_IM.pdf',
     'path': 'TestBuilds/r447/upstream/rmp25-manual.pdf', 'sha': '450afae345171d763c36854401a398b842eb87bc594a39d2e6a66c24a346ddb6',
     'page': 37, 'product': 'https://www.reloop.com/reloop-rmp-2-5-alpha',
     'names': ['RMP-25', 'RMP-25B', 'RMP-25C', 'RMP-25D', 'RMP-25E', 'RMP-25F', 'RMP-25G', 'RMP-25H'],
     'buttons': [('play',6,69),('cuePreview',7,70),('loopIn',12,75),('loopOut',13,76),('reloop',11,74),('keylock',19,82),('pitchBendDown',21,84),('pitchBendUp',20,83)],
     'hotcues': [(27,90),(25,88),(26,89),(15,78)], 'folders': [4,5]},
]
RMP_REFERENCES = {}
for row in RMP_ROWS:
    RMP_REFERENCES[row['name']] = {
        'url': row['url'], 'sha256': row['sha'],
        'files': [{'cachePath': row['path'], 'sha256': row['sha']}],
        'relatedSources': [{'url': row['product']}],
        'review': f"Own manufacturer manual p{row['page']} MIDI map visually reviewed, with separate normal/shifted numbers. Native38-input automatic single-player preset uses Play, held Cue, Loop In/Out/Reloop, Keylock, held bends, eight Hot Cues and navigation. Explicit shifted release-only aliases retire held Cue/bends and rearm normal transport; paired Hot Cue release aliases rearm either physical layer. Source Hot Cue mapping confirms normal slots1..4 and shifted5..8. MIDI channels1..16 stay on the app deck assigned to that physical source, not a hardware channel-selected virtual deck. Hardware multi-deck paging is not implemented. Named USB identities come from this model's own Name menu. Use MIDI USB mode and Edit Off preset commands. Track navigation accepts only the documented NOTE format (normal50/51, shifted113/114); configurable relative/absolute CC variants remain inactive. Folder buttons step native groups. No global Shift latch is created; the hardware already supplies explicit alternate note numbers. Original RMP-3 alone has a Shift42hex/shifted TAP42hex collision and a concatenated Loop Out shifted field6D2E. That field supplies only a defensive6D release alias, never a positive shifted Loop Out. Jog/contact formats and calibration, pitch polarity/types, alternate encodings/presets, FX, full feedback/last-channel ownership, lifecycle/recovery, USB/OS/power/audio and physical/iPad/A10X acceptance remain open. No output, setup, source-mode change, query, preset, driver, firmware or audio-route write runs. RMP-3 Alpha/RMP-4 and the other RMP chart remain separate.",
    }


def rmp_player_profiles():
    """Return independently pinned preset button cores with source-owned app assignment."""
    results = []
    for row in RMP_ROWS:
        p = profile(row['name'], row['url'])
        p.update(definition=row['definition'], role='player',
            aliases=list(dict.fromkeys([row['name'], row['name'].split(' ',1)[1]] + row['names'] + ['Reloop ' + n for n in row['names']] + (['RMP-2.5 Alpha', 'Reloop RMP-2.5 Alpha'] if row['page'] == 37 else []))),
            excludedAliases=['RMP-3 Alpha','RMP-4'] + (['RMP-2.5 Alpha','RMP-25'] if row['page'] == 44 else ['RMP-3']),
            hardwareMode='Select MIDI USB mode and Edit Off preset commands on this player. Native assigns one app deck per connected player. Hardware channel changes keep that assigned deck. Track-wheel navigation works only in NOTE format. Jog, tempo, feedback, alternate presets and hardware multi-deck paging remain open.',
            scope='Automatic38-input-row preset player core: Play, held Cue/bends, Keylock, manual loops, eight Hot Cues, note-format track/group navigation and defensive releases. One assigned app deck per source across MIDI channels. No output/audio setup. Full modes and physical acceptance remain open.',
            gaps=[RMP_REFERENCES[row['name']]['review']])
        for action, normal, shifted in row['buttons']:
            add(p, action, 0, normal, deck='a')
            add(p, action, 0, shifted, deck='a'); p['inputs'][-1]['releaseOnly'] = True
        for slot, (normal, shifted) in enumerate(row['hotcues']):
            for number, release, target in [(normal, shifted, slot + 1), (shifted, normal, slot + 5)]:
                add(p, f'hotcue{target}', 0, number, deck='a')
                add(p, f'hotcue{target}', 0, release, deck='a'); p['inputs'][-1]['releaseOnly'] = True
        for action, n in [('browseNextGroup',row['folders'][0]),('browsePreviousGroup',row['folders'][1]),
                          ('browseNext',50),('browsePrevious',51),('browseNextGroup',113),('browsePreviousGroup',114)]:
            add(p, action, 0, n); p['inputs'][-1]['pulse'] = True
        for r in p['inputs']: r['anyChannel'] = True
        results.append(p)
    return results
