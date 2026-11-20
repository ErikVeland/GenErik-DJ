# R499 Worldwide release preparation

The candidate includes the current mappings for 415 hardware models across 49 manufacturers. The app bundles 406 profiles. The compact encoding matches the profile source. Controls, setup, feedback and audio routing vary by model. See the [controller catalogue](https://dj.generik.au/controllers).

Build 230 passed both signed archive checks and both exports. The A10X iPad accepted installation and launch. The Duo accepted installation and required an unlock before launch. Build 231 includes the simulator CloudKit guard and controller fixture updates. Its production mappings match build 230. Both signed archives and exports passed. App Store Connect processed build 231 and selected it for the iOS and Mac 1.0 drafts. Both drafts are set to release automatically after approval.

The source suite passed 427 checks and skipped 23. Fifteen checks could not find their historical input files. The initial native run stalled. With isolated test data, 11 of the 12 focused checks passed after the Reloop test selected the specific model. The SR2 check also passed after the test used one factory mapping and one independently learned input. The test changes leave the production mappings as built. Controller hardware and sustained iPad audio and touch acceptance remain open.

App Store Connect set the base app to free and saved availability in 175 territories. It saved and verified the English (Australia) descriptions, keywords, promotional text, subtitle and review notes.

| Purchase | Monthly AUD | Lifetime AUD |
| --- | ---: | ---: |
| Controller Support | 2.99 | 19.99 |
| Recording | 1.99 | 12.99 |
| Open Format | 2.99 | 19.99 |
| All-in-One | | 39.99 |

Apple supplied the equivalent prices for other territories. The [djay](https://apps.apple.com/au/app/djay-dj-app-ai-mixer/id450527929) and [Cross DJ](https://apps.apple.com/au/app/cross-dj-music-mixer-app/id584824960) listings informed the AUD tiers.

The Mac artwork uses two captures from build 230 with original demo tracks. The iPhone 17 Pro and 13-inch iPad artwork use genuine simulator captures of build 231. Apple accepted the three compositions. The iPhone artwork replaced the older workspace menu placement. The website uses these compositions and lists the current controller catalogue and Australian purchase prices. The original captures, build archives and verification logs are in `TestBuilds/r499-worldwide-release`.

App Store Connect saved the reviewer directions for all seven purchases. The verified route on iPad is Music library, Settings, Help & About, then Unlock features. The simulator opened Feature access. StoreKit returned no purchase options, so genuine review screenshots remain open. All seven products still show Missing Metadata.

The Duo capture remains open. The simulator library stalled during the capture, and the physical Duo was unavailable. Both app versions remain in Prepare for Submission.
