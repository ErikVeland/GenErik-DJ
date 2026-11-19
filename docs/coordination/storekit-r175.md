# R175 StoreKit purchases and performance limits

## Product choices

- Give each performer 14 days of access to all features from first launch. Do not start a paid subscription automatically.
- Offer monthly and lifetime purchases for Controller Support, Recording and Open Format.
- Offer one lifetime All-in-One purchase for all three features.
- Include in-app DJ name and logo personalisation with every lifetime purchase. Monthly plans do not include it after the preview.
- Use separate subscription groups so customers can hold more than one monthly feature plan.
- The monthly products must provide ongoing feature updates and support. Keep purchases available across iOS and macOS.
- Use App Store in-app purchases for all feature access. Apple requires in-app purchases to unlock app features. Auto-renewing subscriptions must provide ongoing value and work across the customer’s devices. [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/).
- Do not start an auto-renewing trial. The 14-day preview is an app access period, then the performer chooses a purchase.

## App Store product IDs

| Purchase | Product ID | Store type |
| --- | --- | --- |
| Controller Support monthly | `org.generikdj.replica.controller.monthly` | Auto-renewable subscription |
| Controller Support lifetime | `org.generikdj.replica.controller.lifetime` | Non-consumable |
| Recording monthly | `org.generikdj.replica.recording.monthly` | Auto-renewable subscription |
| Recording lifetime | `org.generikdj.replica.recording.lifetime` | Non-consumable |
| Open Format monthly | `org.generikdj.replica.open_format.monthly` | Auto-renewable subscription |
| Open Format lifetime | `org.generikdj.replica.open_format.lifetime` | Non-consumable |
| All-in-One lifetime | `org.generikdj.replica.all_in_one.lifetime` | Non-consumable |

## Limits

- Start one performance clock on the first Play or Record action. Continue to count wall-clock time while tracks are stopped or silent.
- The performer ends a performance after all decks stop. This explicit action resets the performance limits.
- After 20 minutes of controller use in one performance, ignore further controller input. Keep touch input and current audio available.
- Stop and finalise each free recording after 20 minutes. Keep deck playback available.
- After 70 minutes, reject new playback starts for the free Open Format feature. Let current audio continue.
- The 14-day preview unlocks all features and removes these limits.
- Personalisation replaces the in-app header and About mark. Keep the App Store name and app icon unchanged. Save the custom name and logo on each device.

## Remaining release work

R426 created the seven product drafts and the three monthly subscription groups in App Store Connect. English (Australia) product and group names are saved. Product prices, availability, review assets and entitlement checks remain open. The [App Store record](../app-store/README.md) records the metadata and artwork status. The 1.0 release needs a signed build with the current product IDs. Verify purchase, restore and time limits before submission. Physical controller testing is not a release blocker.

## Implementation notes

No StoreKit purchase client or Open Format mode existed in the source at request start. StoreKit access belongs at the application edge. Feature policy and time limits must stay outside the audio render callback. Recording finalisation must run through the existing asynchronous finish path.
