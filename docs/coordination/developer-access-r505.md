# R505 permanent developer access

Erik requires full feature access without purchases for his own development and performance testing.

Local iPad builds made with `tools/ipad_test.py build` or `run` enable developer access in the signed app. This unlocks controllers, recording, Open Format and personalisation. Preview expiry and performance time limits do not remove this access. The feature page identifies developer access and omits purchase controls.

The setting belongs to the app build. It is not saved as a purchase or copied into library data. Installing a store build restores the ordinary access policy. TestFlight archives explicitly disable developer access. Export and upload reject an archive with developer access enabled.

This change does not alter the audio renderer, controller mappings or recording format. The AIFF size limit still applies. At 48 kHz, the current 24-bit stereo writer reaches its limit after about four hours and nine minutes. Continuous longer recordings need a separate change.

## Verification

Focused checks cover an expired preview, a six-hour performance, personalisation, store-build isolation and the normal preview. Distribution checks cover rejection before export and upload, existing archives, retained failure records and source requirements. Failed and completed attempts remain under `TestBuilds/r505/`.

All three focused Swift checks and five distribution checks passed. The access regression failed before the fix. Both distribution rejection cases also failed before the guard. Signed iPad verification and physical acceptance remain open. Full access does not establish sustained audio or touch readiness for the party.

The first local attempt selected build 229 because the separate R499 archives were missing from the test ledger. It was stopped before installation. Recovered records reserve builds 230 and 231 using their actual archive identity and app hashes. The next build is 232.
