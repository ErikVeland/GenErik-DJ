# R291 official website

## Scope

Build the product, manual, support and legal website at https://dj.generik.au.
Use the existing Glasscode Nginx host. Keep public navigation and metadata on the canonical domain.
This is website work. Do not build or install an app as part of this request.

## Evidence and feature inventory

The source audit starts at `fb4dc1e56e5f0260c0751d68cda7d33f8cbb533d`.
The repository does not establish an accepted public release. Public pages must identify the app as in development.

| Area | Status | Evidence and public boundary |
| --- | --- | --- |
| iPad | Implemented, acceptance open | README and iPad project target iPadOS 17+. State the development target, not a released compatibility guarantee. |
| Two decks, library, search, playlists | Implemented, acceptance open | ARCHITECTURE base instrument, LocalMusicLibrary and MusicLibraryView. Describe the development build. |
| Local music | Implemented | LocalMusicLibrary rejects protected and unavailable audio. No subscription streaming claim. |
| Waveforms, BPM, key, grids, sections | Implemented, acceptance open | ARCHITECTURE and R118/R124/R129/R139. No accuracy or timing guarantees. |
| Sync, loops, cues, EQ, effects | Implemented, acceptance open | ARCHITECTURE S3/S4 and source controls. No performance endorsement. |
| Recommendations | Implemented, acceptance open | BrowserRecommendations: ±6% tempo including half/double time; compatible keys first. No genre or learned behaviour claim. |
| Recording and history | Implemented, acceptance open | ARCHITECTURE S2 and recording source. No release entitlement or pricing promise. |
| Private cloud preparation | Implemented, acceptance open | CloudPreparationSync, AutomaticPreparationSharing and CloudPreparationArchive. Automatic idle sync is present. Do not describe it as opt-in. |
| StoreKit purchases | Implemented, not release-ready | R175. Products, pricing and purchase acceptance remain open. No App Store badge or prices. |
| Four decks, live stems, automatic mix | Experimental | ARCHITECTURE expansion gates. Excluded from home page. |
| Controller catalogue | Implemented, model acceptance varies | R169 and R176–R290. No supported-model list. |
| iPhone, Duo, Mac public support | Not release-approved | Active target is iPad. Excluded from availability claims. |
| Subscription streaming, testimonials, awards | Unsupported by evidence | Omitted. |
| Accessibility | No complete test evidence | Describe website implementation and app verification limits separately. |

## Design

Use the app's graphite stage (#0b0d0e), panel (#1b1d20), cyan (#7ddeE6), red playhead (#ed4538), pale text (#e6e6e6) and muted text (#a7adb2).
Use self-hosted Archivo variable type. Use tabular numerals for chapter positions.
A continuous timing rail joins the workflow. Interface captures establish the product. No cards, fabricated UI, autoplay or decorative loops.
Use full screens on wide layouts, legible crops with original-image links on narrow layouts, and a compact wrapping navigation.

## Release dependencies

- DNS is configured. The dedicated certificate was issued on 18 November 2026 and expires on 16 February 2027.
- Reconcile the privacy notice with the final signed app and App Store Connect declarations.
- Hosting inspection confirmed direct Nginx delivery and 14 daily log rotations. The site disables routine access logging.
- Obtain current, release-approved product captures. Historical test captures must remain labelled.
- Complete Safari/iPadOS, macOS Safari, Chromium, Firefox and assistive-technology checks where available.
- Confirm public release, supported platforms and App Store listing before changing release-state copy.

## Verification

The static build passes all 12 routes and 300 internal link/asset targets.
All text palette pairs pass 4.5:1 contrast. The lowest measured ratio is 7.45:1.
The site has no executable JavaScript, external runtime requests, cookies or contact-form backend.
The committed assets total approximately 0.97 MB, including image variants and notices. Each visitor downloads only the required variants.

The in-app browser checked all ten public routes at 320 CSS pixels with no horizontal overflow or missing heading/image failures.
Phone home and manual layouts were reviewed at 390 pixels. Tablet privacy was reviewed at 768 pixels.
Desktop support was reviewed at 1440 pixels. Its disclosure opens by pointer and closes with Enter. Keyboard focus is visible.
A larger browser navigation batch timed out after the first ten successful checks. The interrupted batch is not a full browser-matrix pass.
Physical iPad Safari, separate Chromium/Firefox engines, screen-reader operation, high zoom and throttled-network tests remain open.
The STE linter is absent from the installed skill directory. Copy received a manual review.

Erik rejected abstract slogans and generic cautionary copy. The homepage now describes concrete controls and actions. Compatibility restrictions remain in support and the manual.

The app purchase page privacy link now targets the canonical privacy route. No app build, simulator or device installation ran.
## Published result

Published https://dj.generik.au on 18 November 2026 from source `012c17e0a61fd6d6d00a8af197ebe2808ac595d3`.
`https://dj.generik.au/build.json` reports that exact revision.
The Glasscode Nginx host serves the site directly. Certbot has scheduled renewal.

All ten public routes returned HTTP 200 at their exact canonical URLs.
A missing route returned HTTP 404 and the designed error page.
Sitemap, robots, social artwork, font, licence notices and source identity returned HTTP 200.
HTTP, trailing-slash and index.html variants redirect to the canonical HTTPS route.
A host-directed request for the legacy Glasscode hostname redirects to the canonical route. That hostname has no public DNS record and does not expose an indexed duplicate.
All checked page responses include security headers and no Set-Cookie header.
The live browser rendered the updated copy and reported no warning or error logs.
Public route results are in `website/verification/public-routes.json`.

The publication is a working prerelease website. It is not a claim that the app or website has passed the complete App Store release checklist.
App Store Connect metadata fields were prepared in the website README but were not changed in App Store Connect.

## Primary references

- [Apple Standard EULA](https://www.apple.com/legal/internet-services/itunes/dev/stdeula/)
- [Apple App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/)
- [Apple iPad privacy controls](https://support.apple.com/en-ie/guide/ipad/ipad9ae59af9/27/ipados/27)

These references support the licence link and system-setting guidance. App-specific data statements come from the audited source, not assumptions about Apple services.
