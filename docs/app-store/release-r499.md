# R499 Worldwide release preparation

The candidate includes the current mappings for 415 hardware models across 49 manufacturers. The app bundles 406 profiles. The compact encoding matches the profile source. Controls, setup, feedback and audio routing vary by model. See the [controller catalogue](https://dj.generik.au/controllers).

Build 230 passed both signed archive checks and both exports. App Store Connect validated both uploads. The iPad accepted installation and launch. The Duo accepted installation and required an unlock before launch. Build 231 includes the simulator CloudKit guard and controller fixture updates. Both signed archives and exports passed. Its production mappings are the same as build 230.

The first source run passed 427 checks. It skipped 23 and could not open historical files needed by 15. The first native run identified outdated assumptions about a shared Reloop name, three independently mapped models, SR2 selector state and continuous-control queue order. The focused rerun has separate logs. Availability of a mapping does not establish physical audio, touch or feedback acceptance.

App Store Connect set the base app to free and saved availability in 175 territories. It saved and verified the English (Australia) descriptions, keywords, promotional text, subtitle and review notes.

| Purchase | Monthly AUD | Lifetime AUD |
| --- | ---: | ---: |
| Controller Support | 2.99 | 19.99 |
| Recording | 1.99 | 12.99 |
| Open Format | 2.99 | 19.99 |
| All-in-One | | 39.99 |

Apple supplied the equivalent prices for other territories. The [djay](https://apps.apple.com/au/app/djay-dj-app-ai-mixer/id450527929) and [Cross DJ](https://apps.apple.com/au/app/cross-dj-music-mixer-app/id584824960) listings informed the AUD tiers.

The Mac artwork uses two captures from build 230 with original demo tracks. The website uses the same composition. The original captures, build archives and verification logs are in `TestBuilds/r499-worldwide-release`.

The full mobile screenshot set and purchase review screenshots are pending. App Review submission is pending.
