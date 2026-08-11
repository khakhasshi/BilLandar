# Billio architecture

Billio targets iOS 17 and uses SwiftUI, SwiftData, and Swift Charts without third-party dependencies.

## Layers

- `App`: composition root and persistent model container.
- `Models`: persisted domain entities and value types.
- `Services`: CloudKit container composition and event monitoring, current/historical exchange rates, recurring reminders, bill lifecycle reconciliation, merchant cancellation verification, insights, CSV export, centralized errors, and simulator sample data.
- `Core`: design tokens and dependency-free extensions.
- `Shared`: reusable presentation components.
- `Features`: screens grouped by product capability.

Views read and mutate `Bill`, `PaymentRecord`, and `PaymentMethod` through SwiftData's environment `ModelContext`. Feature views own transient navigation and filtering state. External services are injected through SwiftUI's environment so views do not construct network, notification, or CloudKit dependencies.

`AppFeedbackCenter` centralizes semantic selection, success, warning, and error feedback. Features publish intent to that environment service while the composition root owns the corresponding SwiftUI sensory-feedback modifiers. This keeps haptics consistent and makes them easy to disable or replace without embedding UIKit generators throughout feature views.

## Persistence and iCloud

`DataStoreFactory` creates a single schema containing `Bill`, `PaymentRecord`, and `PaymentMethod`. Production uses the user's private CloudKit database in `iCloud.JIANGJINGZHE.Billio`; if the CloudKit-backed container cannot be created, the app falls back to a local SwiftData store and exposes that state in Settings. Unit tests deliberately use an isolated local store.

The models avoid SwiftData unique constraints and required relationships so the schema remains CloudKit-compatible. Payment history and payment methods use stable identifiers and value snapshots rather than required relationships. Payment-method records contain only descriptive metadata and an optional last four digits.

`CloudSyncMonitor` listens to persistent CloudKit setup/import/export events. Settings separates iCloud account availability from observed synchronization, and reports the most recent successful event or failure instead of treating a signed-in account as proof that synchronization completed.

Debug simulator builds seed ten multi-currency subscriptions and realistic payment history. Device and Release builds never seed demo content.

The app and the `BillioWidget` extension share the same SwiftData store through the `group.JIANGJINGZHE.Billio` App Group. The shared configuration keeps CloudKit as the production backing database and records whether a local fallback is active so extensions open the same configuration. Display-currency, exchange-rate cache, and appearance preferences also use the App Group defaults suite. Widgets never combine unrelated original currencies when the required rate snapshot is unavailable.

## Currency and exchange rates

Each `Bill` stores its original amount and ISO 4217 currency code. `ExchangeRateStore` owns the user's display currency, cached current snapshots, historical snapshots, refresh state, and conversions. `ExchangeRateProviding` keeps the remote API replaceable; the current implementation reads current and date-ranged reference rates from Frankfurter v2 and caches the current snapshot per base currency for 12 hours.

Converted totals are never persisted back into a bill. If a required rate is unavailable, Billio keeps showing original amounts and withholds the combined total instead of silently mixing currencies.

## Lifecycle, product intelligence, and reminders

`BillLifecycleService` reconciles overdue active bills when the app starts or returns to the foreground. It creates one idempotent `pending` record for each missed billing occurrence and advances the next due date. It never records a successful payment without explicit confirmation.

`InsightEngine` is deterministic and independently tested. It detects duplicate merchants, historical price increases, trials ending within seven days, latest-payment failures, and renewal clusters.

`NotificationManager` owns permission state and schedules future local reminders for active recurring bills over an 18-month horizon, within the operating system's pending-request limit. Reminder display and scheduling use the same 09:00 calculation. Delivered identifiers are not immediately re-created, and disabling reminders removes only Billio-owned requests.

The notifications screen implements three real views: all upcoming items, scheduled bill reminders, and product insights presented as updates. Authorization state and scheduling failures remain visible to the user.

## Cancellation and payment-method safety

`MerchantCatalog` is a local curated list of known merchant account/cancellation domains. A link is labelled verified only when it is HTTPS and its host matches the known merchant entry. Unknown user-provided HTTPS links remain usable but carry a warning.

`PaymentMethod` is a reference model for organizing bills. It intentionally cannot store full account numbers, tokens, CVVs, or banking credentials and is not a payment-processing integration.

## Payment correction and undo

`PaymentWorkflowService` owns payment confirmation, editing, and undo. Every mutation returns a receipt containing the before/after state needed for a short-lived undo action. A newly inserted payment can be removed again, while confirming an existing pending payment restores its original status and metadata. Bill due-date advancement is reversed together with the payment so the two records cannot drift apart.

The bill-detail screen also provides a permanent edit path for historical records; undo is an immediate convenience, not the only correction mechanism. Destructive payment-method deletion and unsaved form dismissal require confirmation.

## Presentation and accessibility

`AppTheme` uses semantic system colors and adaptive accent colors, so cards, labels, separators, and statuses remain legible in light mode, dark mode, and increased-contrast mode. Reusable modifiers define a 44-point minimum touch target, tab-bar clearance, adaptive card depth, and reduced-motion-aware transitions.

The iPad calendar uses an adaptive seven-column grid with a centered content width instead of a fixed-width horizontal canvas. Calendar markers are built from one per-render day index, and Overview insights are refreshed from a lightweight data revision rather than regenerated during every body evaluation. Widget reload fingerprints use counts, timestamps, and status hashes instead of sorting and serializing every record.

Bill rows change layout at accessibility Dynamic Type sizes instead of compressing merchant identity and amount into one line. Charts expose spoken values and selectable details, calendar days and week-strip dates are buttons with explicit accessibility labels, and loading summaries use a reduced-motion-aware skeleton rather than replacing content with an unexplained blank state.

## Product navigation

The main app has five tabs: Overview, Calendar, Bills, Analytics, and Settings. Add/Edit Bill and payment-method creation use sheets; Bill Detail, Notifications, Payment Methods, and Privacy use navigation pushes. Bill Detail exposes valid status transitions for active, paused, and cancelled records.

Settings exposes System, Light, and Dark appearance modes. The selected mode is applied at the app scene boundary and persisted in the shared defaults suite; System continues following the device appearance.

## Localization

`Localizable.xcstrings` is the single source of truth for user-visible strings. English is the development language; the app and widget extension ship Simplified Chinese (`zh-Hans`), Traditional Chinese (`zh-Hant`), Japanese (`ja`), Korean (`ko`), French (`fr`), German (`de`), and Spanish (`es`). The system language determines the active localization, including App Intents parameter labels and widget copy. Domain enum titles use `String(localized:)` so categories, billing cycles, payment states, and appearance choices follow the same locale as SwiftUI labels.

## Widgets and system actions

The `BillioWidget` extension provides Next Payment, Monthly Spending, and Upcoming Bills widgets. Timeline reads use the shared SwiftData container and cached exchange rates, refresh at least every 30 minutes, and are explicitly reloaded when bills, payments, display currency, or rates change in the app.

Interactive widget buttons call `MarkBillPaidIntent`, which resolves the bill by stable UUID and delegates to `PaymentWorkflowService`. The transaction therefore records or confirms a payment and advances the due date using the same rules as the main app.

App Intents also expose confirmed monthly spending, bill creation, bill pausing, and payment confirmation to Siri, Spotlight, and Shortcuts. `BillEntity` supplies selectable active bills, while `BillioAppShortcuts` publishes four preconfigured shortcuts. Xcode extracts and validates the App Intents metadata during every app and widget build.

## Test boundaries

The `BillioTests` target covers billing-cycle advancement, reminder fire dates, overdue lifecycle idempotency, merchant normalization and cancellation-domain verification, safe payment-method normalization, current and historical exchange-rate conversion/failure behavior, insight generation, payment confirmation/undo for both new and pending records, widget multi-currency safety, appearance-mode definitions, system-action add/pause/pay mutations, and idempotent sample-data generation with an in-memory SwiftData container.
