# App Store compliance readiness

**Review date:** 20 November 2026

**App:** GenErik DJ, Apple ID `6832211854`
**Status:** Account states checked. Final declarations and release sign-off remain open.

This record maps current project evidence and the App Store Connect state checked on 20 November 2026. It does not replace Apple's current questions, legal advice, or the Account Holder's review. The account showed both app versions as Prepare for Submission. No submission was made.

## Readiness record

| Area | Evidence and current state | Action before submission |
| --- | --- | --- |
| App information and age rating | Both 1.0 versions showed Prepare for Submission. The saved rating is 4+ with regional ratings. Source review found no location sharing or dating feature. On 20 November, App Store Connect showed Shared Location and Dating and Relationships saved as No. | Confirm the saved answers against the final app behaviour and record Account Holder sign-off. The page showed 15 January 2027 as the general deadline for new apps. |
| App Compliance page | The page showed Active entries for China mainland Security Assessment and AI Generated or Synthetic Content, plus a DSA trader declaration. The ICP Filing Number section showed Set Up. Vietnam Game License and Regulated Medical Device appeared as conditional sections. | Check that the active answers and supporting records match the actual distribution regions and release. Decide whether an ICP filing or either conditional item applies. Record the basis and evidence. |
| App privacy | App Store Connect showed Data Not Collected as published. Erik confirmed on 20 November that the developer and vendors cannot access users' private music or private CloudKit records outside their own apps and Apple accounts. Source review confirms uploads use users' private CloudKit databases. Local diagnostic logs are not sent unless users share them. | The access model supports the current answer under Apple's collection definition. Compare the final iOS and macOS builds, CloudKit fields, local diagnostics, privacy notice, manifest, and all third-party SDKs before final sign-off. |
| Encryption and export compliance | `Replica/iPad/Info.plist` sets `ITSAppUsesNonExemptEncryption` to false. The source review found CryptoKit SHA-256 hashing, not a standard encryption algorithm. App Store Connect showed no uploaded encryption documents. This review did not inspect final archives or every dependency. | Reconcile the final iOS and macOS archives and dependencies with Apple's export-compliance questions. Confirm the declaration and provide documents only if Apple's determination requires them. Save the decision and any approval evidence with the release record. |
| Content rights | App Store Connect still shows “No, this app does not contain, show, or access third-party content.” Erik confirmed that the app uses only music each user owns in their local library. The app has no bundled, curated, or streamed music. | Apple's question includes content the app accesses. The proposed answer is Yes with necessary rights. Save it only after the Account Holder confirms the exact declaration. |
| End-user licence | App Store Connect showed Apple's Standard License Agreement. No custom EULA is recorded. | Keep the standard EULA if it matches the intended terms. Review any proposed custom terms before adding them. |
| Apple agreements | Business → Agreements showed the Free Apps Agreement and Paid Apps Agreement as Active. The Paid Apps Agreement showed an effective period ending 15 September 2027. | Keep the active agreements in place. The Account Holder must review any new terms or account requests from Apple. Do not store tax or banking details here. |
| Open-source licences | The live credits page and linked application-notices file load. The public file included licence text from `Replica/.cache/fft-adoption-candidate`. The local asset no longer includes those candidate notices. | Publish the corrected asset after review. Compare each notice with the final release binaries and confirm each shipped component has the required notice. |
| Region-specific obligations | App Store Connect showed 175 available regions, including China mainland. China mainland Security Assessment and AI Generated or Synthetic Content entries are Active. The ICP Filing Number section still showed Set Up. The DSA trader declaration is saved. | Follow the [China ICP filing guide](china-icp-filing.md). The filing process needs identity verification through an eligible provider. Keep China availability only when the required filing is approved and matches the App Store metadata. |
| Public legal pages | The linked privacy policy, privacy choices, terms, and credits pages load. The terms page links Apple's Standard EULA and says music access does not grant distribution rights. The privacy policy has an effective date of 18 November 2026 and describes CloudKit retention. | Publish the prepared licence notice after review. Compare the terms and credits pages with the release build before submission. |

## Required sign-off

The Account Holder is the only App Store Connect role that can sign Apple legal agreements. Do not treat this record or an accepted metadata declaration as that person's approval.

| Sign-off | Name and date | Evidence |
| --- | --- | --- |
| App behaviour, data flows, and privacy answers | Owner confirmed access model. Final-build review pending. | Compare final builds and dependencies with the published privacy answer |
| Content rights and age-rating declarations | Age answers saved. Content Rights review pending. | Confirm the saved age answers and proposed local-library Content Rights answer against the final app. Record the Account Holder's sign-off. |
| Apple agreements and regional declarations | Free Apps and Paid Apps agreements active. ICP filing and regional review pending. | Provide China mainland ICP details or change availability. Confirm regional declarations. |

Record the Account Holder's review date and any required decision. Do not store credentials, tax details, bank details, or identity documents in this repository.

## Apple references

- [China ICP filing guide](china-icp-filing.md)
- [App and compliance information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-and-compliance-information)
- [App Store Connect release notes](https://developer.apple.com/help/app-store-connect/release-notes/)
- [Manage app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/)
- [App privacy details](https://developer.apple.com/app-store/app-privacy-details/)
- [Overview of export compliance](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance/)
- [Sign and update agreements](https://developer.apple.com/help/app-store-connect/manage-agreements/sign-and-update-agreements/)
- [View agreements status](https://developer.apple.com/help/app-store-connect/manage-agreements/view-agreements-status/)
- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
