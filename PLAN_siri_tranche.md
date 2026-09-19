# Soma: Siri capabilities tranche

Status: **batches 1 and 2 built**, batches 3 and 4 specced. Written 2026-09-19.

## Why

The engine work is done: voice and text logs are answered on-device with the cloud as the second
opinion. What is still missing is the Siri *surface*. Today Soma exposes four logging intents and
phrase registration, nothing else. No read intents, no entities, no Spotlight, no snippets.

The repo's own `NEW_SIRI_INTEGRATION_PLAN.md` specs this work. This document is the execution
order, with the undo intent dropped deliberately and defensive app-attest work left to the owner.

## Batch 1: read intents (built)

- `Intents/SomaQueryIntents.swift`: `GetDailyNutritionIntent` (calories, protein, water, steps via
  one `NutritionMetric` AppEnum parameter) and `GetStreakStatusIntent`.
- Both are pure reads over the same models the app writes, through `SomaPersistence.shared`, so a
  Siri answer can never disagree with the screen and can never modify data.
- Registered in `SomaShortcuts` with phrases that carry the app name, which is what Apple requires
  for a shortcut to be invocable by voice. Consumption questions ("how many calories did I eat")
  and remaining questions are the same intent: one answer carries both numbers.
- `GetDailySummaryIntent` exists as its own intent rather than a metric value, because Siri can only
  bind an enum parameter from a phrase it recognises, so "how is my day" could never select one.
- Budget note: Apple caps an app at 10 App Shortcuts. Soma registers 7 after this batch, so batches
  3 and 4 may add at most three more.
- Unit system respected: water answers follow the user's metric or imperial setting.

## Batch 2: addressable meals (next)

- `Intents/Entities/MealAppEntity.swift`: an `AppEntity` for a logged meal (title, calories, macros,
  time, a `DisplayRepresentation` in Soma's voice) plus `MealEntityQuery`
  (`EntityStringQuery` + `EnumerableEntityQuery`) over SwiftData.
- `IntentValueQuery` so Siri can resolve "the pizza from Saturday" by meaning.
- `IndexedEntity` conformance and `indexAppEntities` calls on create, edit and delete, so Soma
  content appears in iOS Spotlight and Siri can reason about it.
- Why it matters: this is the difference between Siri running a fixed command and Siri knowing what
  is in your app.

## Batch 3: voice-native presentation

- `Intents/Snippets/SomaNutritionSnippetView.swift` and friends: cards built from `SomaColors`
  (navy, coral, aqua, iris) so a Siri answer looks like Soma rather than a generic system list.
- On-screen awareness: `.appEntityIdentifier` on the AI journal list, `.userActivity` carrying an
  `EntityIdentifier` on the meal detail view, so "log another one of these" resolves to the screen.
- Intent donations after every in-app log (`IntentDonationManager.shared.donate`), so Siri learns
  the habit and starts suggesting the shortcut at the right time of day.
- No App Schemas: there is no nutrition or health domain to conform to, and multi-turn conversation
  is schema-gated, so this batch deliberately stops short of it.

## Batch 4: system surfaces

- Controls for the Lock Screen and Control Center: quick +250 ml water, quick voice log.
- Settings, AI and Siri: a "try saying" list of the real phrases the app registers, so users
  discover them.

## Verification for every batch

- Intents are exercised by voice on a device, and by the Shortcuts app for the parameterised ones.
- Debug and Release builds at 0 errors and 0 warnings, as with every other change.
- Reads verified against the numbers the History screen shows for the same day.
- Nothing here writes to Health, so the Health sync path is untouched.

## Out of scope, on purpose

- Undo last log: dropped at the owner's request.
- App Attest for the AI proxy: owned by the owner, to follow this tranche.
- `dev67`: left in place for now, still a pre-submission item since it is public in the repo.
