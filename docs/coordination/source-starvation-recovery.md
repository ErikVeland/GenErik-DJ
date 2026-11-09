# R105 source starvation recovery

A streamed deck could keep moving its read position during a buffer miss. The worker then had to chase the moving position. A long outage could take the deck to the end of the file before samples returned. The deck stayed ended after the cache refilled.

The renderer now holds the affected source position during normal playback when it runs out of samples. The worker requests the held position. The master clock and other deck continue. The deck retains its playing state and saved Sync choice. The existing short fade handles the output edge.

At a render boundary, the deck checks coverage at the held position. With Sync enabled, it also checks coverage at the nearest position that matches the current master beat. It resets the stretcher and fades back in when those samples are available. With Sync disabled, playback returns at the held position. Manual touch, Brake and nonstandard performance rates retain their existing control paths. This change adds no file reads, allocation or waiting to the callback.

The fault probe deliberately stopped read-ahead until a streamed deck ran out of samples. It kept the outage long enough for the previous code to reach the end. It then restored read-ahead without another Play command. The other deck remained audible throughout. Both Sync cases recovered. The Sync-on case checked phase after recovery. The tests also checked keylock, unchanged start identity and no further missing frames after refill. Six focused tests passed across nine cases on the candidate source.

The fix recovers from temporary starvation once samples return. It cannot supply audio that remains unavailable. The A10X and Z1 still need a live check.

[Build 168](../testing/builds/168.json) installed on A10X, and iPadOS accepted launch. The source hash and logs are under `TestBuilds/r105/`.
