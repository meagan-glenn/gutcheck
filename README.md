# Gut Check

The health record for a house full of animals. SwiftUI iOS app implementing PRD v0.3 MVP.

## What's implemented

- **Home** — "Something's off" as the primary action, per-pet status cards with mode badges (baseline / watch / chronic), resolution progress dots, one-tap food-theft logging
- **4C capture** (W2) — Consistency (5-point owner scale over stored 1–7 vet values, "Hard" demoted behind *more*), Color, Coating, Contents; live triage badge; mock AI prefill with tap-to-correct
- **Triage ladder** (W11) — Normal / Monitor / Concern / Urgent; liquid ×3 in 24h escalates to Urgent; **Urgent breaks the layout** (vet action promoted, save demoted to a text link)
- **Episode state machine** — baseline → watch → 3 consecutive normals → resolution prompt; chronic pets stay pinned in watch
- **48-hour lookback** (W4) — new items, cross-feeding, recent outputs, "anything we missed?" chips
- **Interventions & protocols** (W5) — one-tap intervention chips, protocol captured at resolution, **protocol replay** banner on the next episode
- **Cross-feeding** — who ate whose, roughly how much; feeds lookback and insights
- **Insights** (W7) — new-household-item correlation, cross-feed-precedes-episode, protocol narrowing across resolutions; counter-evidence shown; association-only language
- Seed household: Navi (chronic gut, active episode + one resolved episode with a protocol), Juniper, Miso

## Not yet built (stubs / next)

Camera + real AI scoring (manual chips are the override path), vet summary PDF (W8), household invites / second opinion (W9), onboarding flow (W1), photo storage.

## Build & run

Requires full Xcode (not just Command Line Tools).

```bash
# one-time, after installing Xcode from the App Store:
sudo xcode-select -s /Applications/Xcode.app
# then:
open GutCheck.xcodeproj   # or build headlessly via xcodebuild
```

Project file is generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`xcodegen generate`).

## Domain tests

Pure-Swift triage/resolution logic in `GutCheck/Domain.swift` is UI-free and testable with just the CLI toolchain — see the assertions run during development (17 checks: tier ladder, liquid escalation, axis independence, resolution counting).
