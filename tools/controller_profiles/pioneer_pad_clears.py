"""First-page clear pairs independently qualified by FLX10 and original DDJ-1000 factory tables."""
from copy import deepcopy


def add_pioneer_pad_clears(profile):
    """Append only the reviewed four-deck layout after every activation and collision check passes."""
    name = profile['id']
    if name not in {'DDJ-FLX10', 'DDJ-1000'} or profile.get('inputProtocol') is not None or profile.get('inputModes') is not None:
        raise ValueError('Pioneer clear layout requires its own model and mode review: ' + name)
    pending = []
    for channel, deck in [(7, 'a'), (9, 'b'), (11, 'c'), (13, 'd')]:
        for slot in range(8):
            action = f"hotcue{slot + 1}{'A' if deck in 'ac' else 'B'}"
            cues = [r for r in profile['inputs'] if r['action'] == action and r.get('targetDeck') == deck and r['kind'] == 'note' and r['channel'] == channel and r['number'] == slot and not r.get('releaseOnly')]
            if len(cues) != 1 or any(r['kind'] == 'note' and r['channel'] == channel + 1 and r['number'] == slot and not r.get('releaseOnly') for r in profile['inputs']):
                raise ValueError('Pioneer clear pair lost activation proof or gained a positive collision: ' + name)
            cue = cues[0]
            if cue['encoding'] != 'absolute' or cue['inverted'] or set(cue) - {'action', 'kind', 'channel', 'number', 'encoding', 'inverted', 'targetDeck', 'shifted', 'shiftChannel'}:
                raise ValueError('Pioneer clear pair needs an input-field review: ' + name)
            clear = {k: deepcopy(v) for k, v in cue.items() if k not in {'shifted', 'shiftChannel'}}
            clear.update(action=action.replace('hotcue', 'clearHotcue'), channel=channel + 1)
            pending.extend([clear, {**clear, 'action': action, 'releaseOnly': True}, {**clear, 'channel': channel, 'releaseOnly': True}])
    profile['inputs'].extend(pending)
    profile['scope'] += ' First-page dedicated Hot Cue clears and paired negative aliases cover all four decks.'
    profile.setdefault('gaps', []).append('R490 qualifies only first-page Hot Cue Shift deletion from this own manufacturer MIDI table and hardware diagram. Raw7/9/11/13 notes0..7 remain activation, while raw8/10/12/14 notes0..7 clear. Both negative aliases rearm their own role even when hardware Shift changes before release. Dedicated opcodes do not infer app Shift state. Page2, other pad modes, complete lifecycle/host/audio and physical acceptance remain open. No hardware configuration, setup or output write is added.')
    return profile
