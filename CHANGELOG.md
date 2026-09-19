# Changelog

All notable changes to **Soma** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased] - 2026-09-18e (speech vocabulary)

### Added
- **`SomaSpeechVocabulary`, a curated 97-phrase recognizer vocabulary** (Apple caps `contextualStrings` at 100): 42 Egyptian dishes, 28 venues and delivery apps in both scripts, 19 dialect phrasings and portion sizes, and 8 units and logging verbs. It replaces the previous 23-entry list, which was all generic measurement words ("grams", "calories", "water") that already live in the system vocabulary. Entries now target what a Saudi-trained Arabic model actually gets wrong: كشري، حواوشي، فطري مشلتت، ممبار، كوباية مية، شاي بلبن، بريد فاست، كوك دور، سيلانترو، and the English brand spellings dictation writes in Arabic letters.

### Changed
- **The Arabic recognizer locale is now picked deterministically**, preferring an Egyptian model if Apple ever ships one, then `ar-SA`, instead of taking whatever the unordered `supportedLocales()` set returned first. Apple offers only `ar-SA` for Arabic today, in both the old and the new Speech API, which is the real ceiling on Egyptian-dialect accuracy.

---

## [Unreleased] - 2026-09-18d (water logs, brand names, iOS 27 vision)

### Added
- **Water is a hydration log wherever it is recognised.** Both engines now report an explicit `waterML` amount (new field in the cloud JSON contract and in the on-device guided-generation schema, plus a hydration rule that keeps calories, macros and items at zero), and every save path routes a water answer into `WaterEntry` and the AI journal instead of the food log: voice bar, text bar, camera, multimodal sheet, and both Siri intents. The two records share one id, so deleting either clears both, and hydration never spends a free AI scan.
- **Apple's on-device model reads photos on iOS 27** (image attachments in a `LanguageModelSession`, capped at two photos for the 4K context window), so photo logs now try Apple's engine before the cloud.
- **Private Cloud Compute as a second Apple stage**, behind the `soma_private_cloud_ai` default (off until the entitlement is assigned). It is skipped when the local attempt timed out, so it cannot stack delay on a busy device.
- **Brand and venue awareness in the shared prompt**: known Egyptian venues, chains and delivery apps with their dictation confusions (بريد فاست arriving as "breakfast" or "bread fast", كوك دور as "cook door"), so a brand lands in `location` and never replaces the meal.

### Changed
- **Water spellings widened in the on-device parser**: مياه، مايه، ميّه، موية، كوبايتين and friends now parse as hydration instead of falling through to the meal path.
- **The engine status tells the truth about languages.** Apple Intelligence does not support Arabic yet, so an Arabic app language reads "Apple Intelligence does not support Arabic yet, so logs go to the cloud" instead of promising local-first analysis, and Arabic logs skip the local attempt (Apple throws `unsupportedLanguageOrLocale` for them) and go straight to the cloud.
- `AIMealEntry` gained `waterML`, so the journal and the entry screen can tell a glass of water from a zero-calorie meal.

### Fixed
- **A water log phrased in a way the local parser missed landed in the food log** as a zero-calorie meal titled like water. Fixed at the source: the engines report the water amount, and every logging path saves it as hydration.

---

## [Unreleased] - 2026-09-18d (History protein filter)

### Fixed
- **A meal that carried protein reported as no protein in History.** The Protein filter only listed protein-type logs (shakes, "40 protein" entries), so a logged Big Mac said "No protein logs for this day" even though its 25g appeared under Food and counted towards the daily total. The Protein filter now lists every entry that contributed protein. Its header stays a plain "Protein", since the card above already carries the day's total. The All view and the edit sheet are unchanged: a meal is still a meal, and editing it still edits calories rather than grams.

---

## [Unreleased] - 2026-09-18c (on-device analysis, cloud as second opinion)

### Added
- **On-device meal analysis on iOS 26 and later.** Apple's Foundation Models framework now answers text and voice logs first, with guided generation (`@Generable`) replacing hand-parsed JSON. Verified against the installed SDK (`SystemLanguageModel`, `LanguageModelSession`, `respond(to:generating:)`) and the framework is weak-linked, so the iOS 17.6 deployment target is untouched.
- **The cloud is now the second opinion, not the default.** It takes over when this iPhone cannot run the on-device model, when a photo is involved, when a local answer takes longer than 2.5 seconds, or when the local answer fails its numeric checks (calories must match the macro breakdown within 25%, plausible macro ranges, non-empty title). Photos always use the cloud, which reads a plate better.
- **Analysis engine switch** in Settings, AI and Siri, with live device status. Turning it off restores cloud-first behaviour exactly, making the whole change reversible from the UI without a rebuild.
- `SomaAIPrompts`, one source of truth for the Egyptian-Arabic nutrition rules, shared by both engines so they cannot drift. The extracted text is byte-identical to the prompt that shipped, verified against the committed source.

### Changed
- `AIMealAnalysisResult` records which engine produced it: the cloud, Apple's on-device model, or the offline keyword fallback, so an unreachable-cloud message only appears when that is actually true.

---

## [Unreleased] - 2026-09-18b (fake hydration logs, honest failures, paywall text)

### Fixed
- **Voice logs could turn into a fake "Hydration (250 ml)" entry.** Two causes: the water branch re-read the AI's own narrative for water words, and the on-device pre-check treated any sentence containing a water word as hydration, so a meal like "شربت مية مع الكشري" was swallowed into a default glass without the AI ever being called. The parser now only reports hydration when the sentence names no real food, the post-analysis branches are gone entirely, and "2 كوباية مية" is two cups (500 ml) instead of 2 ml. Verified with a 12-case harness compiled against the real parser.
- **A failed AI call no longer looks like the food was missing.** The analysis result now carries which engine produced it, so when the cloud call fails and the on-device fallback finds nothing either, the user sees "Couldn't reach Soma AI. Please try again." instead of "No food or drink detected."
- **The Annual plan subtitle was truncated** to "EGP 50.00 / mo · Billed annua...". It is now two deliberate lines, "EGP 50.00 / mo" over "Billed annually", so the monthly equivalent and the billing cadence both stay visible and neither can ellipsize. Subtitles wrap instead of truncating and the price column keeps its width.

---

## [Unreleased] - 2026-09-18 (speed, reminders, Apple Health)

### Fixed
- **AI scans were slow because of which models were tried first.** Measured against the live proxy: the two full Flash models returned HTTP 503 on 4 of 5 attempts (about 4.5s per miss while Google sheds load), and a Flash answer burned 500-900 thinking tokens for 5-15s. The cascade is now Flash-Lite only, which answers a meal photo or a text log in about 1.5s with no thinking tokens at all, and the per-attempt timeout dropped from 25s to 12s.
- **Location no longer delays a log.** Reverse geocoding ran before the entry was written, adding a network round trip to every AI log. The entry now saves first and the resolved location is patched in behind it.
- **A History edit could fail silently.** The edit sheet used `try? modelContext.save()` and dismissed as if the change had landed. A failure now keeps the sheet open with the edited values and explains what happened.
- **Siri could report a log that never saved.** All three App Intents used `try? context.save()` and answered "Logged ..." regardless. They now answer "Soma couldn't save that. Please try again." when the write fails.
- **The reminders toggle could lie.** Permission revoked in iOS Settings left the toggle ON with nothing scheduled. Permission is now re-checked on every activation.
- **The AI entry editor's save was silent**; the edit stays in the context and a failure is logged rather than swallowed.

### Added
- **Reminders are now actually offered.** A one-time opt-in appears after onboarding, in Soma's own onboarding style, before iOS's system dialog can appear cold in the middle of a log.
- **Apple Health write-back.** Calories, protein, carbs, fat and water appear in Health as they are logged, including Siri logs. Samples carry a Soma marker, so editing or deleting an entry replaces exactly its own data and Reset All Data clears only what Soma wrote. Added `NSHealthUpdateUsageDescription`.
- **Manage Subscription** in Settings for active subscribers, opening Apple's own subscription sheet.

### Changed
- Gemini routing is Flash-Lite first: `gemini-3.5-flash-lite`, then the `gemini-flash-lite-latest` alias, then the on-device engine.
- Health authorization now requests the dietary write types alongside the read-only step count.

---

## [Unreleased] - 2026-09-17 (v1.0 release readiness)

### Fixed
- **Duplicate logging and double AI-scan charges**: every analysis entry point (voice, text, camera, multimodal sheet) could run a second analysis on top of a running one. All paths now guard on the in-flight state.
- **Silent data loss**: logging paths used `try? modelContext.save()` and then showed a success toast. Saves are now checked, failures surface a real error, and a failed save no longer consumes a free AI scan.
- **Hydration no longer spends an AI credit**: water is parsed on-device before any cloud call, and the voice-hydration path consumes no scan (it was previously inconsistent with the text path).
- **Captured photo survives the paywall**: the shot is kept until the analysis actually starts, and it is analysed as soon as the user returns from the paywall.
- **Water unit conversion in the Log sheet**: imperial users entered fl oz but the value was stored as ml (an 8 fl oz glass stored as 8 ml). The sheet now converts and labels per `UnitSystem`.
- **Water sheet totals**: same-day entries are summed across all `DailyLog` rows instead of reading only the first match, and the water goal uses `@Query` instead of a fetch per render.
- **Reset All Data**: a failed save no longer drops the user into onboarding on top of surviving data (which created a second profile), and reminders are turned off with the reset instead of leaving the toggle ON with nothing scheduled.
- **Notification permission dead-end**: toggling reminders on after permission was denied now explains the state and offers a route to iOS Settings.
- **Food database alias shadowing**: the most specific alias now wins, so "black coffee" no longer matches Iced Latte and "chicken caesar salad" no longer matches the plain grilled chicken entry.
- **Export date range**: a future-dated log (manual clock change, travel) could invert the picker range and trip a SwiftUI precondition; the start date is now clamped.
- **CSV export dates** are pinned to the Gregorian calendar and `en_US_POSIX` instead of following the user's locale and calendar.
- **Sheet dismissal**: dismissing the multimodal sheet mid-analysis no longer writes an entry the user never saw, and discarded recordings are removed from disk.

### Changed
- **Subscription pricing set for launch**, per storefront: EGP 29.99 / 69.99 / 599.99, AED and SAR 12.99 / 19.99 / 149.99, USD $2.99 / $7.99 / $39.99, EUR €3.49 / €8.99 / €44.99 (weekly / monthly / yearly). No introductory offers.
- **Paywall prices are storefront-aware**: StoreKit's localized price wins, and until products load the fallback table quotes the correct currency for the user's storefront instead of a hardcoded USD figure. The yearly "save X%" badge is now computed from the real weekly and yearly prices.
- **Free AI allowance raised from 3 to 15 scans** per install, with a one-time top-up applied to existing installs so nobody is left on the old balance.
- **Shared persistence**: the SwiftData schema and container now live in one place (`SomaPersistence`) used by both the app and App Intents, instead of each intent building its own container over the same store.
- **Pro status is cached**: a paying subscriber no longer briefly looks free at cold launch, and Siri no longer answers "Subscription Required" before StoreKit resolves.
- **Gemini routing**: the attempt list was capped so a miss costs a few seconds instead of a multi-minute wait (the model order itself was revised on 2026-09-18 after measuring the live proxy).
- **Paywall**: prices come from StoreKit only (the intended price is shown until products load), the plan rows can no longer push the sheet wider than the screen, and purchase/restore failures surface an alert instead of tapping Continue doing nothing silently.
- Photo analysis downscales to 1024 px before upload, cutting the base64 payload by roughly 10x.
- Siri water logging clamps the spoken amount to a plausible range.

### Security
- Cloud AI server error bodies are no longer written to logs in release builds (status code only).
- The privacy manifest now declares Photos or Videos and Other User Content, matching what the AI features send off-device.

### Added
- `com.apple.developer.healthkit.background-delivery` entitlement, so health background delivery actually succeeds.
- `ITSAppUsesNonExemptEncryption = NO` for the App Store upload questionnaire.

### Removed
- `SomaProducts.storekit` and `Secrets.xcconfig.template` no longer ship inside the app bundle.
- Dead code: `InteractivePopGesture.swift`, `saveNutritionResult`, `currentLog`, `activeLog`/`todayLog`, `profileInitials`, `effectiveCount`, and the paywall's hardcoded `priceDescription`.

---

## [Unreleased] - 2026-08-30

### New Features & Engine Updates
- **Tactile Haptic Feedback Suite**:
  - `LogSheetView`: Category switching (`UISelectionFeedbackGenerator`), numeric keypad & backspace (`UIImpactFeedbackGenerator(.light)`), clear action (`UIImpactFeedbackGenerator(.medium)`), and successful save (`UINotificationFeedbackGenerator(.success)`).
  - `HistoryView`: Category filter tabs (`UISelectionFeedbackGenerator`) and swipe-to-delete row action (`UIImpactFeedbackGenerator(.medium)`).
  - `SettingsView`: Goal updates (`UINotificationFeedbackGenerator(.success)`) and full data reset (`UINotificationFeedbackGenerator(.warning)`).
  - `SomaSegmentedToggle`: Remaining / Consumed mode toggle switch (`UISelectionFeedbackGenerator`).
- **Mode-Aware Dynamic Step Count**:
  - Home screen step card dynamically recalculates between Remaining mode (`max(dailyStepGoal - totalStepsTaken, 0)`) and Consumed mode (`totalStepsTaken`) with `.contentTransition(.numericText())` and subtitle cross-fading.
- **Enriched CSV Data Export (`DataExporter.swift`)**:
  - Itemized food breakdown (calories, protein, carbs, fat, custom descriptions) and individual hydration entries with resolved timestamps and time-of-day contextual labels (e.g., `Morning Hydration: 500 ml`, `Night Hydration: 200 ml`).
- **Macro Calculation & Dynamic Effective Calories (`FoodEntry.swift`)**:
  - Added support for Carbs (`carbsG`) and Fat (`fatG`) tracking with automatic minimum calorie resolution derived from macronutrient energy densities ($4\text{ kcal/g}$ protein, $4\text{ kcal/g}$ carbs, $9\text{ kcal/g}$ fat).
- **Interactive Daily Notification Pickers (`SettingsView.swift`)**:
  - Replaced static reminder cells with native `.datePickerStyle(.compact)` time wheel pickers bound to `dailyReminderTime` and `eveningReminderTime` in `NotificationManager`.

### UI, UX & HIG Polish
- **Log Entry Modal Sheet Refactoring (`LogSheetView.swift`)**:
  - **Native Navigation**: Embedded in `NavigationStack` with an app-wide standard `.glassEffect(.regular, in: .circle)` Liquid Glass `✕` close button and top-left alignment.
  - **Keyboard Accessory Toolbar**: Integrated `.keyboard` toolbar with a "Done" button to dismiss the system keyboard when entering optional descriptions.
  - **Clean Hero Display**: Centered hero value (`64pt .bold.rounded.monospacedDigit()`) paired with trailing unit label, eliminating redundant micro-badge pills.
  - **Borderless Inline Description**: Clean, transparent inline input with `Color(.tertiaryLabel)` placeholder and `@FocusState` binding.
  - **Category Chips**: High-contrast labels (`Color(.label).opacity(0.85)`) and updated fitness glyph for Protein (`figure.strengthtraining.traditional`).
  - **Keypad & CTA**: 4×3 grid with `00` quick entry, 14pt rounded cells, and unified 54pt continuous Save action button.
  - **Solid Opaque Background**: Configured `.presentationBackground(Color(.systemBackground))` and `.presentationDetents([.fraction(0.78), .large])` with a visible drag indicator.
- **Export History Modal Polish (`ExportDatePickerSheet.swift`)**:
  - Eliminated text truncation with compact segment tokens `["All", "7D", "30D", "Month", "Custom"]`.
  - Native `.datePickerStyle(.compact)` date range pickers and solid `.presentationBackground(Color(.systemGroupedBackground))`.
  - Taller presentation detent `.presentationDetents([.fraction(0.70), .large])` to display full preview card and CTA without scrolling.
  - Fixed circular preset selection event loop with a state-locking guard flag.
- **Context-Aware History Navigation (`HistoryView.swift`)**:
  - Added `isModal: Bool` parameter. When presented as a modal sheet from Home, displays the Liquid Glass `✕` button; when pushed in Settings via `NavigationLink`, displays only the native `< Back` button.

### App Store Compliance
- **Purged External Donation Links**:
  - Completely removed the "Buy Me a Coffee" section and external link from `SettingsView.swift` and `SomaColors.swift` in full compliance with Apple App Store Review Guideline 3.1.1 (In-App Purchase).

---

## [0.3.0] - 2026-08-29

### New Features
- **Log History & Timeline (`HistoryView.swift`)**:
  - Full chronological timeline of daily food logs, water intake, and synced steps.
  - Real-time instant search matching dates, partial food titles, calorie ranges, and habits.
  - Category filter tabs (`All`, `Food`, `Water`, `Steps`) for one-tap log filtering.
  - Active habit summary strip on day cards showing only recorded habits, hiding empty metrics.
  - Swipe-to-delete for historical food and water entries with automatic SwiftData recalculation.
- **Streaks & Milestone Engine (`StreakCalculator.swift`)**:
  - Daily consecutive logging calculation with historical Best Streak tracking.
  - Glowing amber milestone banner in the History screen.
- **Data Export & Date Picker (`DataExporter.swift`, `ExportDatePickerSheet.swift`)**:
  - RFC-4180 compliant CSV export of logged health data with custom date ranges.
  - Date picker modal with presets (*All Time, 7 Days, 30 Days, This Month, Custom*), matching log count preview, and native iOS share sheet.
  - Formatted export filename: `Soma_History_Export_(Date).csv`.
- **AI Tab Navigation (`AIView.swift`)**:
  - Added dedicated AI Assistant tab with native sparkles icon in the floating liquid glass dock.
- **Rolling Number Counters (Odometer Effect)**:
  - Added `.contentTransition(.numericText())` with snappy spring transitions across the hero calorie counter and the 2×2 stats grid.

### UI & UX Improvements
- **Settings Screen Revamp (`SettingsView.swift`)**:
  - Native iOS `.insetGrouped` list structure with collapsible title.
  - Apple Health-style semantic color hierarchy: Coral (`#FF5C39`) for Calories, Aqua (`#1EA8E6`) for Water, Iris (`#7C5CFC`) for Protein, Amber (`#FF9500`) for History/Streaks, and Emerald (`#10B981`) for Data Export.
  - Multi-tone Navy & Iris gradient avatar with dynamic user initials.
  - Tap-to-edit alerts for goal adjustments and anchored reset confirmation.
- **Onboarding Flow Polish (`SplashView.swift`, `NameInputView.swift`, `BodyStatsView.swift`, `GoalsInputView.swift`)**:
  - Reordered Splash screen layout with centered cat illustration and thumb-reachable bottom CTA.
  - Resolved subtitle text truncation bugs across all step screens.
  - Added top navigation glass back buttons to allow stepping backward during setup.
  - Upgraded body stats icon to `figure.arms.open` and converted Gender to a clean picker.
  - Set root navigation canvas background to solid navy to eliminate split-second corner flash during page transitions.
- **Home View & Weekly Chart Polish (`HomeView.swift`, `WeeklyBarChart.swift`)**:
  - Added interactive swipe-up drag gesture with expanding grabber and spring release.
  - Added tap protection on empty chart bars (`0 kcal`) so zero-data days are not highlighted.
  - Fully unclipped tooltip pills to preserve smooth continuous rounded corners.
  - Native liquid glass button styling with scale spring compression.

---

## [0.2.0] - 2026-06-05

### New Features & Refactoring
- **Weekly Chart Empty Day Slots (`WeeklyBarChart.swift`)**:
  - Empty days render a fixed-height faint capsule (7pt, white 12%) to signal an existing slot without competing with logged data.
- **Responsive Layout Support**:
  - Scaled home stats content dynamically to screen height to prevent Water/Steps cards from clipping behind the floating dock on shorter devices (iPhone 11 / SE).
- **Notification Engine Refactoring (`NotificationManager.swift`)**:
  - Unified `scheduleReminder` helper for daily and end-of-day reminders.
  - Fixed stale doc comments and background scheduling lifecycle handlers.

---

## [0.1.0] - 2026-06-04

### Initial Release & Core Foundations
- **Core Tracking Engine (SwiftData)**:
  - Persistent data models for `DailyLog`, `FoodEntry`, `WaterEntry`, and `UserProfile`.
  - Daily calorie intake vs. target calculations, water logging, and step tracking.
- **Liquid Glass Interface & Navigation**:
  - Custom floating dock navigation bar with translucent blur and spring transitions.
  - Interactive weekly calorie trend bar chart.
- **Lottie Splash & Onboarding**:
  - DotLottie integration featuring animated mascot on the splash screen.
  - Multi-step onboarding flow for profile, body metrics, and goal definitions.
- **Unit System & Localization**:
  - Metric / Imperial unit switching with dynamic conversion across water and body stats.
- **Notifications**:
  - Local push reminders for morning hydration and end-of-day logging.
