# Collection browsing

Current build and acceptance: [project status](../docs/coordination/README.md). Historical measurements apply only to their recorded source.

The song browser supports Songs, Playlists, Artists, Albums and Genre. Search matches title, artist, album and genre across the full library, including native songs that have not finished analysis. Recommendation membership, tempo/key compatibility and the current playlist or category do not restrict search results. Search uses the selected song sort, with title order when the previous view used playlist order.

## Search and browser labels — 2 November 2026

Entering a non-whitespace query displays song results from any browser section. The selected destination deck and previous browsing context are retained. Clearing the query restores that context, including recommendation order or playlist membership. Songs with unavailable or protected audio can still appear in search, with their existing loading restrictions.

The recommendation heading reads **Rec for [track title]**, using the track that supplies the recommendation criteria. Long titles truncate visually; the accessibility label retains the full title. When there is no reference track, the heading reads **Recommendations**.

The optional **Prep list** is a manual shortlist saved in `queue.json`. Its tab appears only when it contains songs. The add button remains available in the song detail pane. Adding songs does not start playback or schedule an automatic transition.

Choose Edit, select songs, then Add to Playlist. Create a named playlist or append to an existing one. Local playlists retain track identities without duplicate entries and are saved atomically in `collection-playlists.json` inside the app workspace. This does not write to the system Music library. Source Music playlists are also available from the native Music catalogue, including songs that have not finished analysis.

Album metadata is retained from local audio tags and Music imports. Older workspaces without an album field still load. Reimporting a linked song can populate its album without replacing manual preparation.

The category picker and playlist sheet are development controls. The documented categories and Edit/select/Add route are implemented, but exact TDJ1 layout, touch transitions, playlist ordering defaults and persistence scope remain unverified against the reference app.

## Validation — 26 October 2026

`Validation/collection-tests.log` passes playlist order, duplicate suppression, restart, invalid-name rejection, corrupt-file preservation, album retention and legacy library decoding checks. `Validation/collection-ipad.log` records a successful ARM64 iPad simulator SDK build. These are not physical iPad gesture tests.

`Validation/collection-preview.png` is an ImageRenderer diagnostic. Native search and picker controls appear as unsupported placeholders, and lazy rows are not rendered reliably. It is not accepted as a visual fidelity check.

The packaged Mac app was then inspected live. Native category and search controls rendered correctly. Artist filtering, search, track selection, the Add to Playlist sheet, empty-name protection and cancellation were verified. No test playlist was left in the working collection. This verifies the development workflow, not original visual parity.
