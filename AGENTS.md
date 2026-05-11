# HIVE — AI Agent Rules

## Project Identity
HIVE is a Flutter/Dart iOS-first photo and video organizer.
It creates a local virtual organization layer only.

**HIVE must never move, rename, delete, or mutate original
Apple Photos assets under any circumstance.**

Do not write Swift, Kotlin, Python, cloud APIs, ML retraining
logic, or any destructive Apple Photos operations unless
explicitly requested by the user.

---

## Core Goal
Automatically sort a user's camera roll into clean named
folders (cells) without any manual effort. The pipeline
analyses Vision labels, OCR text, structural signals, and
metadata to decide which cell each asset belongs to.

---

## Current Cells (Category IDs)
| Cell ID          | Display Name       |
|------------------|--------------------|
| people           | People             |
| food             | Food               |
| places           | Places             |
| travel           | Travel             |
| pets             | Pets               |
| sports           | Sports             |
| screenshots      | Screenshots        |
| documents        | Documents          |
| animation_meme   | Memes              |
| nature           | Nature             |
| vehicles         | Cars & Vehicles    |
| receipts         | Receipts           |
| videos           | Videos             |
| unsorted         | Unsorted           |

---

## Placement Pipeline (in order)
1. PlacementAnalysisBuilder
2. ContentTypeRoutingStage
3. WeightedCategoryScoringStage
4. VetoPrecedenceStage
5. CategoryEntryGateStage
6. PlacementDecisionStage

Do not redesign, rename, or reorder these stages unless
explicitly instructed. New logic goes inside existing stages
following existing patterns.

---

## Placement Rules (non-negotiable)

### Priority order
1. Manual overrides always win — never override a user's
   explicit placement decision
2. Videos are always Videos — no other category steals
   video assets
3. Meme detection runs before People-first rule —
   if any meme signal fires, route to Memes before
   evaluating People, Sports, Screenshots, or Places
4. People-first rule (Phase 1) — strong human presence
   beats Nature, Screenshots, Documents, Animation
5. Category-specific precedence (Phase 2) — Receipts,
   Nature, Vehicles rules
6. Unsorted is the safe fallback — confidently wrong
   is worse than Unsorted

### People
- People should never appear in Nature or Places
  unless a person is truly incidental (far background,
  not the subject)
- Portraits, saved Instagram photos, selfies → People

### Memes / Animation-Meme
- Memes are a first-class category, not just cartoons
- The following ALWAYS route to Memes:
  - Tweet/X/Instagram/Facebook post screenshots
  - Social post jokes and viral text screenshots
  - Photo + bold caption text overlay (sports, people,
    nature, anything)
  - Multi-panel TV/movie/anime scene memes
  - Sports quote graphics (person + huge quote text)
  - Captioned fictional/animated/cartoon scenes
- Normal sports action photos without meme overlay
  still route to Sports
- Normal portraits without text overlay still route
  to People
- Normal app UI screenshots without social/joke
  structure still route to Screenshots

### Screenshots
- True app UI screenshots (Settings, Maps, Notes,
  apps) → Screenshots
- Social post screenshots with joke/viral/meme
  structure → Memes (not Screenshots)
- Receipts with strong OCR evidence → Receipts
  (not Screenshots)

### Documents
- Passport, ID card, MRZ pattern → Documents
- Receipts, till slips, invoices → Receipts
  (not Documents, unless MRZ present)

### Nature
- Only pure scenery with no dominant person
- No landmark anchor (Places beats Nature)
- No travel cluster (Travel beats Nature)

### Unsorted
- Genuinely ambiguous assets belong in Unsorted
- Never lower Unsorted confidence gates to force
  assets into a wrong category

---

## Code Standards

### Every change must include:
- Regression tests in keyword_placement_pipeline_test.dart
  and/or keyword_folder_mapping_service_test.dart
- flutter analyze passing with zero issues
- flutter test passing for all affected test files

### Explainability rule
matchedKeywords must contain ONLY real detected evidence.
Never append synthetic/fake keyword strings as justification.
If a routing rule fires, expose the reason truthfully through
existing debug/explanation fields.

### Pattern rule
Follow existing patterns in the codebase. Do not:
- Rewrite or restructure existing boost/precedence methods
- Add new pipeline stages
- Change Food, Travel, Pets, Sports logic unless asked
- Lower confidence gates across the board

### New signals
New bool-derived signals (e.g. tweetScreenshotMemeLike,
photoTextOverlayMemeLike) belong in placement_models.dart
or the existing CueSummary struct. Derive them from real
Vision labels, OCR text, text coverage ratios, structural
signals, and filename hints only.

---

## Files You Will Touch Most
- lib/data/services/placement/placement_definitions.dart
- lib/data/services/placement/keyword_placement_pipeline.dart
- lib/data/services/placement/placement_models.dart
- test/keyword_placement_pipeline_test.dart
- test/keyword_folder_mapping_service_test.dart

---

## What Not To Touch (unless explicitly asked)
- App shell, onboarding, scan coordinator, UI layer
- Album scope or media fetching logic
- iOS/Android native code
- Firebase or cloud storage layer
- Any file outside lib/data/services/placement/ and test/
