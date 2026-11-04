# R38: dense remixes and DJ versions

Build 86 is the feedback baseline. Erik asked for the unresolved dense remixes, including extended and 12-inch versions, followed by genre checks and an iPad build.

## What went wrong

The full-track recogniser often returned music markers through mixed vocals. Instrumental openings also gave it weak language evidence.
A fresh 30-second vocal excerpt recovered words from the same audio in Dan Croll, Harrison, Michael Jackson and New Order recordings.
Reusing the model context did not cause the loss. A direct instrumental-then-vocal test reproduced the successful excerpt result.

A second filter discarded sung words when the speech-silence score exceeded 0.6.
In the Dan Croll excerpt, five lyric segments had a speech-silence score of 0.841 and word scores between 0.658 and 0.775.
The decoder had returned those words, but the extra filter removed them.
The section rules also rejected some longer lines and strong word phrases with weaker voice-classifier scores in the mix.

## Change

Structure version 6 retries tracks whose first pass has no verse, hook or chorus assignment.
It selects the strongest measured vocal windows and skips weak or mostly instrumental windows.
Each window has at least three seconds of detected voice and an average vocal score of at least 0.25.
Windows last up to 30 seconds, start at least 24 seconds apart and run in vocal-score order.
Overlapping windows own separate source intervals. Retained phrases keep their original song positions.

The guided pass can retain words with a score of at least 0.6 despite a high speech-silence score.
Window provenance lets the section pass support longer lyric lines and combine strong words with quieter voice evidence.
The quieter route requires a word score of at least 0.75 and voice evidence of at least 0.15.
Repeated words and the existing musical checks still determine the role.
Ordinary first-pass phrases retain their previous rules.
These are heuristic gates, not calibrated probabilities of a correct section label.

The existing offline model remains pinned. This change adds no model download or playback processing.
Preparation remains serial and cancels during playback or waveform performance touches.
Existing cue positions, cue deletions and locked preparation retain their authority.
No lyric text is stored in an arrangement or its cache.

## Results

The same 28 recordings cover ten genre families and eleven version hints, including seven successful 12-inch sources.
All original input hashes and decoded timelines match. All final section boundaries are valid.
Vocal form is assigned on 15 recordings, compared with nine in build 86.
The nine existing role inventories are unchanged. The two explicit instrumental controls gain no vocal roles.

| Previously unassigned recording | New automatic candidates |
| --- | --- |
| Dan Croll — From Nowhere (Baardsen Remix) | 2 choruses |
| Harrison — All The Things She Said (Extended Mix) | 2 hooks |
| The Beatles — Come Together (DJ Prince 2013 Remix) | 2 verses, 4 hooks |
| Depeche Mode — Policy Of Truth (DJ Tripp 2011 Club Mix) | 3 verses, 2 hooks |
| Michael Jackson — Remember The Time (12-inch Main Mix) | 5 verses, 2 hooks |
| Chic — Everybody Dance (12-inch Mix) | 2 verses, 3 hooks |

The Michael Jackson result is flagged for possible verse fragmentation. Erik must check whether the separate passages belong together.
Donna Summer’s I Feel Love and New Order’s The Perfect Kiss remain unassigned, as do other recordings in `corpus-review.json`.
Short chants, lyrics without a repeated refrain and weak vocal classification remain limits.
The eighth 12-inch source and the other earlier EOF failures remain outside this successful-source sample.

The comparison is machine-assisted and has no independent listening annotations. The increase measures coverage, not section accuracy.
The broad comparison reuses the pinned R37 first-pass word fingerprints and whole-song classifier frames.
It decodes each original source again and runs the production guided refinement.
A final core replay checks every resulting arrangement against the current source.
Fresh full-source checks cover 99 Problems and the Dan Croll remix separately.

All 48 focused checks pass, including source-window ownership, sample rates, long intros, instrumental gaps, quiet mixed vocals,
variable transcript line lengths, nine legitimate refrains, cue preservation and prior musical-structure checks.
99 Problems retains three verses, three main hooks, its opening hook and outro. It does not enter the retry path.
The guided cancellation check stops inference after the cancellation flag.
Host checks do not establish A10X preparation cost or physical audio continuity.

Rejected attempts remain under `TestBuilds/ipad/R38/`. Fixed windows admitted too much instrumental audio and one Dan Croll attempt timed out.
The stronger-window pass removed that failure. The speech-silence and section evidence fixes recovered the additional vocal roles.
The diagnostic tools can retain word fingerprints and numerical scores without lyric text.
