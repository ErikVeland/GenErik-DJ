# R95: track source recovery

Erik reported failed loads on 9 November 2026, particularly Hannah by Fred again..
He then reported that no tracks would load. The connected A10X iPad confirms build 151.
A failed selection showed No track loaded or restored the previous deck track without a visible deck error.

## Cause and change

The saved iPad library contains 612 records marked as managed audio.
The device file listing shows that 569 corresponding audio copies are missing.
These include Hannah and 38 Fred again.. tracks. Hannah remains available through its exact Music persistent ID.
Its artwork, waveform and saved grid remain in the workspace.

The browser preferred the managed flag over the selected Music item.
The saved-library browser test reproduced an empty deck and audio-file error 2003334207.
The same track loaded through Music's direct-source path in the host check.
No evidence links this failure to the two dots in the artist name.
The cause of the earlier copy removal remains unverified.

Available Music selections now use their exact Music source. Direct saved-track loads also resolve available Music sources.
Registration repairs a managed flag when its copy is missing. Track identity, manual grid and cues remain retained.
The iOS provider verifies the persistent ID returned by its query. Titles and filenames do not select audio.
Offline managed copies remain usable when no local Music item is available.

A failed load displays its selected title and error on the deck and writes the error to the local log.
Play cannot restart the previous track after a failed replacement. A successful load clears this state.
Control characters become spaces in the error label only. Stored metadata remains unchanged.

## Verification

Evidence is retained under `TestBuilds/r95/`, including the iPad catalog, library and file listing.
The saved-library browser check failed before the change and passed after it with the local Hannah audio.
Synthetic checks cover missing copies, saved preparation, duplicate tags, dots, quotes, percent signs,
URL punctuation, Unicode, combining accents and control characters in tags.
The completed focused load checks also cover cancellation, stale completion and the other playing deck.
The combined test process exhausted the shared streaming limit, including in a serial run.
Isolated test processes retain that limit. A single-model check passed sixteen consecutive replacements.
The larger ownership-test batch was stopped after the focused checks. Incomplete and failed logs remain retained.
12 isolated focused tests passed. The filename test includes six cases.

Device playback and touch acceptance remain open. Host checks do not establish A10X performance readiness.

## iPad check

1. Load Hannah from the Music browser.
2. Check its title, waveform, grid and audio.
3. Load another previously failing track into each deck.
4. Keep one deck playing while you load the other.
5. Check audio continuity and touch response.
6. Report any remaining failed load and its deck message.
