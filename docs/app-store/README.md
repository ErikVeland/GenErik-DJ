# R426 App Store metadata

The current compliance readiness review is in [compliance-readiness.md](compliance-readiness.md). It records the account states checked on 20 November 2026 and the remaining final-build and Account Holder decisions.

`en-AU.json` holds the prepared English (Australia) metadata for app `6832211854`.
The text reflects the current interface, local music requirements, private preparation sharing and R175 purchase design.
It includes seven purchase localisations. Prices are not inferred or changed.

The name, subtitle, promotional text, description and keywords pass the current Apple field limits.
Purchase names and descriptions also pass their limits. The STE linter is not installed, so the text received manual review.

## App Store Connect status

Saved the English (Australia) product fields in both 1.0 drafts on 19 November 2026.
Both drafts have the description, promotional text, keywords, copyright, support and marketing links, and App Review contact details.
The review phone remains in App Store Connect.
The shared subtitle and Music category are saved. Apple calculated a 4+ age rating.

The existing privacy policy and privacy choices links match the project URLs.
Erik confirmed that he published the **Data Not Collected** declaration in App Store Connect on 19 November 2026.
The app uses private CloudKit for preparation sync and keeps analysis and diagnostic processing local.
The privacy manifest lists no collected data and disables tracking.
As part of release qualification, check that the final build still matches the published declaration.
Apple saved No for the shared Content Rights declaration on 19 November 2026.
Erik confirmed that the app plays music from the user's own library. It includes no bundled music or streaming catalogue.
Accessibility feature claims await platform checks.

## Artwork and builds

Both 1.0 drafts show the approved icon from build 226, identified by Apple as version 0.1.0.
The iOS draft retains the approved branded header.
Apple takes each icon from the selected build.
Build 226 predates the label fix and the product ID correction. Build 227 is the installed iPad development build.
The release candidate needs the current source.

R427 uploaded three iPhone Duo screenshots and four native 10.5-inch iPad screenshots to the English (Australia) iOS 1.0 draft.
Apple accepted all seven files in the recorded order. [Files and upload evidence](screenshots-r427/README.md).
R429 added four resized 2752 × 2064 copies to the required 13-inch iPad slot. Apple accepted all four.
R430 added native captures from 1.0 (228) to the iOS and Mac drafts. [Release capture record](screenshots-r430/README.md).
The existing website images are historical captures or development previews.

## Purchase drafts

Saved all seven product records with their English (Australia) names and descriptions.
The three monthly products each have a one-month period and their own localised group.
Apple's form rejected hyphens in the Open Format and All-in-One product IDs.
The product records, source and metadata now use underscores for those IDs.
Swift syntax and the seven ID matches passed. StoreKit purchase and restore checks remain open.
Pricing, availability and review assets are pending for all products.

Both platform drafts are in Prepare for Submission.

On 20 November 2026, App Store Connect showed both agreements as Active and Data Not Collected as published. Erik confirmed that the developer and vendors cannot access private music or CloudKit records outside users' apps and Apple accounts. China mainland remains enabled, with the ICP Filing Number section at Set Up. The corrected licence-notice asset is ready for publication. The Shared Location and Dating and Relationships answers are saved as No, with a calculated rating of 4+. Content Rights remains saved as No; the proposed Yes answer is not saved. See the [compliance readiness record](compliance-readiness.md) and [China ICP filing guide](china-icp-filing.md).

## References

- [Apple app information fields](https://developer.apple.com/help/app-store-connect/reference/app-information/app-and-compliance-information)
- [Apple platform version fields](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information)
- [Apple app icon workflow](https://developer.apple.com/help/app-store-connect/manage-app-information/add-an-app-icon)
- [Prior App Store changes](../coordination/testflight-r161.md)
- [Purchase design and remaining setup](../coordination/storekit-r175.md)
