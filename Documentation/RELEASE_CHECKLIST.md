# Billio release checklist

This checklist separates changes enforced by the repository from account-level
steps that must be completed in Apple Developer, CloudKit Console, and App Store
Connect.

## Repository and build gates

- [x] iOS 17 deployment target and iPhone/iPad target membership.
- [x] iPad portrait and landscape orientations configured.
- [x] Release build validates with `CODE_SIGNING_ALLOWED=NO`.
- [x] App and Widget privacy manifests declare the UserDefaults required reason.
- [x] CloudKit uses a versioned SwiftData schema (`BillioSchemaV1`) and an explicit
  migration plan.
- [x] Exchange-rate requests have a 20-second timeout and one transient retry.
- [x] Local notification copy and model-backed labels use the selected app locale.
- [ ] Run the full localization review on every supported device language and
  replace any catalog entry that is still English by design.
- [ ] Archive with the distribution profile and export an App Store package.

## Apple Developer and CloudKit

- [ ] Confirm the App ID, application group, and both bundle identifiers belong
  to the intended team.
- [ ] Confirm `iCloud.JIANGJINGZHE.Billio` exists and the production schema is
  deployed before TestFlight submission.
- [ ] Test a new iCloud account, no account, restricted account, offline mode,
  two-device import/export, and reinstall recovery on TestFlight.
- [ ] Verify the Release provisioning profile contains the production CloudKit
  environment and the final entitlements.
- [ ] Confirm local fallback behavior is understood and does not silently create
  a second unsynchronised copy of a user's data.

## App Store Connect

- [ ] Add the privacy policy URL and support URL.
- [ ] Complete App Privacy answers for SwiftData, private CloudKit sync, local
  notifications, exchange-rate requests, and user-initiated CSV exports.
- [ ] Set age rating, category, pricing, availability, and review contact data.
- [ ] Upload iPhone and iPad screenshots, widget screenshots, and localized
  metadata for all shipped languages.
- [ ] Submit a TestFlight build and verify interactive widgets, App Intents,
  Siri, Shortcuts, notifications, iCloud sync, CSV export, and all supported
  languages on physical devices.

## Final QA matrix

- [ ] Light/dark/tinted appearance, Dynamic Type, VoiceOver, Reduce Motion, and
  Increase Contrast.
- [ ] iPhone portrait, iPad portrait, iPad landscape, and split view.
- [ ] Cold launch with network unavailable, no cached rates, and CloudKit
  unavailable.
- [ ] Monthly, quarterly, yearly, and overdue billing cycles across time-zone
  and daylight-saving transitions.
- [ ] Instruments pass for cold launch, memory peak, SwiftUI frame rate, SwiftData
  queries, and widget timeline work.
