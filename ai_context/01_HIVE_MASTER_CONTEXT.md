# HIVE — Master Context

Hive is an **iPhone-first Flutter/Dart** photo and video organizer.

Hive creates a **local, virtual organizational layer** over the user’s Apple Photos library. It does **not** create real albums in Photos and must **never** move, rename, delete, or mutate original Apple Photos assets.

## Core rules (non-negotiable)

- **Flutter/Dart only.**
- **iOS-first** (Apple Photos via `photo_manager`).
- **On-device ML only.** No cloud inference, no cloud sync requirements for core function.
- **No model retraining** suggestions.
- **No architecture rewrites** unless explicitly requested.
- **Never modify original Apple Photos assets** under any circumstance.

## ML backends (what exists today)

- **Google ML Kit** via Flutter plugins:
  - `google_mlkit_image_labeling`
  - `google_mlkit_face_detection`
  - `google_mlkit_text_recognition`
  - `google_mlkit_barcode_scanning`
- **Apple Vision** labeling bridge exists on iOS via a `MethodChannel`.

Note: the current runtime default backend in code is **Apple Vision**, but the project should treat **ML Kit as a first-class on-device backend** too.

## Main goal

Hive scans accessible photos/videos, classifies each asset with on-device signals, and places it into user-facing **cells** (virtual folders). The placement decision is explainable and must prefer **being safely Unsorted** over being confidently wrong.

## Current cells (cell IDs used in code)

These are the current placement rule targets (from `KeywordPlacementDefinitions`):

- `people` — People
- `pets` — Pets
- `food` — Food
- `places` — Places
- `nature` — Nature
- `travel` — Travel
- `vehicles` — Cars & Vehicles
- `sports` — Sports
- `screenshots` — Screenshots
- `devices_tech` — Devices / Tech
- `documents_receipts` — Documents / Receipts
- `receipts` — Receipts
- `books` — Books
- `animation` — Animation
- `memes` — Memes
- `videos` — Videos (deterministic by media type)
- `unsorted` — Unsorted (safe fallback)

Legacy/back-compat cell IDs that may exist in persisted data:

- `animation_cartoon_meme` — legacy combined id; normalized to `memes` when resolving membership.

## Important product rules (placement intent)

- **Manual overrides always win.** A user’s explicit placement decision must not be overridden.
- **Videos are always Videos.** No other category should steal video assets.
- **Memes must not be overridden by People.**
- **Animated/cartoon characters must not land in People.**
- **People requires real-human evidence**, not weak human-like labels.
- **Screenshots with UI should not become Documents** unless there is strong document/receipt evidence.
- **Food should require real food/dining evidence**, with conservative rescue logic.
- **Vehicles should win** when vehicle evidence is strong/dominant.
- **Places should win** for landmarks/architecture/scenery/outdoors/venues, and should resist “incidental people” drift.

