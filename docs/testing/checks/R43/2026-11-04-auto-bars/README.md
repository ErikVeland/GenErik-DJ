# R43 automatic bar starts

Erik reports that Creep still misses its first beat after build 98. The saved iPad analysis has 136.02 BPM, but its grid remains the inherited 68.0085 BPM import.
The app treats that untouched import as manual preparation. The actual iPad playback cache was copied for this check.
Its first 32 seconds match the local mono source exactly. The first attack is at 0.180408 seconds.

The detector now combines drum-attack patterns, sustained sound changes and beat-synchronous chroma changes.
It uses full-song context after tempo selection. A distinctive snare alone cannot identify beat one.
The full Creep cache gives 136.017769 BPM, an anchor at 0.180574 seconds and bar offset zero.
The short excerpt remains inconclusive. The regression retains that result and checks the complete bar-feature timeline separately.
The frozen features contain no lyric text or audio samples.

Untouched unlocked imports can refresh after audio is ready, while both decks are idle.
A stored bar-analysis version requests one fresh pass. Waveform replacement retains that version.
Analysis saves and load preparation now adopt the supported grid together. The generated grid cue and untouched initial view follow that grid.
The immediate audio-loading path remains in place. A status message shows grid preparation and its result. Playback and performance touches cancel preparation.

Legacy import eligibility requires an exact match to an unlocked original grid. New user grid edits get an explicit protection flag.
Locks, edited grids and adaptive maps stay protected. An inherited grid requires stronger bar support and a compatible tempo, including half/double relationships.
The original Traktor record remains available through RESET. Catalogue refreshes retain the supported automatic choice.

Thirty focused cases pass: 23 rhythm/bar/state cases and seven late-rhythm cases.
They cover loud offbeats, rotated bass accents, a loud snare, quiet pickups, harmonic changes, triple metre rejection, uniform pulses, the full Creep timeline and the saved iPad preparation.
State checks cover legacy decoding, waveform hydration, edit flags, locks and conservative import replacement.
The actual cache check passes. Native host cancellation takes about 0.06 seconds. A10X cost and physical audio acceptance remain unverified.

Nine recordings cover eight genre-family hints and extended, 12-inch, dub, remix and instrumental variants.
All analyses have valid timelines and bounds. Seven produce bar candidates. Only Creep and The Bug pass the stronger support gate for an inherited import.
Harrison, Vampire Weekend, Scooter, The Beatles and Dan Croll remain lower-support candidates, so their existing imports stay authoritative.
Michael Jackson’s 12-inch mix and Zombie Thumper remain unresolved.
This is a development review without independent listening labels or an accuracy percentage.

The design uses rhythmic and harmonic evidence, as discussed in [Krebs et al., ISMIR 2016](https://research.jku.at/en/publications/downbeat-tracking-using-beat-synchronous-features-and-recurrent-n/).
This implementation uses native DSP and does not ship that paper’s neural model.

Run `python3 docs/testing/checks/R43/2026-11-04-auto-bars/check.py` for the 23 focused cases.
Run `python3 docs/testing/checks/R29/2026-11-03-late-rhythm/check.py` for the seven late-rhythm cases.
The source-bound genre results are in `genre-review.json`. Native input audio and caches remain local under `TestBuilds/ipad/R43/`.
Failed and invalid attempts remain recorded. The README and result distinguish the excerpt assumption from the full-song regression.

Signed build **105** passed compilation, framework resolution, signing and source identity checks.
Its source is `bdbd174157029a0051674225dfc58ef4cfed29d2`. Compilation took 315.86 seconds.
The installer timed out after 60 seconds. Installation is unconfirmed and launch was not requested.
The consolidation chat then took ownership of the main merge and final installation. No retry or later device action occurred here.
The previous cache archive 104 matches the authoritative main-104 digest. Its duplicate record is retained separately.
See `../../../../coordination/handovers/R43-automatic-bars-2026-11-04.md` for the checkpoint and remaining acceptance.
