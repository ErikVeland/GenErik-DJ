# R26 local-only library regression review: 3 November 2026

Application base: `dd0a297`.

Changed test source diff SHA-256: `698f09efc542535afdc4be75174275be5544eeb425bc7b79512fc7052b720514`.

## Results

| Check | Result | Detail |
| --- | --- | --- |
| Swift frontend parse | PASS | The three changed library test files parsed. |
| `git diff --check` | PASS | No whitespace errors were reported. |
| Local-only expectations | UPDATED | Search, Music playlists and cloud-only custom-playlist members now have local-only expectations. The large-library fixture uses on-device items. |
| Focused test command | BLOCKED | `swift test --package-path Replica --filter LibraryBrowserProjectionTests` stopped before test execution. Command Line Tools Swift 6.3.3 does not match the installed macOS SDK Swift 6.3.2. The compiler also could not write its module cache. |
| App build and device check | NOT RUN | This review did not access a device or start an app build. |

The code still filters Music catalogue rows with `MusicLibraryItem.isOnDevice`. This review corrects tests that expected cloud-only or protected songs to appear.

## Next evidence

Run the focused test with a matching Swift toolchain and verify the local-only list on Erik's signed iPad build.
