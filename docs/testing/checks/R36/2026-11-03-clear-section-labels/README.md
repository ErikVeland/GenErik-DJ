# R36: Clear performance section labels

Erik reported that question marks across the performance UI undermine trust.
All automatic sections currently receive the same raw label score. The blanket suffix does not identify which assignment is correct.

The label formatter now omits that suffix. This updates waveform labels, countdowns and regenerated automatic cue names.
The section editor identifies Automatic and Manual assignments. Internal scores, section roles and manual locks remain unchanged.
Existing automatic cue names refresh on track load. Personal names and deliberate deletions retain their existing handling.

The generated-cue check failed before the formatter change. Fifteen focused structure and cue checks now pass.
This is a presentation correction. It does not establish better musical recognition.
Genre/version recognition and the larger review corpus are tracked by R35.

Signed build 79 passed from clean source `ca1a31f2bf4ef67f5f348c8745ba87aca165ebac`.
It installed and launched on the 10.5-inch test iPad. Device actions stopped after launch.
Erik reloads tracks to refresh automatic cue names and checks labels, countdowns and personal preparation.
Build 79 retains the stable performance dock from build 78. Erik acceptance remains pending.
