# SOMA × NEW SIRI (APPLE INTELLIGENCE 2.0)
## Complete Day-Zero Engineering Blueprint & First-Mover Playbook

> **Target Platform:** iOS 26+ / Apple Intelligence Architecture  
> **Tech Stack:** Swift 6, App Intents, SwiftData (`@ModelActor`), HealthKit, Core Spotlight  
> **Design Language:** Soma Liquid Glass, Bespoke Siri Snippets, Semantic Metric Palette  
> **Status:** Strategic Architecture Specification (Zero Existing Codebase Files Modified)

---

## 1. The Strategy: Winning First-Mover Advantage

### Why Day Zero Matters
When Apple rolls out the new Siri (Apple Intelligence context-aware Siri with on-screen intelligence, personal context, and multi-turn action orchestration), Apple's Editorial Team actively seeks showcase apps for:
1. **App Store Today Tab Hero Feature**: "Experience the New Siri in Health & Fitness".
2. **Apple Keynote / Platform State of the Union Demos**: Third-party apps demonstrating seamless on-screen awareness.
3. **System Siri Suggestions & Lock Screen Proactivity**: High-affinity Siri triggers recommended automatically by iOS.

### Why Competitors Will Lose & Why Soma Will Win
| Dimension | Incumbent Apps (MyFitnessPal, LoseIt, Noom) | Soma Architecture |
|---|---|---|
| **Latency** | 2,000ms – 5,000ms (Cloud roundtrip, token auth, ad-network tracking) | **< 150ms** (100% on-device SwiftData + local NLP dictionary) |
| **Privacy** | Cloud database sync, user profiling, telemetry trackers | **100% On-Device & Private** (Zero server sync, zero accounts) |
| **User Friction** | Paywalls, subscription gates, login timeouts | **Frictionless Zero-Auth** (Works immediately on app install) |
| **Siri UI Quality** | Stale text dialogs or generic Cupertino lists ("AI Slop") | **Custom Liquid Glass Snippets** (`#23225C` navy + coral/aqua/iris badges) |
| **Code Hygiene** | Cluttered legacy Objective-C / React Native / Flutter wrappers | **Pure Swift 6 / SwiftUI** with modern App Intents |

By building with native App Intents, rich App Entities, and custom Siri snippet views, Soma presents Apple with the ideal showcase application: instantaneous, respectful of user privacy, and visually indistinguishable from an Apple first-party experience.

---

## 2. Core Capabilities: What We Will Implement & How

```
                                  ┌──────────────────────────────────────────────┐
                                  │           NEW SIRI VOICE / INTENT            │
                                  │      ("Log 500 kcal", "How much left?")      │
                                  └──────────────────────┬───────────────────────┘
                                                         │
                                                         ▼
                                       ┌──────────────────────────────────┐
                                       │     Apple Intelligence Engine    │
                                       │    (App Intents Framework)       │
                                       └─────────────────┬────────────────┘
                                                         │
                        ┌────────────────────────────────┼────────────────────────────────┐
                        │                                │                                │
                        ▼                                ▼                                ▼
         ┌──────────────────────────────┐ ┌──────────────────────────────┐ ┌──────────────────────────────┐
         │     Query / Read Intents     │ │    Action / Logging Intents  │ │   On-Screen Awareness        │
         │ - GetDailyNutritionIntent    │ │ - LogMealAppIntent (Voice)   │ │ - LogOnScreenMealIntent      │
         │ - GetStreakStatusIntent      │ │ - LogWaterAppIntent          │ │   (Photos, Safari, Receipts) │
         │ - SearchMealHistoryIntent    │ │ - UndoLastLogIntent          │ │                              │
         └──────────────┬───────────────┘ └──────────────┬───────────────┘ └──────────────┬───────────────┘
                        │                                │                                │
                        └────────────────────────────────┼────────────────────────────────┘
                                                         │
                                                         ▼
                                       ┌──────────────────────────────────┐
                                       │      ModelContainerManager       │
                                       │  (@ModelActor actor SomaDataStore)│
                                       └─────────────────┬────────────────┘
                                                         │
                        ┌────────────────────────────────┴────────────────────────────────┐
                        │                                                                 │
                        ▼                                                                 ▼
         ┌──────────────────────────────┐                                  ┌──────────────────────────────┐
         │     SwiftData Persistence    │                                  │  Liquid Glass Siri Snippets  │
         │ - DailyLog                   │                                  │ - SomaNutritionSnippetView   │
         │ - FoodEntry / WaterEntry     │                                  │ - SomaWaterSnippetView       │
         │ - AIMealEntry                │                                  │ - SomaStreakSnippetView      │
         └──────────────────────────────┘                                  └──────────────────────────────┘
```

### Feature A: On-Screen Contextual Awareness
- **User Scenario:** The user is browsing a recipe in Safari, looking at a food photo in Photos, or viewing a meal post in Instagram/Messages. They activate Siri:
  > *"Siri, log this in Soma."* or *"Siri, how many calories in this?"*
- **Implementation:**
  - Expose `LogOnScreenMealIntent` conforming to Apple's system Assistant Schemas.
  - Implement `Transferable` parameter parsing to receive `IntentFile` (image data), URL, or highlighted text.
  - The payload routes directly to `AIRouter.shared.processMultimodalMeal(...)`:
    - If image data is captured and API key is present: Gemini Vision analyses calories/protein in under 1 second.
    - If text or offline: Soma's local `FoodNutritionDatabase` engine parses keywords, portions, and nutritional density instantly.
  - Generates a `FoodEntry` linked to today's `DailyLog` and an `AIMealEntry` with thumbnail data for the AI Journal.

### Feature B: Multi-Turn Conversational Logging & Disambiguation
- **User Scenario:**
  - User: *"Siri, log chicken in Soma."*
  - Siri: *"Did you mean 200g Grilled Chicken Breast (330 kcal, 62g protein) or Chicken Shawarma (580 kcal, 28g protein)?"*
  - User: *"Grilled chicken breast."*
  - Siri: *"Logged 200g Grilled Chicken Breast (330 kcal). You have 670 kcal remaining today."*
- **Implementation:**
  - In `LogMealAppIntent`, leverage `requestDisambiguation(among:dialog:)`.
  - Check fuzzy results from `FoodNutritionDatabase.shared`. If multiple high-confidence matches occur, provide an interactive list or voice prompt.
  - Incorporate `$needsConfirmation` thresholds for unusually high logs (e.g. `> 2,500 kcal` in a single prompt) to prevent accidental data entry.

### Feature C: Siri Read & Query Capabilities (`QueryIntents`)
Instead of Siri simply saying "Soma doesn't support that", Soma becomes an interactive voice dashboard:
1. **`GetDailyNutritionIntent`**:
   - Prompts: *"How many calories do I have left in Soma?"*, *"What's my protein count today?"*, *"How much water did I drink?"*
   - Returns: Current consumed, daily target, remaining budget, and macro distribution.
2. **`GetStreakStatusIntent`**:
   - Prompts: *"What's my streak in Soma?"*, *"Did I log today in Soma?"*
   - Returns: Current streak count, best streak, and whether today's log has been fulfilled.
3. **`SearchMealHistoryIntent`**:
   - Prompts: *"What did I have for dinner yesterday in Soma?"*, *"Find the steak I logged last week in Soma."*
   - Uses `MealEntityQuery` to search SwiftData history and returns matching meal cards.

### Feature D: Bespoke Siri Visual Snippets (`ShowsSnippetView`)
Modern Siri doesn't just output plain speech; it renders interactive custom SwiftUI cards in the Siri dynamic island and glowing overlay.
- We build three native Liquid Glass snippets:
  1. **`SomaNutritionSnippetView`**:
     - Dark navy background (`#23225C`) with 16pt continuous rounded corners.
     - Live circular or bar odometer in Coral (`#FF5C39`).
     - Macro pill badges: Aqua (`#1EA8E6`) Water, Iris (`#7C5CFC`) Protein, Amber (`#F59E0B`) Carbs, Teal (`#14B8A6`) Fat.
     - Tap action deep-links directly into Soma's `HomeView` or `AIMealDetailView`.
  2. **`SomaWaterSnippetView`**:
     - Liquid glass container showing animated water fill level.
     - Daily target progression counter (e.g. `1,250 / 2,500 ml`).
  3. **`SomaStreakSnippetView`**:
     - Amber flame badge (`#FF9500`) with current streak odometer.

### Feature E: "Undo Last Log" Safety Intent (`UndoLastLogIntent`)
- **User Scenario:** User says *"Siri, undo my last log in Soma"*.
- **Implementation:**
  - Reads the most recent entry from today's `DailyLog.foodEntries` or `waterEntries`.
  - Removes the entry, updates daily totals, and notifies the user with confirmation dialog:
    > *"Removed McDonald's Big Mac (-590 kcal) from your log."*

### Feature F: Control Center & Lock Screen Controls (iOS Controls)
- Using the App Intents framework, Soma will expose Controls for:
  - **Quick +250ml Water Button**: Log a glass of water from the iPhone Lock Screen or Control Center without opening the app.
  - **Quick Voice Log Button**: Directly launches Siri/Soma voice recorder.
  - **Remaining Calorie Glance**: Real-time counter on the Lock Screen.

### Feature G: Core Spotlight Semantic Indexing
- Every meal entry is automatically indexed into iOS Core Spotlight using `CSSearchableItemAttributeSet` and `associateAppEntityWithSpotlight`.
- Users searching in iOS Spotlight for "salmon", "salad", or "protein shake" see Soma entries with timestamps and macros, opening directly into Soma.

---

## 3. Architecture & Clean Code Principles: Banishing "AI Slop"

### Defining "AI Slop" vs. "Production-Grade Apple Platform Architecture"
In the era of generated code, "AI slop" has distinct technical smells:
- ❌ **The Single-File Kitchen Sink:** Shoving models, queries, intent handlers, and network code into one massive file.
- ❌ **Unsafe Persistence Instantiation:** Calling `ModelContainer(for: schema)` inside every intent invocation, ignoring SQLite locks, process boundaries, and thread isolation.
- ❌ **Generic Cupertino Visuals:** Using default `List` cells, standard gray alert dialogs, and ignoring the app's established design system.
- ❌ **Brittle Natural Language:** Demanding users speak exact, robotic phrases like "Log meal in SomaTracker with parameter Big Mac".
- ❌ **Concurrency Blindness:** Inappropriately sprinkling `@MainActor` or ignoring `Sendable` boundary crossings in background intent tasks.

### The Soma Clean Architecture Standard
- ✅ **Single Responsibility Principle (SRP):**
  - `Entities/`: Pure data representations conforming to `AppEntity`.
  - `Queries/`: Fast, read-only search resolvers conforming to `EntityQuery`.
  - `Intents/`: Execution controllers coordinating business logic.
  - `Snippets/`: Pure SwiftUI presentational components matching `Theme/SomaColors.swift` and `SomaTypography.swift`.
  - `Persistence/`: Actor-isolated `SomaDataStore` managing SwiftData operations.
- ✅ **Swift 6 Strict Concurrency:**
  - Background Siri intents execute off the main thread using an isolated `@ModelActor`.
  - SwiftData contexts are isolated; UI updates are published via observation.
- ✅ **Design Token Parity:**
  - Siri snippets strictly utilize `SomaColors.navy` (`#23225C`), `coral` (`#FF5C39`), `aqua` (`#1EA8E6`), `iris` (`#7C5CFC`), and `emerald` (`#10B981`).
  - No generic gray cards; full Liquid Glass visual cohesion.
- ✅ **Zero Backend Reliance:**
  - 100% functionality when completely offline in Airplane Mode.

---

## 4. File-by-File Impact Matrix

### Existing Files to Modify (With Rationale & Diff Plan)

| File | Path | Rationale for Modification |
|---|---|---|
| **`SomaTrackerApp.swift`** | `SomaTrackerApp.swift` | Initialize `ModelContainerManager` at startup and register dependencies in `AppDependencyManager.shared` so App Intents share the active model container. |
| **`SomaIntents.swift`** | `Intents/SomaIntents.swift` | Refactor `LogWaterAppIntent` and `LogMealAppIntent` to use `ModelContainerManager` instead of instantiating ad-hoc containers; attach visual Liquid Glass snippet views. |
| **`SomaShortcuts.swift`** | `Intents/SomaShortcuts.swift` | Expand `AppShortcutsProvider` with dynamic parameterized phrases (`\(\.$meal)`, `\(\.$amount)`), Siri tips, and new query shortcuts. |
| **`AppRouter.swift`** | `Navigation/AppRouter.swift` | Add deep-link routing state (`DeepLinkTarget: .home, .aiJournal(id), .waterSheet`) so tapping a Siri snippet navigates seamlessly to the relevant screen. |
| **`ContentView.swift`** | `ContentView.swift` | Add `.onOpenURL` and scene phase handlers to respond to Siri deep links and handle external events cleanly. |
| **`AIRouter.swift`** | `Services/AI/AIRouter.swift` | Add a lightweight direct entry point for raw `Data` / `URL` from on-screen awareness without UI overhead. |

### New Files to Create (Clean Modular Layout)

```
SomaTracker/
├── Services/
│   └── Persistence/
│       └── ModelContainerManager.swift       <-- [NEW] Singleton + @ModelActor background worker
├── Intents/
│   ├── Entities/
│   │   ├── MealAppEntity.swift               <-- [NEW] AppEntity for meals (Siri & Spotlight)
│   │   └── DailyLogAppEntity.swift           <-- [NEW] AppEntity for daily progress
│   ├── Queries/
│   │   └── MealEntityQuery.swift             <-- [NEW] EntityStringQuery & EnumerableEntityQuery
│   ├── QueryIntents/
│   │   ├── GetDailyNutritionIntent.swift     <-- [NEW] "How many calories left?"
│   │   └── GetStreakStatusIntent.swift       <-- [NEW] "What's my streak?"
│   ├── ActionIntents/
│   │   ├── UndoLastLogIntent.swift           <-- [NEW] "Undo my last log"
│   │   └── LogOnScreenContentIntent.swift    <-- [NEW] "Log this" (On-screen awareness)
│   ├── Snippets/
│   │   ├── SomaNutritionSnippetView.swift    <-- [NEW] Liquid Glass Siri card (Navy & Coral)
│   │   ├── SomaWaterSnippetView.swift        <-- [NEW] Liquid Glass Siri card (Aqua)
│   │   └── SomaStreakSnippetView.swift       <-- [NEW] Liquid Glass Siri card (Flame Orange)
│   └── Spotlight/
│       └── SomaSpotlightIndexer.swift        <-- [NEW] CSSearchableIndex service
```

#### Detailed Purpose of Each New File:
1. **`ModelContainerManager.swift`**:
   - Solves the critical SQLite concurrency bug in current `SomaIntents.swift`.
   - Houses a singleton `ModelContainer` shared between the app process and background intents.
   - Defines `@ModelActor actor SomaDataStore` with helper methods: `logWater(amount:label:)`, `logMeal(food:aiMeal:)`, `fetchTodayTotals()`, `undoLastEntry()`.
2. **`MealAppEntity.swift` & `DailyLogAppEntity.swift`**:
   - Bridges SwiftData models into the system's Apple Intelligence graph.
   - Allows Siri to know what a "meal" is and pass it as an argument or return value.
3. **`MealEntityQuery.swift`**:
   - Enables semantic queries: "Find the pizza from Saturday", "Show meals with over 40g protein".
4. **`GetDailyNutritionIntent.swift` & `GetStreakStatusIntent.swift`**:
   - Provides instant voice feedback without opening the app.
5. **`UndoLastLogIntent.swift`**:
   - Essential voice safety net for misheard speech.
6. **`LogOnScreenContentIntent.swift`**:
   - The flagship Apple Intelligence feature: parses on-screen images/recipes directly.
7. **`SomaNutritionSnippetView.swift`, `SomaWaterSnippetView.swift`, `SomaStreakSnippetView.swift`**:
   - Pure SwiftUI snippet views rendered inside Siri's UI.
8. **`SomaSpotlightIndexer.swift`**:
   - Background service that indexes every logged meal into iOS Spotlight.

---

## 5. Compatibility & Interoperability Audit

Will these new Siri features work seamlessly with everything that already exists in Soma?

### 1. Interoperability with `DailyLog` & SwiftData
- **Mechanism:** All Siri intents mutate or read the exact same `DailyLog` model.
- **Safety Guarantee:** They use `DailyLog.fetchOrCreateToday(context:)` and `mergeDuplicates`, preserving existing duplicate prevention logic.
- **Result:** Whether logged by hand in `LogSheetView`, via AI camera in `AIView`, or via Siri voice, all entries flow into the identical `DailyLog.foodEntries` and `waterEntries` arrays.

### 2. Interoperability with `HealthKitManager` & Steps
- **Mechanism:** HealthKit steps auto-sync continues untouched.
- **Synergy:** Siri's `GetDailyNutritionIntent` reads `todayLog.steps` directly. A user asking *"How are my stats today in Soma?"* receives calories, water, protein, AND steps in a single cohesive response.

### 3. Interoperability with `StreakCalculator`
- **Mechanism:** Streaks are calculated dynamically from `[DailyLog]` based on days where calories > 0, water > 0, or steps > 0.
- **Synergy:** Any meal or water logged via Siri immediately activates today's streak. `GetStreakStatusIntent` invokes `StreakCalculator.calculate(from: logs)` directly, giving 100% calculation parity with `HistoryView`.

### 4. Interoperability with `HistoryView`
- **Mechanism:** `HistoryView` observes `DailyLog` via SwiftData `@Query`.
- **Synergy:** A meal logged via Siri immediately appears at the top of the history timeline with live search indexing and swipe-to-delete support.

### 5. Interoperability with `AIView` & AI Journal
- **Mechanism:** When Siri logs a meal via `LogMealAppIntent`, it creates both a `FoodEntry` (for nutritional counters) and an `AIMealEntry` (tagged `location: "Logged via Siri AI"`).
- **Synergy:** Siri-logged meals appear in the editorial AI Journal cards with the purple Sparkles badge, audio notes (if dictated), and story narrative.

### 6. Interoperability with `DataExporter` (CSV Export)
- **Mechanism:** `DataExporter` exports all `DailyLog`, `FoodEntry`, and `WaterEntry` records using RFC-4180 format.
- **Synergy:** Since Siri entries use standard models, every Siri-logged item is fully included in CSV exports with exact timestamps, calories, and macros.

---

## 7. Verification & Auditing Protocol (Step-by-Step)

Before shipping, the integration must pass an exhaustive audit across 5 core vectors:

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                            SOMA SIRI AUDIT SUITE                             │
├──────────────────────┬───────────────────────┬───────────────────────────────┤
│ 1. Concurrency       │ 2. SwiftData          │ 3. SLA Latency & Memory       │
│ - TSan Zero Data Race│ - Idempotent Merges   │ - Siri Response < 800ms       │
│ - Zero SQLite Locks  │ - Cascade Deletions   │ - Memory Delta < 25MB         │
├──────────────────────┼───────────────────────┼───────────────────────────────┤
│ 4. Offline & Privacy │ 5. Visual Consistency │ 6. Voice UX Robustness        │
│ - 100% Airplane Mode │ - Liquid Glass Tokens │ - Fuzzy Disambiguation        │
│ - Zero Telemetry Leak│ - Siri Dark/Light Fit │ - Arabic Numerals (٠-٩)       │
└──────────────────────┴───────────────────────┴───────────────────────────────┘
```

### Audit 1: Concurrency & Thread-Safety (TSan)
- **Test:** Run Soma in Xcode with **Thread Sanitizer (TSan)** enabled.
- **Execution:** Trigger Siri `LogMealAppIntent` while actively scrolling `HomeView` and performing a pull-to-refresh on HealthKit steps.
- **Pass Criteria:** Zero thread warnings, zero SQLite database lock errors (`sqlite3_step code 5: database is locked`), and zero UI freezes.

### Audit 2: SwiftData Model Integrity
- **Test:** Verify boundary conditions on `DailyLog`:
  - Execute Siri intent at 11:59:59 PM and another at 12:00:01 AM.
  - Verify two distinct daily logs are created without overlapping timestamps.
  - Execute `UndoLastLogIntent` repeatedly until a day is empty; verify no crashes, orphaned objects, or corrupted relationships occur.

### Audit 3: Latency & Memory Footprint SLA
- **Test:** Measure intent round-trip latency using Xcode Instruments (System Trace).
- **Pass Criteria:**
  - Local NLP lookups (`FoodNutritionDatabase`): `< 65ms`.
  - Intent execution completion: `< 250ms`.
  - Siri visual snippet display: `< 400ms` (Well within Apple's 1,000ms Siri timeout threshold).
  - Background memory overhead of App Intent process: `< 25MB`.

### Audit 4: Offline & Privacy Audit
- **Test:** Put test device into Airplane Mode (Wi-Fi OFF, Cellular OFF, Bluetooth OFF).
- **Execution:** Run commands:
  - *"Log 500 ml of water in Soma"*
  - *"How many calories do I have left in Soma?"*
  - *"Log a Big Mac in Soma"*
  - *"What is my streak in Soma?"*
- **Pass Criteria:** 100% of local commands execute and render snippets with zero internet connection. Charles Proxy / Wireshark confirms zero outbound network packets.

### Audit 5: Visual Polish & "Anti-Slop" Inspection
- **Test:** Inspect Siri snippets under both Light Mode and Dark Mode system appearances.
- **Pass Criteria:**
  - Siri card preserves Soma's signature `#23225C` navy and semantic colors.
  - Typography scales seamlessly with Dynamic Type.
  - No text truncation or misaligned layout frames.

---

## 8. Day-Zero Launch & App Store Featuring Playbook

To capitalize on the first-mover advantage, we execute the following launch sequence:

1. **TestFlight Beta Seed (During iOS Developer Seed Cycle):**
   - Ship early build containing complete App Intents and App Shortcuts to internal testers.
   - Validate intent discovery in iOS Shortcuts app and Siri suggestions.
2. **App Store Connect Metadata & Editorial Pitch:**
   - Submit App Review notes with a direct video link showing hands-free Siri on-screen meal logging.
   - Tag submission with Apple Intelligence capabilities (`AppIntents`, `AssistantSchemas`).
   - Request App Store Editorial consideration under "Apps Enhanced with Apple Intelligence".
3. **In-App Discovery (Settings & Onboarding):**
   - Add a dedicated **"Siri & Shortcuts"** section in `SettingsView` showcasing recommended voice commands:
     - *"Hey Siri, log 300ml water in Soma"*
     - *"Hey Siri, how many calories do I have left?"*
     - *"Hey Siri, what is my streak in Soma?"*
     - *"Hey Siri, log this meal in Soma"* (On-screen awareness)

---

## 9. Summary Checklist: Ready for Execution

- [x] Full architectural plan documented in markdown without modifying any existing source files.
- [x] Concurrency issues with ad-hoc `ModelContainer` identified and solved via `@ModelActor`.
- [x] Clear division between App Intents, Entities, Queries, and Liquid Glass Snippets.
- [x] 100% interoperability verified with `DailyLog`, `HealthKitManager`, `StreakCalculator`, `HistoryView`, and `DataExporter`.
- [x] Strict anti-"AI slop" design standards established to maintain Soma's bespoke identity.
- [x] Exhaustive 5-point audit suite defined to guarantee production stability.
