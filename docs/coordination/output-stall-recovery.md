# R104 output stall recovery

Build 166 depended on output notifications to start recovery. A graph could stop producing rendered frames while the controller still marked output active. A later Play command could then wait for a callback that never arrived.

The existing control timer samples the transport's published output frame counter every 100 ms. The audio callback already updates that counter. Sampling does not add work to the callback. A mute, a silent passage or a render with no active deck can still advance the counter.

After at least 750 ms without progress, the monitor checks whether a deck is active, a start awaits the renderer or recording is active. It atomically closes the old callback gate only if no callback is active. If a callback remains in flight, the monitor reports the stall and checks again without waiting on the control thread.

The monitor uses the existing output recovery flow and keeps deck positions, the beat clock and Sync. If the physical output route changed, the app waits for Play. One automatic rebuild is available until two seconds of healthy frame progress or an explicit Play. If the rebuilt graph also stalls, the app waits for Play. A failed restart can use the existing bounded retry policy. Explicit Stop clears the monitor.

Ten focused host checks passed. They cover loss of frame progress, continued progress with silent output, repeat stall limits, preservation of transport and NI routing safeguards. The host checks simulate the recovery decision. The A10X and Z1 still need a physical check.

The monitor cannot infer audible output from successful renders. Source starvation, device silence after the render path, a callback that never returns and operating-system suspension remain separate limits.
