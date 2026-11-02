GenErik DJ project — current implementation and archival research

Current code and readiness are documented in Replica/Status.md.
Analysis accuracy is the current development priority. The separate reference
research is in Analysis/Traktor-DJ-1x/. The acquisition notes below are a dated
record, not authorisation to resume parked device modification.

Historical acquisition notes — 21 October 2026

GenErik DJ archival port

Preserve the original Traktor DJ for iPad and investigate a future port.
The reference app is the first Traktor DJ product, not Traktor DJ 2.
The observed installed release is 1.6.8, not necessarily the launch release.

Status as of 2026-10-21: jailbreak and device modification are parked at the
user's request until after the next gig. Do not run the archive-boot helper,
enter DFU, jailbreak, reinstall the app, or change the performance setup as
part of the current research. Research may continue from public sources and
the local copies already acquired. This does not schedule an automatic resume.

The reconstruction research starts at:
  Analysis/Traktor-DJ-1x/README.md
It covers feature scope, interaction design, user journeys, transport timing,
technical requirements, source evidence, and reference checks still required.

Source/ stores original iOS packages (.ipa) without modification.
Analysis/ stores acquisition evidence and inspection results.
tools/ stores local inspection utilities.

Current evidence:
- GenErik is an iPad Pro 10.5-inch (iPad7,3), running iPadOS 17.7.11.
- The target bundle is com.native-instruments.traktordj, version 1.6.8,
  build 1.6.8.67. Its installed container is not accessible to devicectl.
- The iPhone edition and Traktor DJ 2 are also installed. They are separate apps.
- No IPA was found in the local iMazing app library.
- No Traktor IPA was found in the home folder or mounted user drives.
  Search scope and inaccessible paths are recorded in Analysis/.
- Earlier jailbreak authorisation is now parked by the user's latest request.
- No jailbreak has been performed. The iMazing backup stalled and was stopped.
- USB document access works through pymobiledevice3. Private container access
  was refused. All 53 shared documents (34,988,673,320 bytes) were copied into Backups/.
  Source sizes were checked, and local SHA-256 hashes were recorded.
- Analysis/export-format-observations.json records the exported XML schema and
  audio formats. Analysis/document-acquisition.json records copy status and hashes.

Package acquisition steps, deferred until the user resumes them:
1. Acquire the exact reference package and record its origin and SHA-256 hash.
2. Inspect its Info.plist, binary architectures, encryption flags, and assets.
3. Capture reference interactions, audio routing, controller support, and saved data.
4. Use those observations to define the port and its behavioural checks.

Package inspection (Python 3, standard library only):
  python3 tools/inspect_ipa.py Source/Traktor-DJ.ipa > Analysis/ipa-inspection.json

The inspection utility reads the package without extracting or changing it.
An IPA is compiled software. It does not contain the original source code.
No binary analysis has been completed. Independent replica development now
starts in Replica/, with a shared Swift core, Mac preparation preview and
iPad source target. See Replica/README.md for the build and fidelity limits.

Sources:
https://imazing.com/guides/how-to-manage-apps-without-itunes
https://imazing.com/blog/why-did-apple-kill-app-extraction-in-ios-9

Deferred helper, for reference only. Do not run while the jailbreak is parked:
  bash "/Users/veland/GenErik DJ/tools/run_archive_boot.sh"
The helper validates the completed document-copy report and acquired tool hash.
It then starts palera1n rootless and records output in Analysis/jailbreak-live.log.
