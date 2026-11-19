"""First-page clear pairs independently qualified by each listed model factory table."""
from copy import deepcopy


def add_pioneer_pad_clears(profile):
    """Append only the reviewed model layout after every activation and collision check passes."""
    name = profile['id']
    layouts = {
        'DDJ-FLX10': [(7, 8, 0, 'a'), (9, 10, 0, 'b'), (11, 12, 0, 'c'), (13, 14, 0, 'd')],
        'DDJ-1000': [(7, 8, 0, 'a'), (9, 10, 0, 'b'), (11, 12, 0, 'c'), (13, 14, 0, 'd')],
        'Pioneer DDJ-200': [(7, 8, 0, 'a'), (9, 10, 0, 'b')],
        'Pioneer DDJ-RB': [(7, 7, 8, 'a'), (8, 8, 8, 'b')],
    }
    if name not in layouts or profile.get('inputProtocol') is not None or profile.get('inputModes') is not None:
        raise ValueError('Pioneer clear layout requires its own model and mode review: ' + name)
    pending = []
    for channel, clear_channel, clear_offset, deck in layouts[name]:
        for slot in range(8):
            action = f"hotcue{slot + 1}{'A' if deck in 'ac' else 'B'}"
            cues = [r for r in profile['inputs'] if r['action'] == action and r.get('targetDeck') == deck and r['kind'] == 'note' and r['channel'] == channel and r['number'] == slot and not r.get('releaseOnly')]
            if len(cues) != 1 or any(r['kind'] == 'note' and r['channel'] == clear_channel and r['number'] == slot + clear_offset and not r.get('releaseOnly') for r in profile['inputs']):
                raise ValueError('Pioneer clear pair lost activation proof or gained a positive collision: ' + name)
            cue = cues[0]
            if cue['encoding'] != 'absolute' or cue['inverted'] or set(cue) - {'action', 'kind', 'channel', 'number', 'encoding', 'inverted', 'targetDeck', 'shifted', 'shiftChannel'}:
                raise ValueError('Pioneer clear pair needs an input-field review: ' + name)
            clear = {k: deepcopy(v) for k, v in cue.items() if k not in {'shifted', 'shiftChannel'}}
            clear.update(action=action.replace('hotcue', 'clearHotcue'), channel=clear_channel, number=slot + clear_offset)
            pending.extend([clear, {**clear, 'action': action, 'releaseOnly': True}, {**clear, 'channel': channel, 'number': slot, 'releaseOnly': True}])
    profile['inputs'].extend(pending)
    if name in {'Pioneer DDJ-200', 'Pioneer DDJ-RB'}:
        profile['scope'] += ' Dedicated Hot Cue clears and paired negative aliases cover both decks.'
        profile.setdefault('gaps', []).append('R492 qualifies eight Hot Cue clear pairs per deck from this own manufacturer MIDI table and hardware diagram. DDJ-200 normal raw7/9 and clear raw8/10 use notes0..7. RB uses raw7/8 normal notes0..7 and clear notes8..15. These are separate own-model facts. Both negative aliases rearm their own role without an inferred app Shift state. Existing controls, output/setup/audio and aliases remain unchanged. Complete modes/lifecycle/host, Bluetooth/USB audio and physical acceptance remain open.')
    else:
        profile['scope'] += ' First-page dedicated Hot Cue clears and paired negative aliases cover all four decks.'
        profile.setdefault('gaps', []).append('R490 qualifies only first-page Hot Cue Shift deletion from this own manufacturer MIDI table and hardware diagram. Raw7/9/11/13 notes0..7 remain activation, while raw8/10/12/14 notes0..7 clear. Both negative aliases rearm their own role even when hardware Shift changes before release. Dedicated opcodes do not infer app Shift state. Page2, other pad modes, complete lifecycle/host/audio and physical acceptance remain open. No hardware configuration, setup or output write is added.')
    return profile
