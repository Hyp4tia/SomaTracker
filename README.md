# Soma

**Soma** (ⲥⲱⲙⲁ - Coptic for "body") is a native iOS health tracker that keeps things simple: calories, protein, water, and steps - fast, private, and distraction-free.

## Overview

No backend account to manage. Soma stores your daily history and metrics locally on-device using SwiftData, and pulls step data automatically from Apple Health via HealthKit. Meal logging is multimodal: type it, say it, or photograph it, and Soma AI estimates the nutrition. Cloud analysis goes through a Cloudflare Worker proxy, so no API key ever ships inside the app.

## Features

- Calorie tracking with a Remaining / Consumed toggle and rolling odometer counters
- Water intake logging (customizable unit values in ml / fl oz)
- Protein tracking
- Steps auto-synced from HealthKit
- Weekly interactive bar chart with live tooltips
- Chronological Log History with live prefix search, category filter tabs, and swipe-to-delete
- Daily Streaks & Best Streak record calculator
- Data export to CSV with interactive date range picker sheet
- AI health assistant tab: voice memos, camera photos, and quick text logging with an AI Journal
- Siri & Action Button intents (`Log Water`, `Log Meal`, `Snap Meal Photo`, `Record Voice Meal`)
- Soma Pro subscription (StoreKit 2) with a free AI scan allowance
- Native iOS system chrome (materials, navigation, tab bar) with Soma's own navy and white brand styling
- On-device SwiftData storage with secure cloud multimodal AI meal analysis

## Tech Stack

- **Swift 5 language mode / SwiftUI**
- **SwiftData** - local persistence, no backend
- **HealthKit** - step reads (background delivery enabled)
- **StoreKit 2** - subscriptions
- **App Intents** - Siri, Shortcuts, and Action Button
- **Cloudflare Worker proxy** - protects the Gemini API key (see `Config/APISecrets.template.swift`)
- **Minimum target: iOS 17.6**, iPhone only, built with the current Xcode SDK

## Architecture

- `AppRouter` / `TabRouter` / `TabBarCoordinator` - navigation & tab routing
- `SomaPersistence` - the single `Schema` + `ModelContainer` shared by the app and App Intents
- `HealthKitManager` - `@Observable` wrapper around HealthKit reads
- `StreakCalculator` - consecutive logging streak engine
- `DataExporter` - RFC-4180 CSV export service
- `AIRouter` - routes between the cloud (Gemini via proxy) and the on-device food engine
- `FoodNutritionDatabase` - offline parser for Arabic/English food, water, calorie, and protein input
- Core SwiftData models covering tracked metrics (`DailyLog`, `FoodEntry`, `WaterEntry`, `AIMealEntry`, `UserProfile`)

## Screens

| Screen | Purpose |
|---|---|
| Splash | App launch with hero illustration and bottom CTA |
| Onboarding | Step 1 Name → Step 2 Body Stats → Step 3 Goals |
| Home | Weekly chart, hero calorie number, stats grid, quick-log |
| History | Chronological activity feed, search, category filters, streak card |
| AI | Voice memo recorder, camera logging, AI Journal, insights |
| Settings | Profile, daily goals, units, reminders, CSV export, contact |
| Profile | User body stats & info edit |

## Design Language

- Dark navy (`#23225C`) top section with weekly bar chart
- White bottom sheet with hero calorie number and stats grid
- Semantic metric colors: Coral (`#FF5C39`) calories, Aqua (`#1EA8E6`) water, Iris (`#7C5CFC`) protein, Emerald (`#10B981`) steps, Amber (`#FF9500`) streaks
- Three-tab dock: Home · AI · Settings with a floating capsule
- Ghost bars (`white @ 12% opacity`) for empty chart days with tap protection

## Requirements

- Xcode 27 or newer (the project uses a file-system synchronized group)
- iOS 17.6+ device or simulator
- A paid Apple Developer account for App Store submission

## Setup

```bash
git clone <this repo>
cd SomaTracker
open SomaTracker.xcodeproj
```

`Config/APISecrets.swift` is git-ignored and **required for the app target to compile**. Create it from the template before your first build:

```bash
cp SomaTracker/Config/APISecrets.template.swift SomaTracker/Config/APISecrets.swift
```

Then fill in the proxy client secret (matching the `SOMA_APP_SECRET` value on the Cloudflare Worker) and, only if you intend to bypass the proxy, a Gemini API key.

`SomaProducts.storekit` is a local StoreKit testing configuration. It is excluded from the app target, so it ships nothing to users.

## Privacy

- Meals, macros, water, streaks, and profile data live only in the app's SwiftData store on your device.
- Steps are read from Apple Health; Soma never writes to Health.
- When you use a cloud AI feature, the meal photo, your text note, and the voice transcript are sent through the Cloudflare Worker proxy to Google's Gemini API to estimate nutrition. Nothing else leaves the device, no account is created, and no analytics or ad SDKs are included.
- The privacy manifest (`PrivacyInfo.xcprivacy`) declares Photos or Videos and Other User Content for app functionality, not linked to identity and not used for tracking.

## Status

Pre-release v1.0: core tracking (calories, protein, water, steps, streaks, history, export, AI logging, subscriptions, Siri intents) is complete. Remaining before submission: hosted privacy policy and support URLs, App Store Connect subscription products, and a test target.

## Bundle ID

`com.hyp4tia.soma` - locked after first App Store submission.

## License

This project is licensed under the GNU General Public License v3.0 with an Apple App Store Exception. See the [LICENSE](LICENSE) file for details.
