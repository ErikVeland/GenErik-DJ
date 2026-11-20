# App Store compliance readiness

**Review date:** 20 November 2026  
**App:** GenErik DJ, Apple ID `6832211854`  
**Status:** Prepared for account-holder review. Not legally signed off.

This record maps the current project evidence to App Store Connect compliance work. It does not replace Apple's current questions, legal advice, or the Account Holder's review. The App Store Connect account was not available in this session. Agreement and declaration states marked unverified need a direct check in that account.

## Readiness record

| Area | Evidence and current state | Action before submission |
| --- | --- | --- |
| App information and age rating | R426 records saved English (Australia) metadata and a 4+ rating in both drafts. | Complete the new Shared Location and Dating and Relationships declarations. The App Store Connect release notes set 12 January 2027 as the deadline for all apps. Check that the rating still matches the answers. |
| App Compliance page | Apple moved regulatory permits and declarations to this page on 16 November 2026. | Review the page for each distribution region. Decide and record whether AIGC, China mainland security assessment, permits, or other declarations apply. Do not mark a declaration complete from this source review alone. |
| App privacy | R426 records Erik's confirmation that “Data Not Collected” was published on 19 November. The app uses private CloudKit for preparation sync. The privacy manifest lists no collected data and disables tracking. | Compare the final iOS and macOS binaries, CloudKit fields, local diagnostics, privacy notice, manifest, and App Store privacy answers. Record the final comparison and publish any required correction. |
| Encryption and export compliance | Source review found CryptoKit use, including hashing, and CloudKit. This review did not classify every cryptographic use or bundled binary. | Answer Apple's export-compliance questions for the final builds. Confirm the `ITSAppUsesNonExemptEncryption` value. Provide encryption documents only if Apple's determination requires them. Keep the decision and any Apple approval evidence with the release record. |
| Content rights | R426 records Apple's saved “No” answer and Erik's confirmation that the app has no bundled music or streaming catalogue. The app can access local, unprotected tracks from the user's library. | Recheck the exact Content Rights question and answer in App Store Connect. Record why the answer fits local-library access. Keep permissions or licences for any third-party content included in the app or product page. |
| End-user licence | The product metadata links to Apple's standard EULA. No custom EULA is recorded. | Confirm that App Store Connect still uses the standard EULA. Review any proposed custom terms before adding them. |
| Apple agreements | The app has seven in-app purchase drafts. Apple's current guidance requires the Account Holder to sign the Paid Apps Agreement before offering in-app purchases. The agreement status is unverified. | The Account Holder must check Business → Agreements. Confirm the Apple Developer Program License Agreement and Paid Apps Agreement are active, and finish any required tax or banking details. Save the agreement status and date in the release evidence. |
| Open-source licences | The app source includes `Replica/THIRD_PARTY_NOTICES.txt` and component licence files. The website has a credits and licences page. | Compare the notices with the exact release binaries and website. Confirm required attribution and licence text are present in customer-accessible locations. |
| Region-specific obligations | The planned App Store territories and the current App Compliance answers were not available. | Check each selected territory for registration, permits, trader details, age-rating, or other declarations. Record exclusions and evidence for every conditional requirement. |
| Public legal pages | The repository contains privacy, privacy choices, terms, and credits content. The project records that the site is published, but the public URLs could not be checked in this review. | Open each public URL and compare it with the release build and the App Store metadata. Correct or republish any mismatch before submission. |

## Required sign-off

The Account Holder is the only App Store Connect role that can sign Apple legal agreements. Do not treat this record or an accepted metadata declaration as that person's approval.

| Sign-off | Name and date | Evidence |
| --- | --- | --- |
| App behaviour, data flows, and privacy answers | Pending | Final-build review and App Store Connect privacy status |
| Content rights, product terms, and licence notices | Pending | Content-rights rationale, EULA selection, and release notice review |
| Apple agreements and regional declarations | Pending | Active agreement statuses and completed App Compliance page |

Record the Account Holder's agreement status and date. Do not store credentials, tax details, bank details, or identity documents in this repository.

## Apple references

- [App and compliance information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-and-compliance-information)
- [App Store Connect release notes](https://developer.apple.com/help/app-store-connect/release-notes/)
- [Manage app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/)
- [Overview of export compliance](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance/)
- [Sign and update agreements](https://developer.apple.com/help/app-store-connect/manage-agreements/sign-and-update-agreements/)
- [View agreements status](https://developer.apple.com/help/app-store-connect/manage-agreements/view-agreements-status/)
- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)

