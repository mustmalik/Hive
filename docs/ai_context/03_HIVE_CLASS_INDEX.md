# HIVE — Class Index

This index is meant to help Claude navigate the repo without re-reading everything.

Format per entry:

- **File**: `lib/...`
  - **Class**:
  - **Purpose**:
  - **Important methods**:
  - **Used by**:
  - **Risk level**: Low / Medium / High
  - **Notes**:

## Core models and interfaces

- **File**: `lib/domain/entities/media_asset.dart`
  - **Class**: `MediaAsset`, `MediaAssetType`
  - **Purpose**: Canonical asset record used throughout scan + placement + UI.
  - **Important methods**: n/a (data object)
  - **Used by**: scan coordinator, media library service, placement pipeline, UI.
  - **Risk level**: Medium
  - **Notes**: Asset `type` drives deterministic routing (e.g., videos, screenshots).

- **File**: `lib/domain/entities/classification_label.dart`
  - **Class**: `ClassificationLabel`, `ClassificationLabelSource`
  - **Purpose**: A single ML label with confidence + model identifier.
  - **Important methods**: n/a
  - **Used by**: placement pipeline and explainability.
  - **Risk level**: Medium

- **File**: `lib/application/models/structural_signals.dart`
  - **Class**: `StructuralSignals`
  - **Purpose**: Derived structural features (faces/OCR/layout/barcode/MRZ) used by placement.
  - **Important methods**:
    - `StructuralSignals.empty()`
    - `withScreenDeviceCueCount(int)`
    - `isDocumentLike`, `isChatLike`, `isMemeOrPosterLike`, `isPhotoQuoteCardMeme`
    - `hasAnyToken(List<String>)`
  - **Used by**: `StructuralSignalExtractor`, `KeywordPlacementPipeline`.
  - **Risk level**: High
  - **Notes**: Small threshold changes can shift many routing outcomes.

- **File**: `lib/application/models/asset_mapping_explanation.dart`
  - **Class**: `AssetMappingExplanation`
  - **Purpose**: Explainable placement output returned by the pipeline and shown in UI.
  - **Important methods**: n/a (data object)
  - **Used by**: dashboard/folder detail services and viewer UI.
  - **Risk level**: High
  - **Notes**: Evidence fields must remain truthful; avoid synthetic “fake keywords”.

- **File**: `lib/application/services/scan_coordinator.dart`
  - **Class**: `ScanCoordinator` (interface)
  - **Purpose**: Scan orchestration contract.
  - **Important methods**: `watchActiveRun()`, `startFullScan()`, `cancelActiveRun()`
  - **Used by**: `ScanProgressScreen` (UI) and `RealScanCoordinator` (impl).
  - **Risk level**: Medium

## Media library + permissions

- **File**: `lib/data/services/photo_manager_media_library_service.dart`
  - **Class**: `PhotoManagerMediaLibraryService`
  - **Purpose**: Fetch assets + albums from Apple Photos via `photo_manager`.
  - **Important methods**:
    - `fetchAssets(...)`
    - `fetchAlbums(...)`
    - `getEstimatedAssetCount(...)`
    - `getAssetById(...)`
  - **Used by**: `RealScanCoordinator`, Home UI (album picker).
  - **Risk level**: Medium
  - **Notes**: Determines screenshot subtypes; scope behavior matters for correctness.

- **File**: `lib/data/services/photo_manager_permission_service.dart`
  - **Class**: `PhotoManagerPermissionService`
  - **Purpose**: Photos permission status, request, limited picker, open settings.
  - **Important methods**:
    - `getPhotoPermissionStatus()`
    - `requestPhotoPermission()`
    - `presentLimitedPhotoPicker()`
    - `openPhotoSettings()`
  - **Used by**: `SplashScreen`, `PermissionScreen`.
  - **Risk level**: Low

## Classification backends

- **File**: `lib/data/services/classification_service_factory.dart`
  - **Class**: `ClassificationServiceFactory`
  - **Purpose**: Create labeling backend based on env/config.
  - **Important methods**: `create(...)`, `engineNameForService(...)`
  - **Used by**: `RealScanCoordinator.seeded(...)`.
  - **Risk level**: Low

- **File**: `lib/data/services/ios_vision_classification_service.dart`
  - **Class**: `IosVisionClassificationService`
  - **Purpose**: Apple Vision labeling through `MethodChannel`.
  - **Important methods**: `classifyAssetDetailed(...)`
  - **Used by**: scan coordinator when backend is Apple Vision.
  - **Risk level**: Medium
  - **Notes**: Native bridge availability varies by build; failures are mapped into `ClassificationOutcome`.

- **File**: `lib/data/services/google_mlkit_classification_service.dart`
  - **Class**: `GoogleMlKitClassificationService`
  - **Purpose**: ML Kit image labeling backend with safe input prep.
  - **Important methods**:
    - `classifyAssetDetailed(...)`
    - `disposeSharedResources()`
  - **Used by**: scan coordinator when backend is ML Kit.
  - **Risk level**: Medium
  - **Notes**: Writes temp files for bytes fallback; must remain safe and non-destructive.

## Structural signals

- **File**: `lib/data/services/structural_signal_extractor.dart`
  - **Class**: `StructuralSignalExtractor`
  - **Purpose**: Extract face/OCR/barcode/MRZ/layout signals from safe previews.
  - **Important methods**:
    - `extract(MediaAsset)`
    - `disposeSharedDetectors()`
  - **Used by**: `PlacementAnalysisBuilder` (async pipeline path).
  - **Risk level**: High
  - **Notes**: Timeout/failure behavior impacts meme/doc routing determinism.

## Placement / routing pipeline

- **File**: `lib/data/services/placement/placement_definitions.dart`
  - **Class**: `KeywordPlacementDefinitions`
  - **Purpose**: Canonical cell definitions (rules, keywords, thresholds).
  - **Important members**:
    - `rules`, `unsortedRule`
    - thresholds: `fallbackThreshold`, `fallbackMarginThreshold`,
      `kMinWinningScoreMargin`, `confidentPlacementThreshold`
  - **Used by**: scoring + decision stages.
  - **Risk level**: High
  - **Notes**: Cell IDs here are the “source of truth” for placement.

- **File**: `lib/data/services/placement/placement_models.dart`
  - **Classes**: `AssetAnalysis`, `CueSummary`, `AnalysisSignals`, `PlacementScoreCard`, `DerivedSignals`
  - **Purpose**: Shared analysis model for all stages.
  - **Important methods**:
    - `DerivedSignals.from(AssetAnalysis)`
  - **Used by**: all pipeline stages.
  - **Risk level**: High

- **File**: `lib/data/services/placement/keyword_placement_pipeline.dart`
  - **Class**: `KeywordPlacementPipeline`
  - **Purpose**: Orchestrates placement stages and produces `AssetMappingExplanation`.
  - **Important methods**:
    - `explainPlacement(...)`
    - `explainPlacementAsync(...)`
    - `primeStructuralSignals(...)`
  - **Used by**: `KeywordFolderMappingService`, dashboard/detail resolution.
  - **Risk level**: Very High
  - **Notes**: Contains the stage implementations and many guardrails.

- **File**: `lib/data/services/placement/keyword_placement_pipeline.dart`
  - **Class**: `PlacementAnalysisBuilder`
  - **Purpose**: Builds `AssetAnalysis` and manages structural signal caching + timeouts.
  - **Important methods**: `build(...)`, `buildAsync(...)`, `primeStructuralSignals(...)`
  - **Used by**: `KeywordPlacementPipeline`.
  - **Risk level**: High

- **File**: `lib/data/services/placement/keyword_placement_pipeline.dart`
  - **Class**: `ContentTypeRoutingStage`
  - **Purpose**: Early deterministic routing (videos, strong screenshots, receipts/docs, architecture/places, etc).
  - **Important methods**: `route(AssetAnalysis)`
  - **Used by**: pipeline pre-scoring.
  - **Risk level**: High

- **File**: `lib/data/services/placement/keyword_placement_pipeline.dart`
  - **Class**: `WeightedCategoryScoringStage`
  - **Purpose**: Weighted scoring across all categories (keywords, filename, boosts).
  - **Important methods**: `score(AssetAnalysis)`
  - **Used by**: pipeline scoring.
  - **Risk level**: High

- **File**: `lib/data/services/placement/keyword_placement_pipeline.dart`
  - **Class**: `VetoPrecedenceStage`
  - **Purpose**: Deterministic precedence and veto rules (memes vs people, books precedence, etc).
  - **Important methods**: `apply(scores, analysis)`
  - **Used by**: pipeline after scoring.
  - **Risk level**: Very High

- **File**: `lib/data/services/placement/keyword_placement_pipeline.dart`
  - **Class**: `CategoryEntryGateStage`
  - **Purpose**: Per-category entry gates that veto weak/unsafe placements.
  - **Important methods**: `apply(scores, analysis)`
  - **Used by**: pipeline after precedence.
  - **Risk level**: Very High

- **File**: `lib/data/services/placement/keyword_placement_pipeline.dart`
  - **Class**: `PlacementDecisionStage`
  - **Purpose**: Final decision vs Unsorted using thresholds, margins, “strong support”.
  - **Important methods**: `resolve(scores, analysis, derived)`
  - **Used by**: pipeline final step.
  - **Risk level**: High

## Mapping + persistence surfaces

- **File**: `lib/data/services/keyword_folder_mapping_service.dart`
  - **Class**: `KeywordFolderMappingService`
  - **Purpose**: Runs placement per asset and builds `FolderCell` results for persistence.
  - **Important methods**:
    - `buildSuggestedCells(...)`
    - `explainPlacement(...)`
    - `explainPlacementAsync(...)`
  - **Used by**: scan coordinator (final assembly) and membership resolution.
  - **Risk level**: High

- **File**: `lib/data/services/real_scan_coordinator.dart`
  - **Class**: `RealScanCoordinator`
  - **Purpose**: Orchestrates scan → classification → placement → persistence, emits progress.
  - **Important methods**:
    - `startFullScan(...)`
    - `watchActiveRun()`
    - `cancelActiveRun()`
  - **Used by**: scan progress UI.
  - **Risk level**: High

- **File**: `lib/data/services/persisted_home_dashboard_service.dart`
  - **Class**: `PersistedHomeDashboardService`
  - **Purpose**: Dashboard snapshot with resolved membership counts.
  - **Important methods**: `loadDashboard()`
  - **Used by**: Home UI.
  - **Risk level**: Medium

- **File**: `lib/data/services/persisted_folder_detail_service.dart`
  - **Class**: `PersistedFolderDetailService`
  - **Purpose**: Cell detail view members using resolved authoritative placement.
  - **Important methods**: `loadCell(cellId)`
  - **Used by**: Folder detail UI.
  - **Risk level**: Medium

