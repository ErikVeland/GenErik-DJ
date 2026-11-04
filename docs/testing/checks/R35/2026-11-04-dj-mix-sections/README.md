# R35: First genre/version-aware rhythmic section profile

Erik authorised review, a production section-detection improvement and an iPad installation on 4 November 2026.

## Review findings

The 104-entry baseline contained 79 short-section flags and 84 unassigned-vocal-form flags.
Those flags are not independently verified musical errors. They overlap and include instrumentals and a cappellas.

The closer review inspected ten source recordings through their decoded audio features and timecoded predictions.
It includes extended mixes, 12-inch versions, a radio edit, an a cappella, a remix and an uninterrupted instrumental.
One provisional held-out entry was inspected. This study is not a blind held-out evaluation.
No listening-based full-song annotations or semantic-accuracy percentage are claimed.

The review confirmed two implementation problems:

- An intro required a lower average level than the main track. A full-level rhythmic opening could not qualify.
- Short novelty changes within a continuous low-vocal beat passage created several top-level sections.

Harrison’s **All The Things She Said (Extended Mix)** illustrates both problems.
The old engine already identified about 30 seconds of usable mix-in audio, but split the opening into instrumental sections.
Its measured ending also contains a long low-vocal beat passage.
Tiësto’s **The Business (Extended Mix)** split the opening as its level rose.
A sustained rhythmic change near 32 seconds must remain outside that introductory groove.

The other inspected cases include GenErik’s Matt Berry extended edit, Donna Summer’s I Feel Love 12-inch version,
Chic’s Everybody Dance 12-inch mix and New Order’s The Perfect Kiss 12-inch version.
Maroon 5’s radio mix, Destiny’s Child’s a cappella/remix and Jaydee’s uninterrupted instrumental provide controls.
Broader verse/hook assignments and the baseline’s tempo/key disagreements remain unresolved.

## Production change

Structure version 4 receives each track’s title and genre.
A dance-style tag or an explicit extended/club/dub/12-inch version enables the rhythmic-edge profile.
A cappella versions decline that profile. Broad Pop tags can be outweighed by explicit version wording and measured audio.
This is a metadata-guided audio profile, not a trained genre classifier.

The profile requires a supported tempo, at least eight bars of passage duration, known low vocal activity,
strong low-frequency rhythm and sustained activity. A sustained change ends the passage.
At least 75% of the passage must satisfy the local evidence checks.
Brief fills do not automatically become new full sections. An established nearby transition remains the intro boundary.

The profile names supported passages **Rhythmic intro** and **Rhythmic outro** and consolidates their internal boundaries.
It declines whole-track intro/outro assignments. Each edge is restricted to its outer 40% of the audible timeline.
The radio, a cappella and full-loop controls guard against title-only assignments and blanket relabelling.
These are conservative engineering settings, not universal musical rules or calibrated confidence probabilities.

Title and genre join the arrangement cache identity. Old caches upgrade on deck load.
A metadata change cannot reuse a pending preparation task for a different context.
Manual preparation keeps its authority. Automatic cues retain their frames and receive their new containing-section names.
No model download, playback DSP change or audio-callback work is added.

## Verification

The new API initially failed compilation. With the context API connected but no new rule, 14 assertions failed.
The first implementation exposed a two-second ending-boundary offset. That failure remains retained.
Twenty-five focused production checks now pass, including actual recorded features, cue protection and the earlier chorus checks.
The tests include a full-level synthetic groove, explicit 12-inch wording without a genre tag,
a radio control, an a cappella, missing vocal evidence, vocals throughout and a sustained rhythm break.

`compare.py` retains default-context and genre/version-context outputs for the ten inspected recordings.
The full 104-entry candidate run is in `corpus-comparison.json`. It retains 99 successful analyses and the same five failures.
The profile applies on 22 entries. Short-section flags change from 79 to 74. Key and energy-level choices match on all 99 entries.
Four repeat decodes differ in low floating-point bits. The maximum tempo difference is about 0.0000000011 BPM.
The explicit 0.000001 BPM comparison tolerance and raw differences remain in `numeric-comparison.json`.
This evaluates the first rhythmic-edge change. It does not establish correct verse/chorus form throughout the library.

Signed build 81 passed from clean application source `888dfcf4e` and installed and launched on the 10.5-inch test iPad.
The full source and app identities are in `result.json` and `docs/testing/builds/81.json`. Device actions stopped after launch.
Erik checks the new edge names and boundaries, retained manual preparation and clean other-deck audio.

## Source-bound examples

| Recording | Baseline sections | Candidate sections | Candidate edge passages |
| --- | ---: | ---: | --- |
| Harrison — All The Things She Said (Extended Mix) | 15 | 12 | Intro 0–30.56 s. Outro 186.72–229.88 s. |
| Tiësto — The Business (Extended Mix) | 14 | 13 | Intro 0–32.00 s. Outro 183.97–226.00 s. |
| New Order — The Perfect Kiss (12-inch) | 30 | 24 | Intro 0–93.11 s. No long outro inferred at the ending. |
| Donna Summer — I Feel Love (12-inch) | 35 | 32 | Outro 450.08–495.19 s. |

These are observed output changes supported by the feature review, not independently annotated song-form accuracy.
The five source EOF failures, broad vocal roles and imported tempo/key disagreements remain open.
