# Soma

**Soma** (ⲥⲱⲙⲁ — Coptic for "body") is a native iOS 26 health tracker that keeps things simple: calories, water, protein, and steps — nothing more, nothing synced to a server.

## Overview

No backend. No authentication. No accounts to manage. Soma stores everything locally on-device using SwiftData, and pulls step data automatically from Apple Health via HealthKit. It's built for people who want a fast, private, distraction-free way to log their day.

## Features

- 🔥 Calorie tracking with a Remaining / Consumed toggle
- 💧 Water intake logging (250ml per unit)
- 🥩 Protein tracking
- 🚶 Steps auto-synced from HealthKit
- 📊 Weekly bar chart overview
- 🎨 iOS 26 Liquid Glass UI throughout
- 🔒 100% local storage — no data ever leaves the device

## Tech Stack

- **Swift 6 / SwiftUI**
- **SwiftData** — local persistence, no backend
- **HealthKit** — steps auto-sync
- **iOS 26** minimum target, Liquid Glass design system

## Architecture

- `AppRouter` / `TabRouter` — navigation
- `HealthKitManager` — `@Observable` wrapper around HealthKit reads
- Four core SwiftData models covering the app's tracked metrics

## Screens

| Screen | Purpose |
|---|---|
| Splash | App launch |
| Onboarding | Name → Body Stats → Goals |
| Home | Weekly chart, hero calorie number, stats grid, quick-log |
| Settings | Preferences, Buy Me a Coffee, Contact |
| Profile | User info |

## Design Language

- Dark navy (`#23225C`) top section with weekly bar chart
- White bottom sheet with hero calorie number and stats grid
- Three-tab dock: Home · raised circular **+** · Settings
- Liquid Glass capsule nav bar + separate Liquid Glass **+** button
- Ghost bars (`white @ 12% opacity`) for empty chart days

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

Both are required — HealthKit code will fail without them, and Apple will reject submissions missing either.

## Status

🚧 In active development (pre-release). Core data models, HealthKit integration, and navigation are complete. UI screens are in progress.

## Bundle ID

`com.zeyad.soma` — locked after first App Store submission.

## License

All rights reserved. *(Update this if you intend to open-source it.)*

## Contact

Built by Zeyad. Reach out on [X](https://x.com/) *(update with your handle)*.
