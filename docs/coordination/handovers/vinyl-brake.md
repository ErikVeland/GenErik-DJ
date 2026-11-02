# Vinyl Brake implementation

Implemented in `/Users/veland/GenErik DJ` on 2 November 2026.

Enable **Settings → Extra Controls → Vinyl stop control**. It is off by default. Stop duration defaults to 1.0 seconds and supports 0.2–5.0 seconds.

Touch Brake to start the stop immediately. Drag down to brake harder or up to coast longer. Release or cancellation lets the stop finish. Easing the brake never increases the current speed. Ordinary Pause remains immediate. The separate Play action cancels braking and restores the saved playback speed from the current position.

The audio renderer drives the slowdown. Speed and pitch fall together, including with key lock enabled. Brake disengages Sync, preserves the other deck's clock and cancels armed recovery. Existing effect tails continue. Existing tracks require no reanalysis.

## Verification

- All 16 Brake tests passed in the final focused run.
- Release iPad SDK compilation passed.
- Native transport checks passed at 48 and 96 kHz.
- All 658 tests passed in the earlier combined snapshot.
- Full and compact active Brake layouts were rendered and inspected.
- An independent review found two issues. The Resume timing race and misleading Play icon were fixed and tested.

Concurrent waveform and recovery work continued during verification. A later optional recovery run failed `recoveryEndpointRemainsAvailableWithoutADropForAutoMix` against an older recovery source snapshot. That run was stopped when another recovery integration test did not finish. The final Brake-only run passed after this.

Physical iPad listening, A10X stress testing and installation remain outstanding. No installed app was replaced.
