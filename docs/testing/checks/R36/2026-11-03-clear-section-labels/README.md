# R36: Clear performance section labels

Erik reported that question marks across the performance UI undermine trust.
All automatic sections currently receive the same raw label score. The blanket suffix does not identify which assignment is correct.

The label formatter now omits that suffix. This updates waveform labels, countdowns and regenerated automatic cue names.
The section editor identifies Automatic and Manual assignments. Internal scores, section roles and manual locks remain unchanged.
Existing automatic cue names refresh on track load. Personal names and deliberate deletions retain their existing handling.

The generated-cue check failed before the formatter change. Fifteen focused structure and cue checks now pass.
This is a presentation correction. It does not establish better musical recognition.
Genre/version recognition and the larger review corpus are tracked by R35.

The numbered build and installation result will be added after the device build.
