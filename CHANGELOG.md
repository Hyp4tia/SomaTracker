# Changelog

All notable changes to **Soma** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
