# R426 App Store metadata

`en-AU.json` holds the prepared English (Australia) metadata for app `6832211854`.
The text reflects the current interface, local music requirements, private preparation sharing and R175 purchase design.
It includes seven purchase localisations. Prices are not inferred or changed.

The name, subtitle, promotional text, description and keywords pass the current Apple field limits.
Purchase names and descriptions also pass their limits. The STE linter is not installed, so the text received manual review.

## Live update status

Apple authentication is unresolved. Safari Technology Preview returned the sign-in page after Erik reported signing in.
The saved credential now requires Touch ID. No remote metadata field or artwork assignment has changed in this request.

After authentication, compare and save the fields in both existing platform drafts.
Retain the review phone number already entered by Erik. Do not copy it into the repository.
Check existing purchase records before applying their prepared localisations.
Reconcile the privacy questionnaire with the selected release build before publishing its answers.
Do not assert unverified accessibility support.

## Artwork and build

Use the existing approved `Replica/iPad/AppIcon.icon` artwork and the current App Store header.
Their source checksums are in the metadata file.
Apple takes the app icon from an uploaded build. The icon is not a standalone metadata upload.
The project currently uses marketing version `0.1.0`. The last recorded store drafts use `1.0`.
Check which builds Apple permits before selecting a build or changing the version.
Build 227 is a signed development install, not an App Store distribution upload.

Screenshots must match the selected build and platform. The website's historical captures do not establish current screenshot acceptance.
The metadata request does not submit a public release or invite testers.

## References

- [Apple app information fields](https://developer.apple.com/help/app-store-connect/reference/app-information/app-and-compliance-information)
- [Apple platform version fields](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information)
- [Apple app icon workflow](https://developer.apple.com/help/app-store-connect/manage-app-information/add-an-app-icon)
- [Prior App Store changes](../coordination/testflight-r161.md)
- [Purchase design and remaining setup](../coordination/storekit-r175.md)
