"""Shared app functions; each caller supplies its own reviewed grid addresses."""
from curated import add


def add_native_dj_grid(result, rows, output_channel=0):
    """Add app quadrant functions to independently reviewed bottom-to-top wire rows."""
    for side,deck in enumerate('abcd'):
        left=4*(side%2)
        bottom=4*(side//2)
        for action,offset,colour in [('play',0,19),('cuePreview',1,5),('sync',2,45),('load',3,None),
                                     ('cue',10,19),('loopIn',11,None),('loopOut',12,None),('reloop',13,None)]:
            add(result,action,0,rows[bottom+offset//10][left+offset%10],deck=deck,feedback=colour is not None)
            if colour is not None:result['outputs'][-1].update(onValue=colour,channel=output_channel)
        suffix='A' if deck in 'ac' else 'B'
        result['outputs'].append({'action':'loop'+suffix,'kind':'note','channel':output_channel,'number':rows[bottom+1][left+3],
                                  'onValue':19,'offValue':0,'offUsesNoteOn':True,'targetDeck':deck})
        for slot in range(8):
            add(result,f'hotcue{slot+1}',0,rows[bottom+2+slot//4][left+slot%4],deck=deck,feedback=True)
            result['outputs'][-1].update(onValue=45,channel=output_channel)

