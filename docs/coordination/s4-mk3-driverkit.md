# S4 Mk3 direct USB on M-series iPad

This is the DriverKit follow-up to R123. The separate `GenErikDJS4DriverKit` Xcode scheme embeds the S4 Mk3 extension. The standard GenErik DJ target retains the A10X bridge. The DriverKit variant uses a separate app identity and local workspace.

The driver matches USB device `17cc:1720`, configuration 1, interface 3. It opens interrupt IN `0x83` for controls and interrupt OUT `0x02` for the panel. It uses HID output requests for the jog rings. It leaves the audio interfaces for iPadOS. [USB descriptor and split report capture](https://github.com/libusb/hidapi/issues/274) · [Mixxx mapping](https://github.com/mixxxdj/mixxx/blob/main/res/controllers/Traktor-Kontrol-S4-MK3.js)

The driver keeps button edges in order and sends the latest fader and wheel positions. It reassembles a documented 79-byte fader report when USB delivers it in two packets. The app reuses the bridge's four-deck mapping and blue beat and amber track-end lighting. The driver accepts the panel and ring reports only. Motor drive, displays and external audio capture remain open.

## Local build

Use the `GenErikDJS4DriverKit` scheme with an iOS device destination. To check compilation and embedding without credentials, set `CODE_SIGNING_ALLOWED=NO`. Xcode places the extension in the app's `SystemExtensions` folder. The unsigned app cannot run on an iPad.

## First hardware verification

1. Obtain the DriverKit and USB transport entitlements for the driver. Obtain the Communicates with Drivers entitlement for the app.
2. Sign the app and extension with profiles from the same development team.
3. Install the signed app on an M-series iPad.
4. Enable **GenErik S4 Mk3** under **Settings → General → Drivers**.
5. Connect the separately powered S4 Mk3. Check the controller status in GenErik DJ.
6. Check controls and lighting. Disconnect while a jog or Cue contact is held and check that it releases.
7. Confirm that iPadOS exposes four audio output channels. Check master 1–2 and headphones 3–4 separately.

The entitlement files describe the access this target needs. Apple must grant the applicable entitlements before distribution. The built-in audio driver must expose the four channels for the automatic split route. Physical interface matching, audio, timing and recovery remain open. [Apple DriverKit for iPadOS](https://developer.apple.com/documentation/driverkit/creating-drivers-for-ipados) · [Apple entitlement process](https://developer.apple.com/documentation/DriverKit/requesting-entitlements-for-driverkit-development) · [USB transport entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.driverkit.transport.usb)

## Verification result

The unsigned Release build passed on source `4d631e226`. The app contains the ARM64 DriverKit extension at the expected path. The runtime framework check, eleven focused Swift tests and the C++ report fixtures passed. The C++ fixtures check a split fader report, button-queue overflow and rejection of motor reports. No app or driver was installed or run on an iPad.
