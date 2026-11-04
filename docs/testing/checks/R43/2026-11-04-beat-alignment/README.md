# R43 beat-grid diagnosis

Erik reports that many first beats are far from the audio. Build 95 is assumed because it is the latest installed iPad build.
The exact affected recordings are not yet identified. This diagnosis confirms a detector weakness, not the cause of every reported grid.

The focused probe calls the production rhythm detector with 64 known beats at 120 BPM.
Three pulse-feature patterns share the same beat positions. Only their accents differ.
A distinctive snare on beat two produces the correct tempo and beat alignment, but the wrong bar start with 89% confidence.
A distinctive bass on beat one selects the correct bar start. Equal beats correctly produce no automatic bar position.

The downbeat score measures how much one beat differs from the other three. It does not identify the musical role of that beat.
Grid creation replaces an absent bar position with offset zero. This makes an unsupported bar start appear settled.
The dense-mix fallback chooses alignment by total onset energy. Its confidence comes from periodicity strength, so it does not independently validate phase.

R38 changed section detection. Its refresh uses saved musical analysis, so new section labels do not repair old beat grids.
Existing manual, locked and imported preparation has separate preservation rules.

Run `python3 docs/testing/checks/R43/2026-11-04-beat-alignment/check.py` for the focused diagnosis.
The probe uses production feature frames. It does not test audio decoding, waveform drawing, real-track accuracy or iPad playback.
No application source changed. No new build or device operation occurred.

Next scope: reproduce the reported recordings, measure beat and bar errors at the opening and later passages, then correct phase and bar selection.
Preserve manual corrections and imported preparation. Bind the next test build to those results.
