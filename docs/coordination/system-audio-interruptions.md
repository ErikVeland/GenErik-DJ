# R99 system alerts and playback continuity

GenErik DJ requests the iPadOS preference for fewer system alert interruptions before it activates audio. It requests the preference again when it rebuilds output. If iPadOS refuses the preference, audio startup continues.

Apple documents protection for incoming calls shown as banners. Accepting a call can interrupt the audio session. Full-screen incoming calls can still interrupt it. The preference does not silence every alert or change Focus. [Apple audio session preference](https://developer.apple.com/documentation/avfaudio/avaudiosession/setprefersnointerruptionsfromsystemalerts(_:))

For ordinary notifications, configure a Focus that activates when GenErik DJ opens. Review allowed people, allowed apps, repeated calls and time-sensitive notifications. Check Clock alarms separately. [iPad Focus settings](https://support.apple.com/en-au/guide/ipad/ipad85aa12a1/ipados) · [iPad Clock alarms](https://support.apple.com/guide/ipad/ipadec8a36cc/ipados)

## Additional stop paths

- **Release when the grid has no matching position.** A host probe reproduced this with a 100 ms clip on a 120 BPM grid. The renderer rejected release at a phase outside the clip. Sync stayed on, the deck stayed held and audio stayed silent.
- **Release preparation failure.** R96 keeps a release through queue pressure. When the streamed source cannot prepare the return position, the controller reports the error and clears the request. The native deck can stay held because the release changes its state only after source validation succeeds. The next release fix needs a deliberate fallback if that audio is unavailable.
- **Missed handoff.** A full command queue can still reject Play. If that Play was meant to start the next deck, the current track can end before another deck starts. This is a code finding.
- **Failed output restart.** R96 retains transport if the graph cannot restart. After it reports a failed restart, output can remain silent until another device event or Play. A renderer that stops sending callbacks without an output notification also has no automatic detection path. These paths need controlled failure tests on the physical route.
- **View teardown.** If the root performance view disappears, its teardown calls Stop and finishes recording. The iPad background handler is separate. Verify that screen lock, app switching and window changes do not tear down the performance view during a set.
- **Source and CPU pressure.** The streamer fades toward silence when it runs out of audio. An in-flight analysis prediction can overlap playback until it returns. Measure both on A10X through a sustained set. These are existing open risks from R96.

The short-track probe and source identity are in `TestBuilds/r99/`. The remaining paths are code findings. The signed iPad build checks the preference call. Only a device test with Silent Mode off can establish actual notification and call behaviour.
