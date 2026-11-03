# R26 local library projection compile review: 3 November 2026

The current source map in `LibraryBrowserProjection` uses source IDs. The first focused package build found a stale `bySource` lookup in the native-item projection. The code now reads the matching track from `bySourceID[item.source.id]`.

| Check | Result | Detail |
| --- | --- | --- |
| Swift syntax parse | PASS | `LibraryBrowserProjection.swift` parsed. |
| Focused package build | BLOCKED | After the lookup fix, Swift compiled `TDJCore` and reached interface code generation. The Swift 6.3.3 compiler then crashed. The test target also could not import `Testing`. Logs: [R23 wheel jog check](../../R23/2026-11-03-flx4-wheel-jog-source-check/). |
| Local/cloud behaviour | SOURCE REVIEW PASS | Existing projection and search tests cover local songs, cloud-only songs and mixed playlists. The package test suite did not execute in this review. |
| Device check | PENDING | Erik owns the signed iPad review. No device was accessed. |

This record does not claim a package test pass or device acceptance.
