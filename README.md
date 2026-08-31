# Soma

**Soma** (ⲥⲱⲙⲁ - Coptic for "body") is a native iOS 26 health tracker that keeps things simple: calories, water, protein, and steps - nothing more, nothing synced to a server.

## Overview

No backend. No authentication. No accounts to manage. Soma stores everything locally on-device using SwiftData, and pulls step data automatically from Apple Health via HealthKit. It's built for people who want a fast, private, distraction-free way to log their day.

## Features

- Calorie tracking with a Remaining / Consumed toggle and rolling odometer counters
- Water intake logging (customizable unit values in ml / fl oz)
- Protein tracking
- Steps auto-synced from HealthKit
- Weekly interactive bar chart with live tooltips
- Chronological Log History with live prefix search, category filter tabs, and swipe-to-delete
- Daily Streaks & Best Streak record calculator
- Data export to CSV with interactive date range picker sheet
- AI health assistant tab with contextual suggestions
- iOS 26 Liquid Glass UI and semantic metric color hierarchy
- 100% local storage - no data ever leaves the device

## Tech Stack

- **Swift 6 / SwiftUI**
- **SwiftData** - local persistence, no backend
- **HealthKit** - steps auto-sync
- **iOS 26** minimum target, Liquid Glass design system

## Architecture

- `AppRouter` / `TabRouter` - navigation & tab routing
- `HealthKitManager` - `@Observable` wrapper around HealthKit reads
- `StreakCalculator` - consecutive logging streak engine
- `DataExporter` - RFC-4180 CSV export service
- Core SwiftData models covering tracked metrics (`DailyLog`, `FoodEntry`, `WaterEntry`, `UserProfile`)

## Screens

| Screen | Purpose |
|---|---|
| Splash | App launch with hero illustration and bottom CTA |
| Onboarding | Step 1 Name → Step 2 Body Stats → Step 3 Goals |
| Home | Weekly chart, hero calorie number, stats grid, quick-log |
| History | Chronological activity feed, search, category filters, streak card |
| AI | AI health assistant, insights, and quick questions |
| Settings | Profile, daily goals, units, reminders, CSV export, contact |
| Profile | User body stats & info edit |

## Design Language

- Dark navy (`#23225C`) top section with weekly bar chart
- White bottom sheet with hero calorie number and stats grid
- Semantic metric colors: Coral (`#FF5C39`) calories, Aqua (`#1EA8E6`) water, Iris (`#7C5CFC`) protein, Emerald (`#10B981`) steps, Amber (`#FF9500`) streaks
- Three-tab dock: Home · AI · Settings with floating Liquid Glass capsule
- Ghost bars (`white @ 12% opacity`) for empty chart days with tap protection

## Requirements

- Xcode (iOS 26 SDK)
- iOS 26+ device or simulator
- Apple Developer account (free tier works for local testing; paid required for App Store submission)

## Setup

```bash
git clone https://github.com/<your-username>/soma.git
cd soma
open Soma.xcodeproj
```

Before building, make sure `Info.plist` includes:

- `NSHealthShareUsageDescription`
- `NSMotionUsageDescription`

Both are required - HealthKit code will fail without them, and Apple will reject submissions missing either.

## Status

In active development (pre-release). Core data models, HealthKit integration, streak engine, history timeline, data exporter, and navigation are complete.

## Bundle ID

`com.zeyad.soma` - locked after first App Store submission.

## License

This project is licensed under the GNU General Public License v3.0 with an Apple App Store Exception. See the [LICENSE](LICENSE) file for details.

## Contact

Built by Hyp4tia. Reach out on [X / Twitter](https://x.com/Hypatox)
