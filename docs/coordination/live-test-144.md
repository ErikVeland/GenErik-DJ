# Build 144: first live test

Erik reported these results on 9 November 2026 after using the A10X iPad with the original Z1.
Build 144 is assumed from the last recorded iPad installation. Erik confirmed the iPad and Z1 setup.

Analysis was generally accurate. The Z1 connected and worked, including the custom lights.
This confirms initial physical operation, not sustained live-performance acceptance.

## Blocking feedback

| Request | Report | Required result |
| --- | --- | --- |
| R89 | A loaded track appears partway through the waveform even though audio starts at the beginning. | Show the file start at the playhead on every load. Follow the actual audio position while stopped and playing. |
| R90 | Moving the Z1 crossfader sometimes mutes the track until stop/start. | Keep audio continuous. Do not require stop/start to recover crossfader output. |
| R91 | The small preview strip does not feel like TDJ1. | Restore Erik's expected touch navigation and reliable return to the grid. |
| R92 | Loading a long unanalysed track causes audio and waveform flicker. | Loading and background work must yield before they disturb live playback or controls. |
| R93 | Sync is lost during performance. | Only an explicit Sync-off action may disengage Sync. Keep transport tied to the grid. |

## Transport contract

The grid is the timing authority. Erik must be able to rely on it throughout a set.

- Preserve the user's Sync choice across loads and transport operations.
- With Sync enabled, starts, restarts, seeks, cues and gesture releases must preserve or restore beat alignment.
- Temporary scratching or braking must not silently disable Sync or change the saved choice.
- Show the file start at the playhead during loading. A timing anchor inside the file is not a load position.
- Keep preview navigation and deliberate grid editing distinct from the current audio position.
- Treat a missing grid as unresolved. Do not claim beat alignment until a usable grid is available.
- Analysis must not move a loaded waveform away from the audio position or disturb playback.

## First increment: R89

Source inspection found that loading sets the viewport to `grid.anchorFrame`, while audio preparation starts at frame zero.
The playback monitor follows playing, queued, paused and ended states but omits ready decks.
It can also apply the old track's paused position while its replacement loads.
The pending Music-library preview uses the grid anchor for both its centre and playhead.
Automatic grid completion can move the viewport to a detected downbeat without moving the audio.

The focused fix covers these display paths. Nine focused host tests passed across twelve cases.
The initial run reproduced nine failed expectations before the source change.
The initial test compilation error and all subsequent logs are retained under `TestBuilds/r89/`.
Build 150 installed on the A10X iPad, and iPadOS accepted launch.
Physical verification remains open. R90–R93 remain open.
See the [build record](../testing/builds/150.json) for source identity, evidence and test steps.
Preserve explicit preview, Freeze and grid-edit views. Keep the current iPad and Duo layouts.

Verification covers nonzero grid anchors, both decks, a ready deck seek and replacement of a paused track.
It also checks that explicit preview, Freeze and grid editing retain their view.
Bind the test log and build record to the tested source. Erik verifies physical behaviour on A10X.

## Second increment: R93

Build 151 installed on the A10X iPad, and iPadOS accepted launch.
The fix retains Sync until explicitly disabled and keeps normal transport on the grid.
Forty-two focused host tests passed across fifty-nine cases. Physical acceptance remains open.
See the [Sync contract](persistent-sync.md) and [build record](../testing/builds/151.json).

## Diagnosis and remaining work

The R93 audit found that waveform dragging and vinyl stop disabled Sync. Loading without a grid also discarded Sync intent.
Build 151 removes these paths and restores grid alignment at normal transport transitions.
The preview strip currently changes the viewport without changing audio position.
The crossfader mute and long-track flicker still need reproduction and source-level evidence.

Follow the serial iPad loop. Deliver one focused build, then leave the device for Erik's next test.
