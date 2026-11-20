# App Store compliance readiness

**Review date:** 20 November 2026

**App:** GenErik DJ, Apple ID `6832211854`
**Status:** Account states checked. Final declarations and release sign-off remain open.

This record maps current project evidence and the App Store Connect state checked on 20 November 2026. It does not replace Apple's current questions, legal advice, or the Account Holder's review. The account showed both app versions as Prepare for Submission. No submission was made.

## Readiness record

| Area | Evidence and current state | Action before submission |
| --- | --- | --- |
| App information and age rating | Both 1.0 versions showed Prepare for Submission. The saved rating is 4+ with regional ratings. The new Shared Location and Dating and Relationships answers were reviewed in an unsaved form. Both were set to No based on the current feature source. | Confirm and save the new answers in App Store Connect. The page says new apps must answer these questions before submission. It showed 15 January 2027 as the general deadline. Review the calculated rating after saving. |
| App Compliance page | The page showed Active entries for China mainland Security Assessment and AI Generated or Synthetic Content, plus a DSA trader declaration. The ICP Filing Number section showed Set Up. Vietnam Game License and Regulated Medical Device appeared as conditional sections. | Check that the active answers and supporting records match the actual distribution regions and release. Decide whether an ICP filing or either conditional item applies. Record the basis and evidence. |
| App privacy | App Store Connect showed Data Not Collected as published, with the privacy policy and user privacy choices URLs. The live privacy notice says private CloudKit sync retains track metadata, hashes, analysis, waveforms, and section information. It also says the app keeps an account-specific identifier. The privacy manifest lists no collected data and disables tracking. | Resolve whether the CloudKit data and identifier meet Apple's collection definition for the app and its service partners. Reconcile the final iOS and macOS builds, CloudKit fields, local diagnostics, privacy notice, manifest, and App Store answers. Do not treat the published answer as approved until this review is recorded. |
| Encryption and export compliance | `Replica/iPad/Info.plist` sets `ITSAppUsesNonExemptEncryption` to false. The source review found CryptoKit SHA-256 hashing, not a standard encryption algorithm. App Store Connect showed no uploaded encryption documents. This review did not inspect final archives or every dependency. | Reconcile the final iOS and macOS archives and dependencies with Apple's export-compliance questions. Confirm the declaration and provide documents only if Apple's determination requires them. Save the decision and any approval evidence with the release record. |
| Content rights | App Store Connect saved “No, this app does not contain, show, or access third-party content.” The app accesses local music from the user's library. It has no bundled music or streaming catalogue. | The Account Holder must confirm that “No” is accurate for the app's local-library access and that all music and product-page content has the required rights. Change the answer if this review is not accurate. |
| End-user licence | App Store Connect showed Apple's Standard License Agreement. No custom EULA is recorded. | Keep the standard EULA if it matches the intended terms. Review any proposed custom terms before adding them. |
| Apple agreements | Business → Agreements showed the Free Apps Agreement and Paid Apps Agreement as Active. The Paid Apps Agreement showed an effective period ending 15 September 2027. | Keep the active agreements in place. The Account Holder must review any new terms or account requests from Apple. Do not store tax or banking details here. |
| Open-source licences | The app source includes `Replica/THIRD_PARTY_NOTICES.txt` and component licence files. The website has a credits and licences page. | Compare the notices with the exact release binaries and website. Confirm required attribution and licence text are present in customer-accessible locations. |
| Region-specific obligations | App Store Connect showed a DSA trader declaration and China mainland compliance entries. The selected distribution regions and basis for these declarations were not checked. | Check each selected territory for registration, permits, trader details, age-rating, or other declarations. Record exclusions and evidence for every conditional requirement. |
| Public legal pages | The linked privacy policy and privacy choices pages load. The privacy policy has an effective date of 18 November 2026. It describes CloudKit retention and says sync has no permanent in-app opt-out. | Reconcile the policy with Apple's privacy answers and the final build. Check the live terms and credits pages against the release build before submission. |

## Required sign-off

The Account Holder is the only App Store Connect role that can sign Apple legal agreements. Do not treat this record or an accepted metadata declaration as that person's approval.

| Sign-off | Name and date | Evidence |
| --- | --- | --- |
| App behaviour, data flows, and privacy answers | Pending | Resolve the CloudKit declaration question and compare the final builds with the published privacy answer |
| Content rights and age-rating declarations | Pending | Account Holder confirmation of the local-library rights answer and new age-rating answers |
| Apple agreements and regional declarations | Account agreement statuses active. Regional review pending. | Free Apps and Paid Apps agreement states, plus final review of regional declarations |

Record the Account Holder's review date and any required decision. Do not store credentials, tax details, bank details, or identity documents in this repository.

## Apple references

- [App and compliance information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-and-compliance-information)
- [App Store Connect release notes](https://developer.apple.com/help/app-store-connect/release-notes/)
- [Manage app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/)
- [App privacy details](https://developer.apple.com/app-store/app-privacy-details/)
- [Overview of export compliance](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance/)
- [Sign and update agreements](https://developer.apple.com/help/app-store-connect/manage-agreements/sign-and-update-agreements/)
- [View agreements status](https://developer.apple.com/help/app-store-connect/manage-agreements/view-agreements-status/)
- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
