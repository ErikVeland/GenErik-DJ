# R26 cloud-track exclusion source check: 3 November 2026

Application base: `600f063630cb83cedcd0f4807f62d2fb89afc694`.

Changed source SHA-256: `b08489a70fe8f9294a35ba733558f3f9752a97e44b20d13dfa9ece019e7ddf55` (`Replica/Sources/TDJInterface/LocalMusicLibrary.swift`).

## Change

`LocalMusicLibrary.iosCatalog()` marks a readable file URL as available. For an `ipod-library` URL, it requires MediaPlayer to report that the item is not a cloud item. Cloud items receive the `notDownloaded` state, so library and playlist projections omit them. Protected items remain excluded.

Apple documents `MPMediaItem.isCloudItem` as the cloud-item flag and `assetURL` as the media URL. The app cannot check the file path behind an `ipod-library` URL, so the provider also requires the cloud flag to be clear for this URL scheme.

## Checks

| Check | Result | Detail |
| --- | --- | --- |
| Swift frontend parse | PASS | `LocalMusicLibrary.swift` parsed. |
| `git diff --check` | PASS | No whitespace errors were reported. |
| Package tests | NOT RUN | No test command was requested. |
| iPad check | NOT RUN | No device was accessed. |

## Remaining evidence

On the signed iPad build, confirm that local tracks remain visible and cloud-only or downloadable-only tracks stay hidden. Confirm that locally stored music-library items remain visible after refresh.
