# R558 Shared analysis pilot

The first release step is a read-only pilot on the development iPad. It uses a separate CloudKit record type and a small seed from the Mac run. Each record contains an automatic deep result and uses the exact decoded audio identity as its key.

## Implementation and checks

- Test playlist membership, exact identity, result size, and profile checks before adding the receiver.
- Fetch one bounded batch for downloaded Music tracks in playlists. Use existing audio identities and skip tracks with saved deep results.
- Use the existing cloud cancellation path and deep-analysis transaction. Preserve manual preparation. Use local analysis on a miss or service error.
- Prepare seed records from explicit Mac revisions. Keep audio and personal library data outside the public record.
- Verify the signed development build and a live lookup on the A10X. Compare audio continuity and touch response during two-deck playback before release.

The public catalogue and private sync use separate record types. The pilot runs only in personal development builds. Production data, Mac and other device qualification, and opt-in contributions remain open. Contribution intake needs rate limits, validation, review, and an App Store privacy review.

## Development evidence

Apple validated and accepted the read-only Development record type. The schema export confirms that the private preparation record kept its existing permissions. Four Mac results passed exact-key and payload checks. The public Development database accepted all four analysis-only records. A download of one saved payload matched all 6,921 source bytes.

Four focused host checks passed. They cover playlist eligibility, exact audio identity, payload limits, and saved preparation. Build 266 passed signing and is ready for the iPad. The live lookup and A10X playback checks remain open. Build 265 remains available for the pending R559 test. [Build record](../testing/builds/266.json).

The four seed records have zero exact matches in the saved iPad snapshot. For the first positive device check, use a seeded recording in a downloaded Music playlist with a verified audio identity and missing deep analysis.
