# Humanising DJ mixing in real time

Strategy for GenErik DJ, 11 November 2026. Runtime observations refer to the R162 review source at `c6776a6`.

## Musical purpose

Let a record retain its character while the DJ creates a coherent performance with another record. Preserve expressive timing, clear attacks, bass weight and space. Help the DJ control tension, release and musical direction.

The first use case is a drifting Norwegian disco remix mixed into a steady modern remix. Solo playback retains the original push and pull. Starting the second deck engages gradual alignment towards shared bar boundaries. The DJ still chooses the entry, blend, bass handover and exit.

A successful blend should require fewer corrective nudges without sounding rigid, blurred or unstable. It should remain easy to interrupt, extend or reshape by touch.

No mixer can make every pairing work. Conflicting arrangements, harmonies and rhythms can require another entry point, a shorter transition or another record.

## Decisions and scope

Erik has selected these timing requirements:

- Starting the second deck triggers alignment. Loading a track does not.
- Headphone preparation counts once the second deck starts, even before the audience hears it.
- The interval choices mean 4, 8, 16 or 32 beats. The first version uses four beats.
- Solo adaptive playback uses a constant playback rate and retains the source timing variation.
- Automatic correction must preserve continuous source position and the saved Sync choice.
- Explicit Sync off remains off until the DJ changes it.

The first timing scope assumes a usable accepted adaptive map and four-beat metre. Free metre and uncertain downbeats cannot support a trusted one-bar lock.

The spectral, dynamics and colour strategies below are proposals. They do not authorise automatic EQ, stem removal or a change to the existing touch layout. Each runtime change needs a focused request and its own acceptance evidence.

The [R162 implementation plan](groove-sync-r162.md) owns the current timing contract. The [project direction](../product-direction.md) and [A10X acceptance gates](release-gates.md) remain authoritative.

## What human groove means

Human groove includes relationships between notes, accents, articulation and silence. It also includes changes across a phrase. A late snare can feel relaxed while an early bass note creates forward motion.

Groove does not require loose timing. Witek and colleagues found the strongest movement and pleasure ratings at intermediate syncopation in their drum-break experiment. This supports preserving rhythmic structure. It does not establish an ideal timing offset for a DJ blend. [Study and limits](https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0094446).

Our design principle is to preserve the performance already in the recording. Random timing changes, artificial wow and a universal swing amount are outside the first scope.

Treat timing at four scales:

| Scale | Musical question | Proposed treatment |
| --- | --- | --- |
| Phrase | Do the entry, build and release make musical sense? | Give the DJ useful landmarks and room to choose. |
| Bar | Do the records share a dependable reference? | Use accepted downbeats for bounded correction. |
| Beat and subdivision | Do the kick, snare and hats retain their relationships? | Preserve internal timing where correction permits. |
| Waveform cycle | Do related audio paths reinforce or cancel? | Verify processing latency and phase separately from grid alignment. |

A whole-record speed change also changes internal timing in output seconds. Bar alignment reduces the number of timing targets. It cannot guarantee that every expressive detail remains unchanged.

## Existing approaches and the proposed distinction

Real-time musical assistance already exists. Algoriddim documents Fluid Beatgrid, real-time separation and Crossfader Fusion transition processing in djay Pro 5. [Official announcement](https://www.algoriddim.com/press_releases/447-algoriddim-unveils-djay-pro-5-with-next-generation-neural-mix-crossfader-fusion-and-fluid-beatgrid-).

Ableton Live supports groove extraction, adjustable quantisation and real-time groove parameters for warped audio. These features establish relevant prior approaches, although Live has a different performance workflow. [Ableton groove manual](https://www.ableton.com/en/manual/using-grooves/).

GenErik DJ should test a specific combination: natural solo timing, second-deck bar alignment, predictable mixer behaviour and optional assistance under direct touch control. Its value must come from audible results and reduced effort. The project has not established a first-in-market claim or comparative superiority.

## Current foundation and gaps

| Area | Current review source | Remaining gap |
| --- | --- | --- |
| Adaptive timing | R162 holds solo rate and steers towards shared bars without automatic cursor jumps. | Real-remix feel, correction audibility and A10X acceptance remain open. |
| Timing evidence | Accepted adaptive maps supply source bar positions. | Wrong downbeats and sparse material still need review. |
| Controls | Mixer changes use 5 ms ramps. | Ramps alone do not establish a musical fader or filter response. |
| Crossfader | Both assigned decks have unity gain at the centre. Default master gain is 0.5. | Verify headroom with gain, EQ, effects and overlapping attacks. |
| EQ | Complementary one-pole bands split at 250 Hz and 2.5 kHz. Neutral settings reconstruct the dry signal. | Compare useful separation, phase response and feel against the reference. |
| Keylock | The current spectral processor has explicit timing and output contracts. | Transient shape, stereo image and rate automation need real-music listening. |
| Effects | Existing processing preserves released tails through bounded transitions. | Check dense blends, feedback and gain interaction on the device. |
| Master output | The inspected transport output sums sources and applies master gain. | No true-peak limiter appears in that path. Verify the complete device route. |
| Recommendations | Existing ranking uses key, tempo, broad energy and previous pairings. | It does not establish phrase, spectral or perceptual compatibility. |

Source references: [mixer](../../Replica/Mixer.md), [native mixer](../../Replica/Sources/CTDJTransport/TDJMixer.h), [transport](../../Replica/Sources/CTDJTransport/TDJTransport.c), [keylock](../../Replica/Keylock.md), [effects](../../Replica/Effects.md) and [recommendations](../../Replica/Sources/TDJCore/PerformerSuggestions.swift).

R162 passed 36 focused Swift tests, 13 native scenarios and the map-publication check. These establish synthetic behaviour on the recorded source. Musical feel and sustained A10X performance remain unverified. [Results](../testing/groove-sync-r162-results.json).

## Strategy for timing and shared pulse

### Use gradual bar alignment as the baseline

The engine should guide a drifting record towards a shared musical reference without resetting audible playback at each bar. Keep the accepted source map intact.

| Approach | Benefit | Cost or failure mode | Decision |
| --- | --- | --- | --- |
| Continuous beat correction | Tight beat alignment | Can suppress local timing and expose stretch artefacts. | Keep as a comparison baseline. |
| Hard reset at each bar | Exact boundary placement | Can cut audio, duplicate attacks or create a discontinuity. | Reject for automatic audible correction. |
| Gradual bar alignment | Fewer correction targets and continuous playback | Speed changes can still become audible. | Validate the R162 baseline first. |
| Alignment every 8, 16 or 32 beats | More room for natural movement | Larger separation can develop between checkpoints. | Evaluate after one-bar acceptance. |

R162 permits extra rate correction up to 6% of nominal. Automatic slew is at most six percentage points of nominal per second. These engineering defaults need listening review. They are not established perceptual limits.

Compare the current controller against smoother correction envelopes only if listening exposes a problem. A candidate could reduce rapid changes in acceleration. Another could use an error band to avoid unnecessary correction. Both must retain target identity, deadlines and visible unresolved alignment.

Do not assume corrections belong only between attacks. Dense percussion can leave no suitable gap. Moving correction elsewhere can disturb vocals or sustained notes. Any transient-aware policy needs comparison against the simpler controller.

### Separate source character from timing uncertainty

Preparation should distinguish gradual tempo drift, recurring expressive offsets and uncertain beat detection. An apparent late kick might be intentional timing, a pickup or an incorrect grid.

Store confidence separately for beat position, downbeat position and local tempo continuity. A confident tempo estimate does not establish the first beat of a bar. Preserve manual corrections and keep uncertain sections visible.

Sparse material such as Dune's *In the End* must test this distinction. Stronger correction cannot repair the wrong timing reference. When evidence fails, retain continuous playback and report unresolved alignment.

### Keep one clock authority

Starting a blend must not make two drifting decks chase each other. Retain one master tempo and a defined bar reference throughout acquisition.

Preserve the outgoing source position and incoming pickup. R162 can establish bar phase from the solo record when no other clock-dependent performance prevents it. An active Pattern Player or Loop Recorder retains the existing clock phase.

When the blend ends, retain the current source rate for solo playback. Avoid an automatic speed step. Deliberate master-tempo changes still apply.

Scratch, braking, loops, seeks and gesture releases retain their existing contracts. Rebuild the correction target after an explicit discontinuity. Never interpret a deliberate performance gesture as an error that needs stronger correction.

## Strategy for attacks and headroom

Two kicks can align rhythmically yet sound like a double hit because their attack shapes differ. They can also reinforce strongly. Peak alignment alone is therefore an incomplete objective.

First measure the clean mixer with fixed controls. Include coherent copies, unrelated tracks, sustained bass, resonant filters and effect returns. Record the level before and after summation, master gain and output conversion.

The default master gain provides some attenuation. It does not establish sufficient headroom for boosted channels, EQ, feedback or more decks. Allen & Heath also treats headroom as necessary for clean analogue mixing. [Xone operating levels](https://support.allen-heath.com/hc/en-gb/articles/43053562464017-Xone-96-User-Guide).

Compare crossfader responses at matched levels. Equal-power curves can maintain average power for unrelated signals, while coherent signals can still peak higher. Linear curves can produce a perceived dip. Retain predictable touch behaviour and measure the chosen response. Avoid a hidden curve that changes with the music.

Prefer stable preparation gain over live loudness chasing. A quiet breakdown should remain quiet unless the DJ changes it. Preserve crest factor, the difference between peak and average level.

Assess a final safety limiter only after measuring the complete output path. It should catch occasional excess without becoming the normal source of loudness. Required attenuation, attack damage, pumping, latency and CPU cost must all enter the decision.

True-peak measurements belong in this assessment because reconstructed peaks can exceed individual sample values. [FabFilter metering explanation](https://www.fabfilter.com/help/pro-l/using/metering).

No system can preserve arbitrary overlapping peaks at a fixed ceiling without attenuation or a change to the signal. Define the overload behaviour explicitly.

## Strategy for phase and stereo coherence

Grid phase describes position within a beat or bar. Waveform phase describes position within an audio cycle. Correcting one does not establish the other.

Two identical, equal-level 50 Hz tones cancel when separated by half a cycle, or 10 ms. Different frequencies have different periods. A single delay cannot align every component of two changing records. [Phase and time relationships](https://www.izotope.com/community/blog/5-ways-to-adjust-phase-after-recording).

The engineering priority is coherence between related paths: dry and processed audio, parallel effects, duplicated sources and recombined stems. Measure latency and alignment through bypasses, keylock changes and rate transitions.

For unrelated songs, reject continuous global waveform alignment as the default. Test small manual nudges where low-end interaction sounds poor. Do not automatically invert polarity or force stereo material to mono based on a momentary reading.

Check both stereo and mono listening. Record low-band cancellation, centre stability and deliberate stereo effects. A negative correlation reading can describe an intended effect. It cannot independently decide whether the mix sounds wrong.

The app can preserve its output integrity. Room acoustics, subwoofer alignment and the venue system remain outside its correction scope.

## Strategy for bass and frequency space

Give the DJ a clear way to decide which record leads the low end. A common transition keeps the outgoing kick and bass while the incoming percussion enters. The DJ then exchanges bass roles at a chosen phrase boundary.

This is a useful starting technique, not a rule for every blend. Two complementary bass parts can work together. Two conflicting vocals can fail even with clean bass.

Masking occurs when competing content makes a part harder to hear. Cancellation is a different mechanism. A spectrum overlap alone cannot distinguish either problem from an intentional layer.

Compare assistance strategies in this order:

| Strategy | DJ benefit | Main risk | Proposed scope |
| --- | --- | --- | --- |
| Better EQ response and cue monitoring | Clear, direct control of space | Poor band choices can remove wanted body. | First mixer investigation. |
| Prepared bass handover controlled by the DJ | Repeatable transition with fewer simultaneous moves | A fixed curve can create a hole or alter the phrase. | Optional prototype after the clean mixer audit. |
| Bounded dynamic EQ in a selected low band | Can make room only during overlap | Pumping, colour changes and uncertain conflict detection | Later comparison with manual EQ. |
| Stem-based handover | More selective control of kick, bass or vocals | Separation artefacts, latency and device cost | Deferred until the two-deck baseline holds. |

Production techniques such as selective EQ and band-limited ducking offer useful precedents. Applying them between mastered DJ records is a project hypothesis. [Kick and bass techniques](https://www.izotope.com/community/blog/how-to-mix-kick-and-bass).

Any prototype must use the actual blend context. Consider channel level, crossfader assignment, EQ, active effects and cue routing. A cued deck can trigger timing alignment under Erik's chosen policy. It must not trigger spectral attenuation of the audience's solo record.

Bound attenuation depth, band range and recovery time. Avoid automatic boosts. If confidence becomes inadequate, return smoothly to the DJ's settings without chasing changing measurements.

## Strategy for phrases harmony and energy

Help the DJ recognise useful entries, pickups, breakdowns, builds and exits. Keep uncertain landmarks distinct from accepted cues. Do not silently move a launch to a guessed phrase boundary.

Describe specific opportunities: a sparse entry, a vocal-free overlap or a bass handover after a fill. A single compatibility score hides the reason and can encourage poor choices.

Key compatibility is useful guidance. It cannot establish that the current chords, melodies or vocals work together. Evaluate the actual overlap and the DJ's intended energy change.

Do not automatically flatten a build, raise a breakdown or remove a competing hook. Musical tension can be deliberate. Assistance must follow an explicit performance choice.

Preserve the existing recommendation order unless Erik requests a change. New phrase and overlap evidence should first appear in research comparisons or an existing review surface.

## Strategy for warmth and character

Define warmth through listening outcomes: body without mud, controlled harshness, stable bass and retained attack. Several clean engineering choices can support these outcomes before colour processing.

Keep a neutral path as the reference. Compare fader curves, EQ and filters against TDJ1 at matched levels before designing another sound.

An optional colour processor could add gentle harmonics. Compare channel colour before summation with bus colour after summation. The bus version reacts to both records together and can change their dynamic interaction.

Every candidate needs bypass, level compensation, bounded drive and stereo checks. Measure aliasing, latency and A10X cost. Retain a candidate only when repeated listening supports its benefit.

Exclude automatic wow, random drift, noise and routine bus saturation from the baseline. Already mastered records can lose clarity when further processing changes their attacks or low end.

## DJ control and assistance contracts

Timing alignment and tonal assistance need separate enable states. Starting the second deck authorises the selected Sync behaviour. It does not authorise EQ changes or stem removal.

| Control concern | Required contract |
| --- | --- |
| Manual touch | A touched parameter belongs to the DJ. Suspend automation for that parameter until explicit rearming or the next defined transition. |
| Saved settings | Preserve saved Sync, EQ, filter and colour choices. Keep transient assistance offsets separate from base settings. |
| Assistance amount | Show a small, understandable amount and state through an existing control surface. Avoid another permanent dashboard. |
| Missing evidence | Report unresolved timing. Fade optional tonal offsets back to zero when safe to do so. |
| Cancellation | Remove optional processing offsets through bounded ramps. Preserve playback, source position and the DJ's base values. |
| Loop and effects performance | Respect deliberate changes, retained tails and clock ownership. |
| Recording | Capture the intended audible master, including enabled assistance. Preserve enough session data to explain the processing. |

Rearming behaviour is a proposed contract that needs interaction review before implementation. Manual control must never silently return to automation during the same gesture.

## Architecture and real time limits

Use existing module boundaries. Keep analysis and decisions outside views and view controllers. Pass small typed dependencies so focused tests can use fakes.

| Boundary | Responsibility | Published information |
| --- | --- | --- |
| Preparation in `TDJCore` | Analyse local timing, structure and broad spectral features outside live deadlines. | Versioned features, source identity, accepted edits and separate confidence fields. |
| Performance planning in `TDJCore` | Combine DJ intent, accepted timing and current blend context. | Bounded targets, selected clock reference and assistance state. |
| Native `CTDJTransport` | Render samples, apply ramps and enforce limits. | Applied values, alignment error, limit state and bounded diagnostics. |
| `TDJInterface` | Display state and collect direct touch. | Explicit control intent and parameter ownership. |
| Evidence records | Bind tests and listening to source and settings. | Commit, build, tracks, preparation, route, measurements and DJ result. |

Start from existing snapshots and command paths. Agree units, parameter ownership and invalidation rules before introducing new contracts. Do not create a second timing authority in another module.

Keep full-track analysis, model inference and large spectral comparisons outside the audio callback. The callback must not allocate, read files, take locks or wait for workers.

Use preallocated state and bounded processing. Reject stale results after load, seek, map replacement or source changes. Optional work must yield or cancel before it threatens audio or touch.

Retain existing callback and control deadlines. A feature that needs larger buffers or relaxed deadlines has not met the current target. Measure on the 2017 A10X iPad Pro with the actual output route.

## Shared research workstreams

These workstreams divide the questions for the agents already involved. They do not assign ownership or start another implementation chat. Keep runtime edits serial and coordinate shared files before integration.

| Workstream | Decision to resolve | Required output | Dependency |
| --- | --- | --- | --- |
| Timing and analysis | Which map and correction policy retain feel while controlling drift? | Labelled timing examples, controller comparisons and failure cases. | Accepted grid and clock contract. |
| Mixer and dynamics | What gain, fader and EQ behaviour preserves punch through a blend? | Response measurements and matched-level listening renders. | Fixed source, preparation and route. |
| Phase and keylock | Which processing paths change attacks or stereo relationships? | Latency measurements, transient comparisons and mono checks. | Shared render timeline. |
| Structure and spectral assistance | Which conflicts can we describe or reduce reliably? | Explainable proposals compared with manual DJ choices. | Actual overlap context and confidence policy. |
| Touch and DJ workflow | Can the DJ understand, override and recover from assistance? | A minimal control proposal and physical gesture checks. | Parameter ownership contract. |
| Listening and evidence | Does the combined result sound better with less effort? | Repeatable blend set, source-bound results and Erik's acceptance. | Outputs from each candidate under test. |

Use one decision record for each experiment. Record its hypothesis, baseline, changed variable, failure criteria, source and outcome. Retain rejected results so another agent does not repeat an unhelpful approach.

Agree the shared contracts before implementation. Allocate a request ID to each runtime increment. Consolidate accepted source through the normal branch and review workflow before a test build.

## Validation and musical acceptance

### Use a small difficult blend set

Select six to eight real pairs from Erik's library. Include both transition directions where they expose different behaviour. Preserve exact cues, accepted grids and preparation.

| Blend | Main question |
| --- | --- |
| Drifting disco into a steady modern remix | Does bar alignment reduce nudges while retaining the groove? |
| Two drifting records | Does one clear reference prevent unstable mutual correction? |
| Dune's *In the End* into a clear pulse | Does sparse material expose uncertainty without false lock? |
| Long kicks and sustained bass | Does the blend retain attack and low-end stability? |
| Busy vocals or strong melodic hooks | Does assistance respect arrangement and harmonic limits? |
| Spacious stereo material and long tails | Does the image remain stable through mono checks and transitions? |
| A quiet breakdown into a loud master | Does gain handling preserve the intended energy change? |
| An unsuitable or deliberately wrong map | Does the system remain continuous and visibly unresolved? |

Use synthetic signals for exact engineering questions. Use real recordings for musical judgements. Neither replaces the other.

### Compare one change at a time

1. Fix the tracks, cue points, preparation, master tempo and output route.
2. Record the current neutral path and the candidate at matched perceived levels.
3. Compare free playback, ordinary Sync and R162 where the question concerns timing.
4. Compare the same transition in TDJ1 or another available reference when practical.
5. Randomise listening order when practical and retain an unchanged repeat.
6. Judge stereo and mono output, including the moment assistance starts or stops.
7. Record preference, defects and manual corrections before revealing the candidate.

The listening questions are concrete:

- Can the DJ still feel the source groove?
- Do kicks sound solid, doubled, softened or unstable?
- Does bass disappear, swell or pump during the handover?
- Do vocals and percussion retain their articulation?
- Does correction produce audible surging, pitch change or image movement?
- Does the blend preserve the intended phrase and energy direction?
- Can the DJ override assistance immediately with fewer corrective actions overall?

Record mixed results by track pair. A preferred average must not hide a serious failure on one recording.

### Keep engineering and musical criteria separate

| Criterion | Required evidence |
| --- | --- |
| Continuous transport | No automatic cursor jumps, invalid samples, source starvation or unintended stops. |
| Timing | Bar error, internal onset relationships, applied rate and limit state on the exact source. |
| Attacks and level | Peak and true-peak readings, crest-factor changes and rendered attack comparisons. |
| Phase and image | Related-path latency, stereo listening and mono cancellation checks. |
| Real time performance | Existing audio and control deadlines, memory and thermal limits on the A10X. |
| DJ control | Immediate override, preserved saved choices and no missed or delayed touches. |
| Musical value | Erik prefers the result or achieves the same result with fewer corrections and no new audible defect. |

Retain existing numerical transport and performance limits. Set any new perceptual threshold from the listening results before using it as a pass criterion. Do not invent a universal groove score or millisecond tolerance.

## Delivery order

1. Establish a matched-level reference for the current mixer and the difficult blend set.
2. Resolve the first reproducible headroom, transient or stereo defect in one focused increment.
3. Complete R162 listening and physical acceptance before changing its controller or widening intervals.
4. Compare EQ responses and a DJ-controlled bass handover if the reference blends show a clear need.
5. Evaluate bounded spectral assistance against the accepted manual approach.
6. Evaluate optional colour only after the clean path meets its musical and performance criteria.
7. Consider phrase assistance, longer intervals and stems through separate requests.

Preparation and read-only research can progress across workstreams. Each runtime increment follows the [single-change iPad loop](../testing/README.md). Broad release qualification remains a separate, user-directed activity.

The immediate deliverable is a repeatable reference blend set and a clean-mixer audit. The next implementation should address its first demonstrated defect. Further processing must earn its place through audible benefit, preserved touch and measured A10X performance.
