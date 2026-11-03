# R26 local preparation availability source check: 3 November 2026

Application base: `577c23a22813dbd26bec29c3237d224200ade8a1`.

Changed source SHA-256: `348fc845e31e07f8f9eec7034fc77838f81a08a16a9d7bee9488bd38059ca82d` (`Replica/Sources/TDJInterface/LocalMusicLibrary.swift`).

## Change

The iOS preparation lookup now checks the current MediaPlayer item again. It accepts readable file URLs and `ipod-library` URLs only when the item is not marked as a cloud item. Protected, missing and cloud-only items fail as unavailable. This closes the stale-catalogue case where an item changes availability after the library refresh.

## Checks

| Check | Result | Detail |
| --- | --- | --- |
| Swift frontend parse | PASS | `LocalMusicLibrary.swift` parsed. |
| `git diff --check` | PASS | No whitespace errors were reported. |
| STE linter | PASS | The updated request ledger passed. |
| Package tests and app build | NOT RUN | No test or build was requested. |
| iPad check | NOT RUN | No device was accessed. |

## Remaining evidence

On iPad, confirm local songs remain visible and that a song which becomes cloud-only after refresh cannot be prepared. Confirm the error is clear and playback remains unaffected.
