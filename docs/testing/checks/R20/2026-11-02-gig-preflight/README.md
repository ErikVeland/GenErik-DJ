# R20: Gig preflight, 2 November 2026

Status: open. This evidence does not establish gig readiness for 3 November.

Erik requested closure of the remaining blockers before an actual gig. The current scope includes hardware acceptance and unfinished features. They cannot all close through a successful build.

## Evidence

- `results.json` records the source identity, commands and exit codes for this run.
- `renderer.json` records the five-minute host renderer workload when it completes.
- The renderer uses two looping decks, six effects, key lock, scratch traffic and two background workers.
- `recording-stop.log` covers the existing native recording-stop checks.
- `adaptive-grid.log` covers bounds, interpolation, deck isolation and concurrent map publication.
- `concurrent-work.json` records another process committing pending work and building iPad candidates during this run.

The renderer is a host C-engine check. It does not exercise iPad audio hardware, real songs, the Swift interface or the complete adaptive-grid workload. Concurrent compilation affects timing measurements. A failed timing gate remains failed. No deadline is relaxed.

## Results

The source hash matches signed build 49. No application content changed during the checks, although another process committed pending work and built candidates.

- Five-minute renderer: failed. Six callbacks exceeded the 2.667 ms limit. The maximum was 5.111 ms. Concurrent compilation limits timing interpretation.
- One-minute repeat after compilation: passed. Zero overruns. The maximum was 2.133 ms with the same binary and workload settings.
- Both renderer runs: zero invalid samples, rejected commands, full queues and clock errors.
- Recording stop: passed. The check reproduced the blocking-stop baseline and verified the request-stop path retains accepted frames.
- Adaptive map: passed bounds, interpolation, deck isolation and concurrent publication checks.

The shorter repeat does not replace the failed sustained run. No conclusion about audible continuity, actual A10X timing or gig acceptance follows from these host checks.

## Remaining blockers

| Issue | Required closure |
| --- | --- |
| B01: browser appearance | Inspect the selected candidate on the actual iPad. The older Mac snapshot does not establish an iPad defect. |
| B02: sustained audio | Freeze one candidate. Test it on the A10X with the intended audio route, library, controls, effects and recording. Retain any interruption or failure. |
| B03: musical recognition | Automatic section, drop and rhythmic-ending recognition remain incomplete. Use verified manual markers where supported. Do not rely on unverified automatic recovery. |
| B04: key preparation | Direct Mixed In Key extraction, review and Traktor write-back remain incomplete. Verify the required preparation before the set. |
| B05: controllers | Verify the exact controller, connection, main output, headphone cueing and control mapping. Generic MIDI support does not prove original Z1 compatibility. |
| B06: private history | Keep unresolved candidates listed and preserved. Reconciliation remains open. |
| Candidate ownership | The controller chat has now held source and builds. Build 49 is saved. Build 46 remains installed. Select the rehearsal candidate before deployment. |

## Device acceptance

Record the build, iPad, controller, output device, sample rate and rehearsal duration.

1. Confirm the selected build in Settings → About.
2. Load tomorrow's library and playlists.
3. Check main output and headphone cueing separately.
4. Mix both decks with Sync, scratch, loops, slices, Flux and the effects needed tomorrow.
5. Check manual takeover, Brake release and queued-load cancellation.
6. Record a representative rehearsal set.
7. Stop recording and retrieve the audio and tracklist.
8. Listen to the retrieved recording and check the timestamps.
9. Record every dropout, click, unexpected stop or blocked control.
10. Confirm Erik's acceptance of that exact build and setup.

Retain a proven performance setup and rollback build. Builds 46 and later have no recorded gig acceptance. A saved build alone is not a proven fallback.

This preflight made no application edits and performed no device operations. The installed app remains under Erik's control.
