# R161 TestFlight distribution

Erik requested iOS and Mac TestFlight distribution, current artwork and an external testing group on 11 November 2026.

## Builds

- iOS 0.1.0 (226): archived from `c9fd852c8` on main with Xcode 27.1. Signature and embedded-framework checks passed. Export attempts 1 and 2 failed because Xcode could not use the Apple account. Attempt 3 succeeded after sign-in refresh. See [build record](../testing/builds/226.json).
- macOS 0.1.0 (226): archived from `e04f45ae4` on main with Xcode 27.1. Both Intel and Apple silicon executables are included. Deep strict signing verification passed. The archive includes the current icon, privacy manifest and sandbox entitlements. Export attempt 1 failed before sign-in refresh. Attempt 2 succeeded. Evidence remains under `TestBuilds/r161/mac/`.

`GenErikDJStore` is the Mac distribution target. It shares the existing interface and audio engine. Its entry point saves the library under Application Support inside the app container. The development target and analysis workers retain their existing workspace. The distribution target does not scan the development Traktor workspace at launch. Runtime imports, persistent file access, controller operation and audio acceptance still need physical verification.

## App Store Connect

App: `6832211854`. Team: `54WU29TRTY`.

Created the macOS platform. Created Internal Testers with automatic distribution disabled, then External Testers. Apple exposed external-group creation after the internal group existed. No tester invitations were sent.

- External group: `4f9ffe8e-a572-4257-8b9b-b238b0dbcbe9`.
- Internal group: `1d53909c-8e33-489b-ac41-2906dcdfa690`.

Uploaded the 3840 × 1646 GenErik header to the iOS product-page draft. Apple displayed one header asset. R174 removed the rejected artwork from the project. The uploaded header still needs replacement in App Store Connect. Both archives carry the current Icon Composer artwork. Apple must process the uploaded builds before their icons and testing status can be confirmed.

Beta description and feedback email are saved. The beta review contact needs Erik's phone number. The privacy-policy URL is verified below. External beta review, tester availability and physical acceptance remain open. No public App Store release was submitted.

Apple accepted both uploads on 11 November 2026. Both upload commands returned success. Processing, build-icon confirmation and external review remain pending. The [Mac build record](../testing/mac-builds/226.json) preserves the archive hash and export attempts.

## Live website links — 18 November 2026

Erik confirmed that the website and legal pages are live. Public HTTPS checks returned HTTP 200 for the privacy, support and legal routes.

| App Store Connect field | URL |
| --- | --- |
| Marketing URL | https://dj.generik.au |
| Support URL | https://dj.generik.au/support |
| Privacy Policy URL | https://dj.generik.au/privacy |
| Privacy choices | https://dj.generik.au/privacy/choices |

The site lists `erik@veland.au` as the support and privacy contact. The privacy notice covers the development app and website, effective 18 November 2026. It describes automatic private CloudKit preparation sharing and local audio analysis.

App Store Connect changes and current build status still need verification after sign-in. The beta review contact phone number remains unresolved in this chat. The rejected header remains a separate R174 replacement item.
