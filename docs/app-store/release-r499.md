# R499 Worldwide release preparation

The candidate includes the current mappings for 415 hardware models across 49 manufacturers. The app bundles 406 profiles. The compact encoding matches the profile source. Controls, setup, feedback and audio routing vary by model. See the [controller catalogue](https://dj.generik.au/controllers).

Build 230 passed both signed archive checks and both exports. The A10X iPad accepted installation and launch. The Duo accepted installation and required an unlock before launch. Build 231 includes the simulator CloudKit guard and controller fixture updates. Its production mappings match build 230. Both signed archives and exports passed. App Store Connect processed build 231 and selected it for the iOS and Mac 1.0 drafts. Both drafts are set to release automatically after approval.

The source suite passed 427 checks and skipped 23. Fifteen checks could not find their historical input files. The first native run identified outdated assumptions about a shared Reloop name, three independently mapped models, SR2 selector state and continuous-control queue order. The focused rerun compiled the updated tests. The test process stalled before it reported results. Controller hardware and sustained iPad audio and touch acceptance remain open.

App Store Connect set the base app to free and saved availability in 175 territories. It saved and verified the English (Australia) descriptions, keywords, promotional text, subtitle and review notes.

| Purchase | Monthly AUD | Lifetime AUD |
| --- | ---: | ---: |
| Controller Support | 2.99 | 19.99 |
| Recording | 1.99 | 12.99 |
| Open Format | 2.99 | 19.99 |
| All-in-One | | 39.99 |

Apple supplied the equivalent prices for other territories. The [djay](https://apps.apple.com/au/app/djay-dj-app-ai-mixer/id450527929) and [Cross DJ](https://apps.apple.com/au/app/cross-dj-music-mixer-app/id584824960) listings informed the AUD tiers.

The Mac artwork uses two captures from build 230 with original demo tracks. App Store Connect accepted the image. The live website uses the same composition and lists the current controller catalogue and Australian purchase prices. The original captures, build archives and verification logs are in `TestBuilds/r499-worldwide-release`.

The build 231 iPhone simulator reached the library. It stalled before the demo track loaded. The new iPhone, Duo and iPad marketing sets remain open. All seven purchases still show Missing Metadata and need review screenshots from the app. Both app versions remain in Prepare for Submission.
