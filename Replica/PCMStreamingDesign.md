# Bounded PCM design and integration history

Documentation reviewed against the shared implementation on 30 October 2026. [Current readiness and verification](Status.md) is the implementation status record. Dated measurements below apply only to their recorded source and workload.

## Historical design and validation record

The remainder preserves earlier design steps and measurements. Proposed declarations and old budgets are historical; current constants and acceptance are described in Status.md and the production headers.

Historical checkpoint: native handoff correction, 29 October 2026. Current budget and ticket semantics below supersede the earlier 256-block design. [Native batch07](Validation/TransportDiscontinuities-2026-10-29-07/manifest.json), including the stopped-output readiness query, passes both native suites in normal, address/undefined and thread-sanitized builds; the earlier source-bound Swift 60/300-second results are preserved in [the pre-correction report](Validation/audio-priority-2026-10-28.md). Integration must rerun against the correction. Physical-device acceptance remains open.

## Problem and required behaviour

`tdj_asset_map` maps the entire private stereo Float32 file and touches each page before loading the deck. Those clean pages remain reclaimable. A four-hour 48 kHz track occupies 5,529,600,000 bytes, exceeding the minimum A10X iPad's 4 GB of RAM. Touching the entire file does not ensure that its beginning remains resident when playback starts. Both the transport and Keylock currently read that mapping directly.

Replace file-backed callback reads with bounded, prefilled PCM buffers. Keep `tdj_asset_create` and all in-memory tests unchanged as the numerical reference. File I/O, buffer allocation, descriptor construction, cancellation, file closing and disposal must run outside the audio callback and MainActor. The callback must never wait for preparation or read the file to repair a miss.

The existing decoder may still create the private PCM file in advance. This proposal changes playback access, not the original decoder, analysis data, or media files.

## Memory and ownership

Current budget: 512 blocks of 8,192 stereo frames per loaded asset. Each block uses 65,536 bytes, giving 32 MiB per asset. Two active decks use 64 MiB of PCM buffers. Permit at most one replacement asset per deck, for a global PCM ceiling of 128 MiB during replacement. Retired generations count towards that ceiling until disposal completes. Descriptor tables, queues and Keylock/FX state have separate fixed bounds and must be reported in the manifest.

At 48 kHz, one asset's pool covers about 87.4 seconds of source audio. This is a capacity budget, not a promise to pin an entire loop or every cue. At the maximum supported source rate and speed, the worker must calculate whether all required windows fit. Reject preparation explicitly if they do not. Do not silently shrink the Keylock read window or evict mandatory live data.

Each asset has one preparation worker and one render consumer. Both decks can share an asset only through the same serial render consumer. Buffer references are immutable after publication. Worker-owned reference counts cover every ready, current and retired descriptor table. Only the worker changes these counts or reuses blocks.

A published table references at most 240 blocks. The physical pool can hold two completely disjoint 240-block tables plus 32 spare blocks. This includes the worst case where optional cue warming fills the old table. The worker can therefore fill a complete next mandatory window while the consumer retains its immutable current table. The earlier 256-block design could deadlock even when each individual window fitted: old 141 plus new129 with one shared block needs269 slots. That baseline is preserved in `Validation/BackgroundAckRetention-2026-10-29-01`.

The worker can withdraw an obsolete or incomplete pending table with one compare/exchange before rebuilding it. If the consumer already took it, the worker leaves it alone. This allows bounded fill passes to finish the next window without requiring extra zero-frame consumer calls. The consumer still checks immediate minimum coverage before adopting any candidate. A working mandatory union exceeding240 blocks reports CAPACITY. A producer-only READY reservation that loses admission as live demand moves reports CAPACITY once and stops contributing ranges; it cannot block live audio indefinitely.

Use three preallocated descriptor tables per asset. The worker can publish at most one prepared table. The consumer adopts it at a callback boundary and retires its previous table through a fixed SPSC mailbox. The worker may reuse a retired table and its unreferenced blocks only after that retirement arrives. If the retirement mailbox is full, the consumer retains its current table and leaves the new table pending. No callback retries, allocation, reclamation or waiting are required. The worker must keep the current table valid while preparing its successor.

Asset retirement is separate from table retirement. The existing generation-retirement message proves that the render consumer no longer references the asset. After that message, a disposal queue cancels and joins the worker, drains its tables, closes its file and frees its pool. `PCMAsset.deinit` must not perform a large `munmap`, worker join or file disposal on MainActor. Shutdown first stops the render consumer, then disposes the remaining assets on that queue.

## Proposed API boundary

Names below describe responsibilities. Final declarations follow the agreed implementation split.

| API | Caller | Responsibility |
| --- | --- | --- |
| `tdj_asset_open_stream(path, frames, rate, limits)` | PCM preparation queue | Validate file length, allocate fixed pool/tables, open the read-only file. No full-file mapping. |
| `tdj_asset_prepare(asset, request)` | Asset worker | Fill required blocks with checked `pread`, build a complete immutable table, publish its preparation token. |
| `tdj_asset_prepare_status(asset, token)` | Serial control producer | Report pending, ready, cancelled, invalid or I/O failure. |
| `tdj_asset_publish(asset, token)` | Serial control producer | Select a prepared target for a transport command. This cannot discard live mandatory windows. |
| `tdj_asset_read_stereo(view, frame, out)` | C/C++ render path | Read one ready frame, return an explicit missing result. No I/O, allocation, locks or ARC. |
| `tdj_keylock_read_ranges(processor, proposedState, outputFrames, ranges)` | Render consumer / preparation snapshot | Report all input intervals needed for the next quantum, reset, or speed transition. |
| `tdj_asset_telemetry(asset)` | Control producer | Copy fixed atomic counters and latest missing range. |

Commands retain deck generation checks and gain a preparation token where they change required source regions. The renderer checks that token and required coverage before accepting the state change. A ready token for an old generation, old speed, or different loop cannot authorise the command.

The table lookup must have a strict bound. Start with an immutable fixed hash table plus a cached current-block pointer in the reader. Build and validate the hash layout on the worker. Cap probes explicitly, and benchmark its callback cost against the contiguous reference. Interpolation needs both frames, including the loop-start frame when the next frame wraps. C++ Keylock must use the same accessor, including mid/side conversion. Never construct a fake contiguous pointer across cache blocks.

## Required windows and scheduling

Priority order is current audible playback, imminent loop wrap/queued start, mandatory Flux return, accepted target gesture, then optional cue warming. Fill one block at a time. Re-check urgent requests and cancellation between blocks. Analysis, artwork, library scans and cache conversion cannot share or block this worker.

Use a dedicated serial playback preparation queue at user-initiated QoS. It is below the audio thread's real-time scheduling and above background analysis. The existing `PCMCache.worker` is a separate `AnalysisWorker`, but its QoS is background and it can spend a long time decoding. Continuous read-ahead requires its own worker, independent of that initial decoder queue.

Track a forward and reverse safety reserve in source seconds, not a fixed number of output frames. Initial targets are two seconds of forward source travel and one second behind, enlarged for actual Keylock bounds and measured worker stalls. At 8× speed, source travel consumes the reserve eight times faster. Compute the reserve from speed, source/output rate and observed service latency. Report the actual reserve in telemetry. These starting values require device measurements.

For loops shorter than the pool budget, pin the complete loop plus interpolation coverage. For longer loops, retain the current running region and both wrap edges, then read ahead through the interior. Freeze slices use the same mechanism. Keep the continuing Flux position warm while a temporary slice or loop owns audible playback. The continuing position advances even when it is not audible.

Prewarm eight saved cue targets opportunistically. Cue warming cannot evict current playback, Keylock history, wrap edges or Flux return. The first touch on a cold cue requests urgent preparation while current audio continues. Do not acknowledge or display it as an executed jump before the target is ready.

## Transport acceptance rules

Load becomes ready only after its first playback and Keylock windows are complete. A plain Play from an already prepared position retains its existing timing. Pause, volume, crossfader, EQ and FX controls never wait for a cache target.

Seek, cue, saved-loop recall, Freeze audition and reverse starts prepare their target before the renderer accepts them. Keep the old playback running during preparation. For quantised commands, accept only if the table covers the scheduled execution and continuing playback until that point. If preparation misses that boundary, leave the old music running and report the action as pending or failed. Moving the action to a later musical boundary requires an explicit policy and a separate test.

Tempo, Keylock enable and performance-rate changes can also expand read requirements. Check the proposed bounds before accepting these commands. A loop exit with Flux must already have its continuing position ready. A release gesture must not become an unbounded wait. Maintaining that reserve is therefore mandatory throughout the temporary action, rather than starting preparation only on release.

Coalesce superseded navigation requests by deck generation and request serial. Preserve the latest target without queuing every touch movement. Retain the previous accepted target until the replacement is ready. Do not coalesce release/cancel messages away or redirect a held contact to another mode.

## Keylock bounds

Use the configured vendor instance's `inputLatency()`, `outputLatency()`, `seekLength()` and `outputSeekLength(speed)`. Do not approximate these with an assumed small cache window.

The current wrapper primes by reading `outputSeekLength(speed)` input-timeline frames. A speed change reads history beginning at `cursor - seekLength()*step`, after moving cursor to `position + (inputLatency() + speed*outputLatency())*step`. Normal processing consumes `floor(64*speed + remainder)` input frames per 64 output frames. Include the dry interpolation reads at the current position, all vendor accesses and one interpolation neighbour. Use the exact integer conversions from the wrapper.

Extract range calculation and actual read requests from one shared planning function, so the worker and renderer cannot drift. Test it with an instrumented reader that records every index the vendor requests. Cover reset, every supported speed endpoint, fast direction changes that bypass Keylock, 44.1/48/96/192 kHz source/output combinations, zero-padding outside the file, and wrapped short loops. Split wrapped intervals at loop boundaries. A tiny loop can alias many requested ranges to the same few blocks.

An initial instrumented-copy probe covers 25 source-rate/speed combinations at 48 kHz output. The configured vendor instance reports input latency 2,880 frames, output latency 4,320 frames and seek length 7,200 frames. At 384 kHz source and 8× speed, priming requests input positions up to 303,608 source frames ahead. A speed transition requests up to 307,704 ahead or 30,240 behind in this probe. This proves that a single 8,192-frame cache block is insufficient. It does not establish complete bounds for all output rates or trajectories. Add the interpolation neighbour when converting positions to required blocks. Results and source hashes are in `Validation/keylock-read-ranges-design-probe.json`; `Validation/keylock-read-ranges-design-probe.py` reproduces the probe using a temporary instrumented copy without changing production Sources.

## Misses and overload

Prevent expected misses by checking coverage before state changes and preserving the reserve. Storage failure or a worker stall can still exhaust any finite cache. No finite reserve proves uninterrupted output under arbitrary I/O failure.

Publish distinct counters for missing source reads, rejected cold commands, late preparation, low reserve, I/O errors, pool exhaustion, retirement backpressure and maximum preparation latency. Include deck generation, source range and first output frame for the latest miss. Out-of-file zero-padding is legitimate and must not count as a cache miss.

On a genuine unexpected miss, the callback must remain bounded. Apply a short fixed emergency fade and report the incident. Never replay stale unrelated PCM, read the file, spin for the worker, or count substituted output as successful audio continuity. The runtime check fails on any missing source frame or emergency substitution, even when its deadline metrics pass. The emergency behaviour remains a failure policy, not parity evidence.

## Implementation split and acceptance

The gesture/DSP chat owns C pool/table/accessor code, Keylock adaptation and native boundary tests. The main recreation chat owns Swift worker lifecycle, command preparation/coalescing, UI pending state, retirement/disposal queue and production runtime integration. Agree on the C API before either side edits these Sources.

1. Keep the current in-memory transport, loop, Flux, Keylock and effect regressions as the exact reference.
2. Compare streamed output with that reference across block boundaries, end-of-file, fractional interpolation, reverse, tiny loops, long-loop wraps, quantised jumps and Flux release. Require identical output where the same algorithm path applies.
3. Add a deterministic slow reader and short reads/I/O failures. Verify cold commands leave current music running, stale tokens fail, cancellation preserves ownership, and retirement cannot reuse a live block.
4. Instrument allocations and system calls around the callback. Reject callback reads, allocation, locks, unbounded loops or disposal.
5. Run a long logical asset larger than physical RAM through both decks with all eleven effects, Keylock, recording, analysis and search. Record fixed pool usage, reserve, all telemetry and callback deadlines. Avoid filling the device with a giant test file when a sparse deterministic native fixture suffices for boundary tests.
6. Repeat on the confirmed A10X iPad under memory pressure and real storage contention. Mac runtime results and sparse fixtures cannot establish physical-device continuity.

Do not label the streaming change complete until the combined production path and device acceptance pass. The parked gig iPad remains untouched.

## Proposed C declarations for integration

This is the proposed ABI for review before source edits. It separates the serial control producer, one worker per asset, and the single render consumer. Public structs use fixed-width integers. The production implementation keeps atomics and descriptor tables opaque.

The settled declarations are now in `Sources/CTDJTransport/include/TDJStreaming.h`; use that header for integration. The examples below retain design context. `tdj_command` also gained an atomic compound touch route: flag `TDJ_TOUCH_WITH_RATE` with `touch_rate`. A cold slice cannot apply a separate rate command to the old music. Same-region compound updates retain the current source position and Keylock state. Same pending-region updates retain the scheduled beat and change only the latched rate. A quantised compound touch preserves the old audible rate and Keylock state until the jump executes.

```c
#define TDJ_STREAM_BLOCK_FRAMES 8192u
#define TDJ_STREAM_BLOCK_COUNT 256u
#define TDJ_STREAM_MAX_RANGES 64u
#define TDJ_STREAM_MAX_TICKETS 16u
#define TDJ_STREAM_GLOBAL_PCM_BYTES (64ull * 1024ull * 1024ull)

typedef struct {
    uint64_t first;                 /* Inclusive source frame. */
    uint64_t end;                   /* Exclusive source frame. */
    uint32_t priority;              /* 0 mandatory; 1 optional warming. */
    uint32_t reserved;
} tdj_stream_range;

typedef struct {
    uint64_t request_id;            /* Producer serial; never reused. */
    uint64_t deck_generation;
    uint32_t count;
    uint32_t reserved;
    tdj_stream_range ranges[TDJ_STREAM_MAX_RANGES];
} tdj_stream_request;

typedef struct {
    double position;
    double source_speed;           /* Positive transport speed, 0.125..8 with Keylock. */
    double performance_rate;       /* Existing scratch/reverse/brake multiplier. */
    double loop_start;
    double loop_end;               /* <= start means no wrapping. */
    double continuing_position;
    uint32_t keylock;
    uint32_t reserve_continuing;    /* Mandatory Flux return region. */
} tdj_stream_target;

typedef struct {
    double output_rate;
    double forward_seconds;        /* Source travel; initial proposal 2.0. */
    double backward_seconds;       /* Source travel; initial proposal 1.0. */
    uint32_t max_output_frames;     /* Callback bound used for coverage planning. */
    uint32_t reserved;
} tdj_stream_config;

enum tdj_stream_status {
    TDJ_STREAM_INVALID = -1,
    TDJ_STREAM_IO_ERROR = -2,
    TDJ_STREAM_CAPACITY = -3,
    TDJ_STREAM_CANCELLED = -4,
    TDJ_STREAM_UNSUPPORTED_ATOMICS = -5,
    TDJ_STREAM_PENDING = 0,
    TDJ_STREAM_READY = 1
};

typedef struct {
    uint64_t resident_pcm_bytes;
    uint64_t global_reserved_pcm_bytes;
    uint64_t ready_table_serial;
    uint64_t source_read_misses;
    uint64_t missing_output_frames;
    uint64_t first_missing_output_frame;
    uint64_t latest_missing_source_frame;
    uint64_t low_reserve_callbacks;
    uint64_t rejected_cold_commands;
    uint64_t io_errors;
    uint64_t capacity_failures;
    uint64_t retirement_backpressure;
    uint64_t request_backpressure;
    uint64_t bytes_read;
    uint64_t max_service_nanoseconds;
    uint64_t minimum_forward_ready_frames;
} tdj_stream_telemetry;

/* Preparation/disposal queue, never the callback or MainActor. */
tdj_asset *tdj_asset_open_stream(const char *path, uint64_t frames,
    double source_rate, const tdj_stream_config *config, int32_t *error);

/* Serial control producer. Ticket 0 means allocation/enqueue failure. */
uint64_t tdj_asset_request_prepare(tdj_asset *, const tdj_stream_request *);
int32_t tdj_asset_prepare_status(const tdj_asset *, uint64_t ticket);
void tdj_asset_release_preparation(tdj_asset *, uint64_t ticket);

/* Pure planner: no live deck reads, I/O, publication or mutable DSP state. */
int32_t tdj_asset_plan_target(const tdj_asset *, const tdj_stream_target *,
    uint64_t request_id, uint64_t deck_generation, tdj_stream_request *);
int32_t tdj_asset_plan_minimum(const tdj_asset *, const tdj_stream_target *,
    uint64_t request_id, uint64_t deck_generation, tdj_stream_request *);

/* Exactly one serial preparation worker for each asset. */
int32_t tdj_asset_service(tdj_asset *, uint32_t maximum_blocks);
void tdj_asset_cancel_service(tdj_asset *);

/* Read-only atomics, safe for the serial control producer. */
void tdj_asset_stream_telemetry(const tdj_asset *, tdj_stream_telemetry *);
uint64_t tdj_stream_reserved_pcm_bytes(void);
```

`tdj_command` gains `uint64_t preparation_ticket`, `uint64_t preparation_ticket_b` and `uint64_t preparation_generation_b`. The first ticket belongs to the addressed deck, or deck A for global TEMPO. Its expected generation is the existing `command.generation`. The second ticket and generation belong to deck B for global TEMPO. Zero remains the default for existing callers. A supplied ticket must match its actual asset, request identity and real deck generation. Generation zero never bypasses validation.

For streamed LOAD, PLAY, SEEK, JUMP, LOOP, TOUCH, RATE, KEYLOCK and speed-changing GRID/SYNC/TEMPO, validate the proposed state's actual coverage on the render consumer. A nonzero ticket proves preparation when needed, but zero is accepted immediately when the current table already covers all required reads. Do not require asynchronous preparation for a warm 20 ms tempo or rate update. The renderer retains every existing musical-policy check. A ticket cannot override INVALID, STALE, PROTECTED, UNRESOLVED or KEYLOCK_RANGE.

Validate musical parameters and generation first. Build the proposed state in fixed local storage, plan the minimum immediate read coverage, and check its adopted cache table before committing any clock/deck/DSP change. Return the new command status `TDJ_SOURCE_COLD = 7` for a valid command whose necessary source region is missing. Map this to a distinct Swift `TransportError.sourceCold`, rather than INVALID. No state change or producer ticket claim occurs on that rejection. A global TEMPO command validates both proposed deck states and both supplied ticket generations, then applies once or rejects entirely. It never changes one deck's rate while leaving the other unchanged.

Separate minimum immediate coverage from the desired prefetch reserve. The fast path requires the exact next callback/Keylock/reset/transition reads and wrap/return obligations. A low optional forward reserve starts urgent preparation and telemetry but does not reject an otherwise safely covered continuous control change. Accepted cold-target preparations include the larger reserve before reporting READY. Both paths publish the updated desired ranges immediately. This distinction prevents an unnecessarily large prefetch policy from imposing control latency.

The main producer supplies tickets through prepared variants of the current Swift transport methods. After SOURCE_COLD, coalesce newer intent, request preparation off MainActor, and resubmit only the latest valid generation/action. The current music continues. A superseded pending touch-start must not run after its touch-end/cancel. Pause, Panic, contact cleanup and ordinary mixer/effect commands retain immediate routes. A release always clears contact ownership; an unexpected missing mandatory Flux return is a continuity failure with bounded emergency handling, rather than a stuck audition awaiting I/O.

Split the current Swift synchronous load into `reserveLoad` and `submitPreparedLoad`. Reserve a real monotonically increasing deck generation before planning. A cancelled reservation leaves a harmless gap. Open the asset, plan with that generation, await READY, then submit the exact reserved generation. Asset ownership moves into the transport's generation dictionary before submission and is removed on submission failure or the existing retirement message. In-memory `load` remains a convenience that reserves and submits immediately. Do not plan LOAD with generation zero and later replace its identity.

Swift's target planner starts from the current published snapshot: sample/output rate, source frame, source BPM, effective speed, Sync, Keylock, loop bounds, performance rate, Flux and continuing frame. The producer also retains its requested master BPM, free-rate intent and pending action values. GRID changes recompute effective speed from the proposed BPM; SYNC off preserves the current effective speed; TEMPO uses the proposed master BPM on both synced decks. Do not reconstruct the musical beat clock in Swift. C owns timed execution, exact proposed-state validation and the live pending target ranges. Extend the snapshot with free rate and pending jump/slice endpoint fields only if the Swift integration needs to display or conservatively plan them. They do not give Swift ownership of scheduling.

`tdj_asset_request_prepare` copies a fixed request into an unused ticket slot and publishes it with release ordering. It does not perform I/O. Each slot has a monotonically increasing identity and atomic producer/consumer reference bits. A ticket cannot be reused while either reference is held. A zero-reference slot is reclaimed by the worker before the producer can reserve it again. This prevents ABA reuse across delayed commands.

The producer holds its reference until the command's acknowledgement, cancellation before submission, or submission failure. On successful acceptance, the renderer claims its own reference before acknowledging. For a quantised jump or saved-loop recall, the renderer retains that reference until execution or cancellation, and publishes the pending target in every read-ahead request. After execution it releases the reference only after adopting a worker table whose acknowledged live-request serial includes the new state and whose actual coverage check succeeds. Publishing a live request alone is insufficient, because the worker might still be using the preceding request. The same handoff rule applies to immediate commands. Release on replacement, Panic and engine destruction is mandatory. A rejected command never claims the ticket. No extra completion message is needed for ticket lifetime. The producer must still poll the existing command acknowledgement before releasing its reference after submission.

Ticket lifetime cases are explicit:

| Event | Producer reference | Render reference |
| --- | --- | --- |
| Request cancelled before submission | Release immediately; asset remains retained until worker observes it. | None. |
| Command queue full | Release both supplied tickets immediately; preserve current music. | None, because the command was never enqueued. |
| Submitted command awaits acknowledgement | Retain both tickets and their assets. | May be claimed only by successful acceptance. |
| STALE, INVALID, SOURCE_COLD or other rejection | Release after the acknowledgement. | None. |
| Immediate command accepted | Release after acknowledgement. | Retain until worker/live-table handoff completes. |
| Quantised command accepted | Release after acknowledgement. | Retain through execution/cancellation and worker/live-table handoff. |
| Global TEMPO accepted | Retain both until the single acknowledgement, then release both. | Claim both atomically with acceptance; release each after its asset handoff. |
| Pending action replaced or Panic | Submitted producer reference still follows its acknowledgement. | Release obsolete claims after safe new/live coverage, or immediately when no source can render. |
| Engine destroyed | Stop output first; destroy engine before releasing unacknowledged producer tickets/assets. | Destructor releases every accepted claim. Queued commands never accepted have no render claim. |

The engine destructor does not free PCM. Swift releases any remaining producer references after it knows the sole render consumer has stopped, then the disposal queue joins workers and destroys the retained assets. For global TEMPO sharing one asset across both decks, the two tickets can differ by generation. If they are the same ticket identity, claim/release once per unique ticket rather than using a single reference bit as an accidental reference count.

READY means that the worker has published a table containing that ticket's mandatory ranges. Unconsumed referenced tickets contribute their required ranges while their union fits with live demand. A later live request can revoke a producer-only reservation with explicit CAPACITY. Cancelled or superseded producer tickets relinquish their references. Optional cue warming can be omitted without failing mandatory coverage.

An accepted-command ticket is single-use. Both decks may share the same identity within one global command because validation of both decks precedes consumption. A later source-validating command using that identity returns STALE. `prepare_status` reports INVALID after acceptance. Producer release after acknowledgement is still required to reclaim ticket identity storage. Native claims keep their existing lifetime through pending execution and table adoption, but their old ranges stop contributing once the worker receives the live publication generated by acceptance. That publication includes current, pending and Flux requirements. Thus delayed MainActor acknowledgement collection cannot pin obsolete PCM ranges. A held producer reference never permits identity reuse before release.

At each callback boundary, before applying source-changing commands, the renderer adopts any pending table for every unique active or queued-load asset. This includes an asset not yet installed in a deck. A READY ticket therefore cannot require an otherwise unloaded asset to render before LOAD can succeed. Table adoption and retirement are C operations with fixed bounds. The worker can have at most one published successor table. If the consumer cannot retire its current table, it leaves that successor pending, and coverage checks can reject/defer the new command. READY alone never bypasses the actual coverage check.

## Render requests and shared assets

The internal render-side functions are not Swift APIs:

```c
void tdj_stream_render_begin(tdj_asset *, uint64_t output_frame);
bool tdj_stream_render_read_stereo(tdj_asset *, uint64_t frame,
    float *left, float *right);
void tdj_stream_render_request(tdj_asset *, const tdj_stream_request *);
void tdj_stream_render_end(tdj_asset *, uint64_t missing_output_frames);
```

The engine collects both decks' requirements before publishing an asset request. If both decks use the same asset, publish one union containing both live positions, loops, pending targets and Flux positions. Never let the second deck overwrite the first deck's request. An asset can belong to only one engine's serial render consumer at a time. A second engine must open its own streamed asset and pool. Reject cross-engine attachment explicitly. Loading the same asset into both decks in one engine remains supported.

The render request mailbox uses three fixed slots with atomic ownership states, rather than a retrying seqlock. The consumer publishes into a free slot and can supersede an unclaimed older request. The worker claims a slot before copying it, so its payload cannot change during the copy. If no slot is free, increment a request-backpressure counter and retain the previous mandatory cache table. Neither side spins. A worker service pass coalesces to the newest complete request, then fills at most `maximum_blocks` blocks before returning. Four blocks is the initial Swift service-call budget. The worker must recheck cancellation and new urgent requests between block reads.

Swift runs service calls on a dedicated serial user-initiated queue. It starts the worker after opening the asset and submits the initial target request before LOAD. Service passes continue while the asset has producer, engine or retirement ownership. A short cancellable timer or worker notification schedules another pass. Do not dispatch a Swift task or signal a blocking primitive from the callback. Immediate work should be scheduled by the producer for cold commands. Routine prefetch can poll at a measured bounded interval, initially 5 ms. Actual cadence and low-water marks need device measurement.

For `tdj_asset_service`, READY means this pass has no immediate worker progress to make. It may be waiting for the render consumer to adopt a table, or all requested data may already be ready. PENDING means more fill work remains after the finite `maximum_blocks` budget. Negative statuses report cancellation, invalid service use, capacity failure or I/O failure. READY is not a substitute for querying an individual ticket. A zero block budget is INVALID. Requeue PENDING work promptly on the same worker, allowing cancellation and higher-priority requests between passes. Use the measured polling interval for quiescent or publication-blocked passes, rather than spinning.

The planner uses immutable Keylock configuration values captured at asset construction. The render-side planner also incorporates the live Keylock cursor/remainder and pending speed transition. Both call the same range helper. The control-side target plan conservatively covers reset/prime and the possible speed-transition history, so it does not read mutable vendor state. Instrumented range tests must prove that every actual read is covered. Do not expose mutable vendor internals to Swift.

## Global budget, service faults and atomic requirements

Reserve exactly 32 MiB from a process-wide atomic budget before allocating each pool. Use checked compare/exchange on the preparation queue. A cancelled load, failed submission, replaced deck or retired asset keeps its reservation until its worker stops and all buffers are freed. No temporary decode buffer, staging allocation or replacement pool may borrow outside that budget. The decoder's existing fixed scratch buffer is accounted separately. If four reservations remain live, a fifth open returns CAPACITY promptly and current audio continues. Swift retries only after disposal returns capacity, or reports that preparation cannot proceed. It must not evict an active asset to create capacity.

`tdj_asset_cancel_service` sets an atomic cancellation flag. The worker owns all I/O and observes cancellation between finite reads. The disposal queue awaits the Swift worker task before calling `tdj_asset_destroy`. The asset destructor closes the file and releases its budget reservation. It is legal only after all producer tickets have been released and every engine generation using the asset has retired. Retain the Swift asset until these conditions hold. No callback can destroy an asset or a table.

For deterministic tests, provide a test-only constructor or configuration hook before the worker starts:

```c
typedef struct {
    uint32_t delay_microseconds_per_read; /* Bounded to <= 1,000,000. */
    uint32_t maximum_bytes_per_read;      /* 0 means normal block read. */
    uint64_t fail_after_bytes;            /* UINT64_MAX means no injected error. */
} tdj_stream_test_io;
int32_t tdj_asset_set_test_io(tdj_asset *, const tdj_stream_test_io *);
```

This hook rejects changes after service starts. Delays and injected short reads occur only on the worker. A short read loops in bounded chunks until the requested valid file range is complete, EOF occurs, cancellation arrives, or an injected/real error occurs. EOF inside the validated PCM length is an error, not valid silence. A finite stall lets tests verify reserve recovery; a stall exceeding the reserve must increment continuity-failure telemetry. Never hide that failure by asserting only finite output.

All atomic integer, pointer and ownership types used by the callback must pass `atomic_is_lock_free` at construction. Fail streamed asset creation with UNSUPPORTED_ATOMICS if any callback primitive falls back to a library lock. Use acquire/release ownership publication and relaxed counters where no payload depends on the counter. No CAS retry loop, atomic reference-count destructor, file operation, heap operation, Objective-C call or Swift closure runs in the callback. Test the compiled callback path, not only source patterns.

Validate every range before publication: `first < end <= asset.frames`, count at most 64, priority exactly mandatory or optional, and checked byte offsets representable by `off_t`. Validate finite target/config values and the existing supported audio-rate and musical-speed constraints before using them in integer conversions. A replaced or truncated PCM file is an I/O failure. The asset opens the private immutable cache generation, rather than reopening a mutable path on each service pass.

Prefilled anonymous memory also remains subject to host memory management. The fixed pool bounds pressure and removes file-backed source faults from the read path. It does not prove that the OS can never compress, reclaim or fault a page. Physical-device stress and measured resident behaviour remain required. Do not infer a page-lock guarantee from allocation or prefilling, and do not add an untested `mlock` assumption.

## Native implementation evidence

`Scripts/check-streaming-native.sh` compares the streamed path with the existing immutable in-memory renderer. `Validation/streaming-native-tests.log` records exact sample equality while reading 51,533,824 bytes through one 16 MiB pool. Coverage includes continuous block crossings, fractional-speed Keylock, cold compound reverse rejection, Flux return including continuation beyond EOF, quantised ticket lifetime, same-region rate updates, a tiny boundary loop, reverse, two decks sharing one asset, and rejection of a second engine using that asset.

The suite also covers service before any request, changing a 230-block target before attaching a renderer, the global 64 MiB budget, cancelled assets retaining their reservation, short reads, injected I/O errors, worker cancellation, concurrent table publication/retirement, and deliberately exhausted-cache telemetry. A finite one-second worker delay does not hold the audio callback. These are native Mac tests, not a physical storage or iPad acceptance result.

`Validation/streaming-native-address-undefined.log` records the address/undefined-behaviour sanitizer run. The thread-sanitizer result is retained separately in `Validation/streaming-native-thread.log`. Native build inputs and binary hashes are stored under `.cache/streaming-native/<variant>/`. `Validation/streaming-inmemory-keylock-regression.log` retains the earlier renderer's allocation/timing check, including zero C++ allocations during render.

An initial starvation-test assertion expected the first missing frame at the next block's first sample. The interpolator reads its neighbour one sample earlier. `Validation/streaming-starvation-neighbour-assertion.log` retains that failed assertion; the corrected trial checks frame 8,191 and still requires explicit miss counters. It does not change the renderer to hide the missing read.

Unattached preparation uses an atomic worker ownership marker before retiring an unused table. A concurrent LOAD receives SOURCE_COLD and can retry, rather than reading a mutable worker table. No work means no empty table publication. Active-render table adoption also checks minimum next-read coverage before replacing the current view. This prevents a worker table prepared before a warm zero-ticket action from discarding the newly accepted source region.

The telemetry field `resident_pcm_bytes` reports the allocated, prefilled pool size. It is not an OS residency measurement. Any source-read miss, missing output frame, render failure, dropped recording frame or emergency substitution must fail combined continuity acceptance.

Integration regressions added two further guarantees. Releasing an inactive touch after a cold begin was rejected does not reset live Keylock or retire an unrelated pending jump claim. A pending unbounded touch over an active slice prepares the underlying loop that will actually own wrapping after execution. The native suite compares the cancelled cold gesture against a reference that receives no gesture.

Live render requests now distinguish mandatory minimum reads from optional forward/backward prefetch. `tdj_asset_plan_minimum` exposes the same minimum planner to Swift. Initial LOAD can retain full-reserve preparation through `plan_target`; cold performance controls can combine mandatory minimum ranges with optional desired ranges. A 384 kHz dual-region Flux trial proves that optional reserve pressure does not stop the worker. An 8× preparation trial proves that minimum reads can become ready when two full mandatory reserves exceed the fixed pool.

Live request identities increase on every asset publication, including zero-frame control calls. They do not derive from the audio output frame. This prevents stale idle requests from replacing newer intent and prevents immediate prepared commands from releasing their tickets against a table published before that command. The zero-frame SEEK regression checks retention until the worker table is actually adopted.

`TDJ_CUE_RECALL` atomically combines a stopped-deck point/loop recall with start. A cold jump can no longer leave a following Play command to start the old position. The existing Play start checks and scheduler are shared with the composite command. Eight native comparisons cover point/loop, ready/paused, native first tempo, manually selected tempo and an incoming synced bar wait. Cold recall leaves the other deck's audio, target source position and clock unchanged. Playing-deck recalls keep their existing jump/loop route. Ended saved-loop recalls now use the same atomic start route and reset their continuing timeline to the recalled cue. Cold validation remains inert.

The source-bound native results including atomic cue recall are archived in `Validation/StreamingNative-2026-10-28-02/manifest.json`. Normal, address/undefined-behaviour and thread-sanitizer variants pass. The earlier `StreamingNative-2026-10-28-01` archive retains the preceding streaming baseline and queued-Play cancellation evidence.

The subsequent cooperative reader fix is archived in `Validation/StreamingNative-2026-10-28-03/manifest.json`. Before the fix, cancelling an active asset's cold preparation allowed another 983,040 bytes to be read over 382.810 ms in a controlled 20 ms/block trial. After the fix, the same probe read one additional 65,536-byte block and returned in 19.716 ms. This probe measured worker responsiveness, not an audio deadline failure.

After each block read, the worker now checks whether a live request arrived or the set of referenced tickets changed. It finishes describing already cached data without further I/O, then lets the next pass coalesce current priorities. Permanent native tests cover both ticket cancellation and a new live render request. Each permits at most one in-flight block plus a race margin, and requires zero source misses. Normal, address/undefined-behaviour and thread-sanitizer variants pass with matching current source and binary hashes. No callback or public ABI changed.

## First combined production check

`Validation/SwiftRuntime-2026-10-28-StreamedEleven60s01/result.json` passes the first 60-second combined Mac run. Both decks used the streamed production path and 33,554,432 allocated PCM bytes. The run measured 5,626 callbacks, no output deadline overruns, timestamp gaps, render failures, source-read misses, I/O errors, missing output frames or recording drops. All 2,880,000 captured recording frames reached the file. The maximum callback work was 5.482 ms against its 10.667 ms audio period.

All eleven effects ran with 3,000 control batches, 343 background analyses and 816 searches over 5,000 metadata tracks. Control updates had no measured deadline misses. Two cold preparations completed without errors while current audio continued. This check does not measure SwiftUI frame pacing, physical storage pressure or the target A10X iPad. A longer sequential read-ahead trial and the full regression remain separate checks.

## Host callback bounds and future Flux capacity

`tdj_engine_configure_maximum_output_frames` sets the actual source-node callback bound while output is stopped. It accepts 1–65,536 frames and acquires the render guard once. A busy renderer returns `TDJ_PROTECTED` without waiting. An unsafe bound returns `TDJ_SOURCE_CAPACITY` before changing the engine or attached assets. Zero internal override preserves native callers’ per-asset configuration. A successful override updates attached assets and applies to newly attached LOAD assets before coverage validation. Worker planning reads one atomic bound for each complete request. No PCM pool allocation changes.

Flux continuation always plans native performance rate 1, including Keylock history and priming lookahead. It follows the linear track rather than audible loop wrapping. A proposed control also checks the bounded future working set of the current and pending trajectories across both decks sharing an asset. Divergent paths that cannot fit the 240 published blocks return terminal `TDJ_SOURCE_CAPACITY` before changing playback. Short loops, clipping at file boundaries and equal unbounded normal-rate trajectories retain their bounded coverage. This check uses fixed local arrays and arithmetic. It performs no file operations, allocation, waits or track-length enumeration.

The batch05 pool limits were 16 MiB per asset and 64 MiB globally; batch06 supersedes these with 32/128 MiB to guarantee immutable-table staging. The native tests cover 8,917- and 16,384-frame host requests, changed attached bounds, coherent concurrent planning, protected second-engine ownership, minimum-only Flux returns and future path divergence. These are Mac tests. The source-node integration and physical A10X acceptance remain separate checks.

An output-stopped bound update changes planning geometry but does not fetch the larger window. Before restarting output with loaded assets, the controller must prepare and adopt the complete new-bound current and pending minimum windows. `Validation/HostBoundResumeCoverage-2026-10-28-01/manifest.json` records the failure and positive control: a 4,096-to-16,384 change at 8× tempo and raw rate 4 produces 12,184 missing frames without preflight, and zero after completed preparation/adoption. The configuration API remains allocation-free and does not perform I/O.

Initial cache construction also needs the configured host bound before preparing LOAD. A full two-second reserve alone does not prove this coverage: the planner takes the larger of reserve and travel/lookahead. `Validation/InitialHostBoundCoverage-2026-10-28-01/manifest.json` records 48 kHz/8×/Keylock LOAD returning SOURCE_COLD with an old 4,096-frame constructor at both 8,917 and 16,384 host frames. Using the configured 16,384-frame constructor accepts the first LOAD. Repreparing after the native LOAD updates the asset bound also succeeds.

The Swift startup integration now passes the prepared source-node maximum through PCMCache and PCMAsset before initial preparation. A cold LOAD caused by a route change during decoding is prepared again with the updated native bound, with at most two retries. The existing native retirement message releases a failed LOAD generation; a shared or currently playing generation remains retained. A redundant Swift cleanup added during the startup review was removed after confirming that native path.

For an already active stopped-output source, PlaybackController holds engine start until asynchronous source preparation completes. OutputSourcePreparation combines both decks by asset identity, includes pending positions and Flux continuation, and retains tickets through zero-frame adoption. Zero-frame control draining also runs while waiting, so bounded staging tables can progress without a nonzero audio callback. Source geometry, generation and configured bound are checked again before starting. Mixer, filter, crossfader, gain and FX changes do not trigger unnecessary preparation. Stop, route changes, interruptions and controller destruction cancel pending startup. No previously captured Play command is replayed after preparation.

`Validation/output-start-final-focused.log` covers first Keylock LOAD at 8,917/16,384 frames, resumed 8× tempo/raw-rate-4 output at both bounds, both decks sharing one fixed pool, and rejected-load lifetime cleanup. These are controlled Mac checks, not physical A10X acceptance. The initially stalled helper check, before adding zero-frame progress while waiting, remains in `output-start-preflight-stalled-before-adoption-pump.log`.


## Native handoff correction, 29 October 2026

The retained pre-fix probe demonstrates two independent failures: a completed producer ticket pinned obsolete ranges after native handoff, and the 256-block pool could not stage the next 129-block minimum while an old 141-block table remained in use. The correction uses serial-marked native ticket consumption, 512 physical blocks with the unchanged 240-block working-set limit, and worker withdrawal of incomplete or obsolete pending candidates. Audio callback sample reads and table adoption remain unchanged; all reads and preparation remain on the worker. There is no MainActor acknowledgement deadline for PCM safety.

`Scripts/streaming-handoff-check.h` permanently covers delayed acknowledgement collection at 512/16384/30000 output frames, minimum/full preparation, and optional-filled 240-block initial tables. Worker service between real callbacks has no zero-frame adoption calls. It also checks late release, shared global-command consumption, explicit single-use rejection and READY reservation revocation after a host-bound increase. The preserved pre-fix archive remains authoritative evidence of the original failures. Native batch06 records all 20 handoff cases in normal/address-undefined builds, with 16 original plus 4 near-full cases in thread-sanitized builds. All report zero source/output misses. Both native suites pass all three build variants. The synthetic allocation/timing probe reports zero render allocations and deadline overruns; the 30-musical-second stress accepts 24,752 commands with no audio, clock, queue or deadline failure. Integration runtime results must be recorded separately; these Mac checks do not establish target-device or 1:1 musical fidelity.


## Output-start coverage check, 29 October 2026

`tdj_engine_output_sources_ready` runs only while device output is stopped. One attempt to acquire the render guard returns PROTECTED if the consumer owns it. For each playing or queued streamed deck, the query plans the minimum current, pending and Flux ranges with the configured host bound and checks the CURRENT immutable audio table. It returns OK only when all those ranges are present, or SOURCE_COLD otherwise. A null engine returns INVALID. In-memory, ready, paused and ended decks need no check here; their next source action retains normal validation.

The query does not adopt a pending table, publish a request, collect acknowledgements, advance a clock, reset DSP, change deck state or increment source telemetry. It allocates nothing and performs no file reads or waiting. Worker publication can no longer be mistaken for adoption: a ticket can be READY while this query remains COLD. The output-start helper retains preparations, continues worker/zero-frame progress, rechecks source geometry and the configured bound, then requires this actual-coverage result immediately before starting the device engine. Worker reclamation never changes the current table, so worker activity cannot invalidate an OK result before a subsequent consumer operation.

Native tests cover cold coverage after raising the host bound, READY publication before adoption, OK after zero-frame adoption, unchanged snapshots and table acknowledgements across repeated queries, inactive/native-first deck exclusion, shared active decks, pending touch/Flux ranges, and a single protected guard attempt during concurrent rendering. The source-bound batch07 record is separate from the preceding batch06 handoff correction.


Batch07 also reproduces the stopped-output shared-asset gap with active A and distant inactive B. In both READY and PAUSED B cases, A's ticket becomes READY after 96 one-block worker passes, but the rejected candidate needs nine more passes before actual adoption makes the active-source query return OK. Both variants pass normal, address/undefined and thread-sanitized builds with zero source/output misses. Repeated same-geometry zero-frame publications continue progress in this fixture. The current reclaim policy is retained; no serial-policy change was needed for this result.
