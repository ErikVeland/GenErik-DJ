"""Encode application inputs without changing the reviewed protocol records."""
from copy import deepcopy

INPUT_KEYS={
    'action':'a','kind':'k','channel':'c','number':'n','encoding':'e','inverted':'i',
    'targetDeck':'d','anyChannel':'w','argument':'g','releaseOnly':'r','requiredMode':'m',
    'shifted':'s','shiftInput':'t','holdInput':'h','shiftChannel':'z','lowNumber':'l',
    'pulse':'p','requiresTouch':'u','directionStep':'v','deckBank':'b',
}


def compact_runtime(value):
    """Retain native fields and packet bytes while shortening input property names."""
    result=deepcopy(value)
    for profile in result['profiles']:
        for key in ['definition','gaps','hardwareMode']:profile.pop(key,None)
        compact=[]
        for row in profile['inputs']:
            unknown=set(row)-set(INPUT_KEYS)-{'layerIndependent'}
            if unknown:raise ValueError('The compact controller input has unreviewed fields: '+', '.join(sorted(unknown)))
            compact.append({INPUT_KEYS.get(k,k):v for k,v in row.items()
                if not ((k=='kind' and v=='note') or (k=='encoding' and v=='absolute') or (k=='inverted' and v is False))})
        profile['inputs']=compact
    return result
