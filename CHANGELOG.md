# Changelog

All notable changes to Soma will be documented in this file.

## [Unreleased] - 2026-08-30

### ✨ New Features
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
  - Added `.contentTransition(.numericText())` with snappy spring transitions across the hero calorie counter and the 2x2 stats grid.

### 🎨 UI & UX Improvements
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
