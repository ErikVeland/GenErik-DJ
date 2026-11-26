# R558 Shared analysis pilot

The first release step is a read-only pilot on the development iPad. It uses a separate CloudKit record type and a small seed from the Mac run. Each record contains an automatic deep result and uses the exact decoded audio identity as its key.

## Implementation and checks

- Test playlist membership, exact identity, result size, and profile checks before adding the receiver.
- Fetch one bounded batch for downloaded Music tracks in playlists. Use existing audio identities and skip tracks with saved deep results.
- Use the existing cloud cancellation path and deep-analysis transaction. Preserve manual preparation. Use local analysis on a miss or service error.
- Prepare seed records from explicit Mac revisions. Keep audio and personal library data outside the public record.
- Verify the signed development build and a live lookup on the A10X. Compare audio continuity and touch response during two-deck playback before release.

The public catalogue and private sync use separate record types. The pilot runs only in personal development builds. Production data, Mac and other device qualification, and opt-in contributions remain open. Contribution intake needs rate limits, validation, review, and an App Store privacy review.
