# Collection browsing

Documentation reviewed against the shared implementation on 30 October 2026. [Current readiness and verification](Status.md) is the implementation status record. Dated measurements below apply only to their recorded source and workload.

The prepared collection supports Songs, Playlists, Artists, Albums and Genre. Search matches title, artist, album and genre. Manual sorting applies to the collection; search within suggestions preserves their recommendation order.

Choose Edit, select songs, then Add to Playlist. Create a named playlist or append to an existing one. Local playlists retain track identities without duplicate entries and are saved atomically in `collection-playlists.json` inside the app workspace. This does not write to the system Music library. Source Music playlists are also available after the user opens and refreshes Music library access; only prepared songs appear in the deck browser.

Album metadata is retained from local audio tags and Music imports. Older workspaces without an album field still load. Reimporting a linked song can populate its album without replacing manual preparation.

The category picker and playlist sheet are development controls. The documented categories and Edit/select/Add route are implemented, but exact TDJ1 layout, touch transitions, playlist ordering defaults and persistence scope remain unverified against the reference app.

## Validation — 26 October 2026

`Validation/collection-tests.log` passes playlist order, duplicate suppression, restart, invalid-name rejection, corrupt-file preservation, album retention and legacy library decoding checks. `Validation/collection-ipad.log` records a successful ARM64 iPad simulator SDK build. These are not physical iPad gesture tests.

`Validation/collection-preview.png` is an ImageRenderer diagnostic. Native search and picker controls appear as unsupported placeholders, and lazy rows are not rendered reliably. It is not accepted as a visual fidelity check.

The packaged Mac app was then inspected live. Native category and search controls rendered correctly. Artist filtering, search, track selection, the Add to Playlist sheet, empty-name protection and cancellation were verified. No test playlist was left in the working collection. This verifies the development workflow, not original visual parity.
