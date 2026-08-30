# Changelog

All notable changes to Soma will be documented in this file.

## [Unreleased] - 2026-08-30

### ✨ New Features & Engine Updates
- **Tactile Haptic Feedback Suite**:
  - `LogSheetView`: Category switching (`UISelectionFeedbackGenerator`), numeric keypad & backspace (`UIImpactFeedbackGenerator(.light)`), clear action (`UIImpactFeedbackGenerator(.medium)`), and successful save (`UINotificationFeedbackGenerator(.success)`).
  - `HistoryView`: Category filter tabs (`UISelectionFeedbackGenerator`) and swipe-to-delete row action (`UIImpactFeedbackGenerator(.medium)`).
  - `SettingsView`: Goal updates (`UINotificationFeedbackGenerator(.success)`) and full data reset (`UINotificationFeedbackGenerator(.warning)`).
  - `SomaSegmentedToggle`: Remaining / Consumed mode toggle switch (`UISelectionFeedbackGenerator`).
- **Mode-Aware Dynamic Step Count**:
  - Home screen step card dynamically recalculates between Remaining mode (`max(dailyStepGoal - totalStepsTaken, 0)`) and Consumed mode (`totalStepsTaken`) with `.contentTransition(.numericText())` and subtitle cross-fading.
- **Enriched CSV Data Export (`DataExporter.swift`)**:
  - CSV generation itemizes food entries (calories, protein, carbs, fat, descriptions) and individual hydration entries with resolved timestamps and custom labels (e.g. `Night Hydration: 200 ml`).
- **Interactive Daily Notification Pickers (`SettingsView.swift`)**:
  - Replaced static reminder cells with native `.datePickerStyle(.compact)` time wheel pickers bound to `dailyReminderTime` and `eveningReminderTime` in `NotificationManager`.

### 🎨 UI, UX & HIG Polish
- **Log Entry Modal Sheet Refactoring (`LogSheetView.swift`)**:
  - **Native Navigation**: Embedded in `NavigationStack` with an app-wide standard `.glassEffect(.regular, in: .circle)` Liquid Glass `✕` close button and top-left alignment.
  - **Keyboard Accessory Toolbar**: Integrated `.keyboard` toolbar with a "Done" button to dismiss the system keyboard when entering optional descriptions.
  - **Clean Hero Display**: Centered hero value (`64pt .bold.rounded.monospacedDigit()`) paired with trailing unit label, eliminating redundant micro-badge pills.
  - **Borderless Inline Description**: Clean, transparent inline input with `Color(.tertiaryLabel)` placeholder and `@FocusState` binding.
  - **Category Chips**: High-contrast labels (`Color(.label).opacity(0.85)`) and updated fitness glyph for Protein (`figure.strengthtraining.traditional`).
  - **Keypad & CTA**: 4×3 grid with `00` quick entry, 14pt rounded cells, and unified 54pt continuous Save action button.
  - **Solid Opaque Background**: Set `.presentationBackground(Color(.systemBackground))` and `.presentationDetents([.fraction(0.78), .large])` with a visible drag indicator.
- **Export History Modal Polish (`ExportDatePickerSheet.swift`)**:
  - Truncation elimination with compact segment tokens `["All", "7D", "30D", "Month", "Custom"]`.
  - Native `.datePickerStyle(.compact)` date range pickers and solid `.presentationBackground(Color(.systemGroupedBackground))`.
  - Taller presentation detent `.presentationDetents([.fraction(0.70), .large])` to display full preview card and CTA without scrolling.
  - Fixed circular preset selection event loop with state-locking guard flag.
- **Context-Aware History Navigation (`HistoryView.swift`)**:
  - Added `isModal: Bool` parameter. When presented as a modal sheet from Home, displays the Liquid Glass `✕` button; when pushed in Settings via `NavigationLink`, displays only the native `< Back` button.

### 🛡️ App Store Compliance
- **Purged External Donation Links**:
  - Completely removed the "Buy Me a Coffee" section and external link from `SettingsView.swift` and `SomaColors.swift` in full compliance with Apple App Store Review Guideline 3.1.1 (In-App Purchase).
