import 'dart:math' as math;

import '../../../application/models/asset_mapping_explanation.dart';
import '../../../application/models/structural_signals.dart';
import '../../../domain/entities/classification_label.dart';
import '../../../domain/entities/media_asset.dart';

class PlacementCellRule {
  const PlacementCellRule({
    required this.cellId,
    required this.cellName,
    required this.description,
    required this.styleKey,
    required this.keywords,
    this.featured = false,
    this.priorityBias = 0,
    this.assetTypes = const <MediaAssetType>{},
  });

  final String cellId;
  final String cellName;
  final String description;
  final String styleKey;
  final Set<String> keywords;
  final bool featured;
  final double priorityBias;
  final Set<MediaAssetType> assetTypes;
}

class PlacementScoreCard {
  PlacementScoreCard({
    required this.rule,
    required this.score,
    Set<String>? matchedKeywords,
    Set<String>? primaryEvidence,
    Set<String>? secondarySupport,
    Set<String>? fallbackOrDebugReasons,
  }) : primaryEvidence = primaryEvidence ?? matchedKeywords ?? <String>{},
       matchedKeywords = primaryEvidence ?? matchedKeywords ?? <String>{},
       secondarySupport = secondarySupport ?? <String>{},
       fallbackOrDebugReasons = fallbackOrDebugReasons ?? <String>{};

  final PlacementCellRule rule;
  double score;
  final Set<String> primaryEvidence;
  final Set<String> matchedKeywords;
  final Set<String> secondarySupport;
  final Set<String> fallbackOrDebugReasons;
  bool vetoed = false;
}

class AssetAnalysis {
  const AssetAnalysis({
    required this.asset,
    required this.topLabels,
    required this.scoringLabels,
    required this.normalizedFilename,
    required this.filenameTokens,
    required this.cueSummary,
    required this.signals,
    this.structural = const StructuralSignals(
      faceCount: 0,
      largestFaceAreaRatio: 0,
      hasSingleLargeFace: false,
      textCoverageRatio: 0,
      fullOcrText: '',
      lineCount: 0,
      blockCount: 0,
      hasChatLikeLayout: false,
      hasTableLikeLayout: false,
      barcodeCount: 0,
      hasQrCode: false,
      hasMrzPattern: false,
    ),
  });

  final MediaAsset asset;
  final List<ClassificationLabel> topLabels;
  final List<ClassificationLabel> scoringLabels;
  final String normalizedFilename;
  final Set<String> filenameTokens;
  final CueSummary cueSummary;
  final AnalysisSignals signals;
  final StructuralSignals structural;
}

class PlacementSignal {
  const PlacementSignal({
    required this.score,
    required this.evidenceCount,
    required this.isModerate,
    required this.isStrong,
  });

  final double score;
  final int evidenceCount;
  final bool isModerate;
  final bool isStrong;

  bool get isPresent => evidenceCount > 0 || score > 0;
}

class AnalysisSignals {
  const AnalysisSignals({
    required this.humanCentered,
    required this.humanPresence,
    required this.petCentered,
    required this.animalPresence,
    required this.documentLike,
    required this.documentness,
    required this.screenshotLike,
    required this.uiDensity,
    required this.graphicPostLike,
    required this.graphicMemeNess,
    required this.tweetScreenshotMemeLike,
    required this.socialEmbedMemeLike,
    required this.photoTextOverlayMemeLike,
    required this.quoteCardMemeLike,
    required this.captionOverlayPhotoMemeLike,
    required this.multiPanelMemeLike,
    required this.captionedFictionMemeLike,
    required this.hasProtectedDocumentIdentitySignal,
    required this.placeLike,
    required this.scenePlaceStrength,
    required this.sportsGraphicLike,
  });

  final PlacementSignal humanCentered;
  final PlacementSignal humanPresence;
  final PlacementSignal petCentered;
  final PlacementSignal animalPresence;
  final PlacementSignal documentLike;
  final PlacementSignal documentness;
  final PlacementSignal screenshotLike;
  final PlacementSignal uiDensity;
  final PlacementSignal graphicPostLike;
  final PlacementSignal graphicMemeNess;
  final PlacementSignal tweetScreenshotMemeLike;
  final PlacementSignal socialEmbedMemeLike;
  final PlacementSignal photoTextOverlayMemeLike;
  final PlacementSignal quoteCardMemeLike;
  final PlacementSignal captionOverlayPhotoMemeLike;
  final PlacementSignal multiPanelMemeLike;
  final PlacementSignal captionedFictionMemeLike;
  final bool hasProtectedDocumentIdentitySignal;
  final PlacementSignal placeLike;
  final PlacementSignal scenePlaceStrength;
  final PlacementSignal sportsGraphicLike;

  bool get hasConfirmedMemeSubtype =>
      tweetScreenshotMemeLike.isModerate ||
      socialEmbedMemeLike.isModerate ||
      photoTextOverlayMemeLike.isModerate ||
      quoteCardMemeLike.isModerate ||
      captionOverlayPhotoMemeLike.isModerate ||
      multiPanelMemeLike.isModerate ||
      captionedFictionMemeLike.isModerate;
}

class CueSummary {
  const CueSummary({
    required this.familyCueCount,
    required this.peopleCueCount,
    required this.directPetCueCount,
    required this.foodCueCount,
    required this.strongFoodCueCount,
    required this.diningContextCueCount,
    required this.placeCueCount,
    required this.strongPlaceCueCount,
    required this.natureCueCount,
    required this.vehicleCueCount,
    required this.screenshotCueCount,
    required this.screenDeviceCueCount,
    required this.presentationCueCount,
    required this.documentCueCount,
    required this.identityDocumentCueCount,
    required this.documentCopyCueCount,
    required this.receiptCueCount,
    required this.animationCueCount,
    required this.crowdCueCount,
    required this.travelCueCount,
    required this.travelContextCueCount,
    required this.strongSportsCueCount,
    required this.weakSportsCueCount,
    required this.portraitCueCount,
    required this.groupPeopleCueCount,
    required this.strongFamilyCueCount,
    required this.sportsContextCueCount,
    required this.sportsGraphicCueCount,
    required this.chatUiCueCount,
    required this.strictChatUiCueCount,
    required this.logoTextApparelCueCount,
    required this.familyCueStrength,
    required this.peopleCueStrength,
    required this.directPetCueStrength,
    required this.foodCueStrength,
    required this.strongFoodCueStrength,
    required this.diningContextCueStrength,
    required this.placeCueStrength,
    required this.strongPlaceCueStrength,
    required this.natureCueStrength,
    required this.vehicleCueStrength,
    required this.screenshotCueStrength,
    required this.screenDeviceCueStrength,
    required this.presentationCueStrength,
    required this.documentCueStrength,
    required this.receiptCueStrength,
    required this.chatUiCueStrength,
    required this.travelCueStrength,
    required this.travelContextCueStrength,
    required this.strongSportsCueStrength,
    required this.sportsGraphicCueStrength,
    required this.logoTextApparelCueStrength,
    required this.architectureCueStrength,
    required this.mosqueCueCount,
  });

  final int familyCueCount;
  final int peopleCueCount;
  final int directPetCueCount;
  final int foodCueCount;
  final int strongFoodCueCount;
  final int diningContextCueCount;
  final int placeCueCount;
  final int strongPlaceCueCount;
  final int natureCueCount;
  final int vehicleCueCount;
  final int screenshotCueCount;
  final int screenDeviceCueCount;
  final int presentationCueCount;
  final int documentCueCount;
  final int identityDocumentCueCount;
  final int documentCopyCueCount;
  final int receiptCueCount;
  final int animationCueCount;
  final int crowdCueCount;
  final int travelCueCount;
  final int travelContextCueCount;
  final int strongSportsCueCount;
  final int weakSportsCueCount;
  final int portraitCueCount;
  final int groupPeopleCueCount;
  final int strongFamilyCueCount;
  final int sportsContextCueCount;
  final int sportsGraphicCueCount;
  final int chatUiCueCount;
  final int strictChatUiCueCount;
  final int logoTextApparelCueCount;
  final double familyCueStrength;
  final double peopleCueStrength;
  final double directPetCueStrength;
  final double foodCueStrength;
  final double strongFoodCueStrength;
  final double diningContextCueStrength;
  final double placeCueStrength;
  final double strongPlaceCueStrength;
  final double natureCueStrength;
  final double vehicleCueStrength;
  final double screenshotCueStrength;
  final double screenDeviceCueStrength;
  final double presentationCueStrength;
  final double documentCueStrength;
  final double receiptCueStrength;
  final double chatUiCueStrength;
  final double travelCueStrength;
  final double travelContextCueStrength;
  final double strongSportsCueStrength;
  final double sportsGraphicCueStrength;
  final double logoTextApparelCueStrength;
  final double architectureCueStrength;
  final int mosqueCueCount;
}

class PlacementDecision {
  const PlacementDecision({required this.explanation});

  final AssetMappingExplanation explanation;
}

class DerivedSignals {
  const DerivedSignals({
    required this.humanPresenceScore,
    required this.animalPresenceScore,
    required this.graphicnessScore,
    required this.documentnessScore,
    required this.sceneDensityScore,
    required this.uiDensityScore,
  });

  final double humanPresenceScore;
  final double animalPresenceScore;
  final double graphicnessScore;
  final double documentnessScore;
  final double sceneDensityScore;
  final double uiDensityScore;

  static double humanLikeLabelScore(List<ClassificationLabel> labels) {
    return _maxConfidenceForKeywords(labels, const [
      'person',
      'face',
      'portrait',
      'selfie',
      'human',
      'people',
      'adult',
    ]);
  }

  factory DerivedSignals.from(AssetAnalysis analysis) {
    final labels = analysis.scoringLabels;
    final structural = analysis.structural;
    final summary = analysis.cueSummary;
    final humanLabelScore = humanLikeLabelScore(labels);
    final structuralFaceAreaScore = _clamp01(
      structural.largestFaceAreaRatio * 3.0,
    );
    final structuralMultipleFacesScore = structural.faceCount >= 2 ? 0.7 : 0.0;
    final animalLabelScore = _maxConfidenceForKeywords(labels, const [
      'dog',
      'cat',
      'animal',
      'pet',
      'bird',
      'puppy',
      'kitten',
      'mouse',
      'mammal',
    ]);
    final graphicLabelScore = _maxConfidenceForKeywords(labels, const [
      'poster',
      'cartoon',
      'illustration',
      'meme',
      'graphic',
      'drawing',
    ]);
    final isDevicePhotoContext =
        summary.screenDeviceCueCount >= 1 &&
        structural.largestFaceAreaRatio < 0.08;
    final structuralGraphicScore = _clamp01(structural.textCoverageRatio * 2.0);
    final structuralQuoteCardScore =
        structural.isPhotoQuoteCardMeme ? 0.72 : 0.0;
    final structuralFaceWithoutHumanLabel =
        !isDevicePhotoContext &&
        structural.faceCount >= 1 &&
        humanLabelScore < 0.55 &&
        structural.largestFaceAreaRatio < 0.20 &&
        !structural.hasSingleLargeFace;
    final sceneLabelScore = _maxConfidenceForKeywords(labels, const [
      'architecture',
      'building',
      'landscape',
      'mosque',
      'dome',
      'mountain',
      'beach',
      'forest',
      'skyline',
      'street',
      'nature',
    ]);
    final sceneDensityScoreValue = _clamp01(sceneLabelScore);
    final foodPhotographyCue =
        summary.foodCueCount >= 1 ||
            summary.strongFoodCueCount >= 1 ||
            summary.foodCueStrength >= 0.28;
    final realWorldSceneAnchor =
        sceneDensityScoreValue >= 0.38 ||
            summary.placeCueStrength >= 0.25 ||
            summary.natureCueStrength >= 0.25 ||
            summary.travelCueStrength >= 0.25 ||
            summary.travelContextCueStrength >= 0.25 ||
            summary.strongSportsCueStrength >= 0.25 ||
            (summary.strongSportsCueCount >= 1 &&
                summary.sportsContextCueCount >= 1);
    final isLikelyNonPhotoArtwork =
        structural.faceCount == 0 &&
            humanLabelScore < 0.30 &&
            summary.peopleCueStrength < 0.35 &&
            summary.directPetCueCount == 0 &&
            !foodPhotographyCue &&
            !realWorldSceneAnchor;
    final structuralMangaComicOcrScore =
        structural.hasAnyToken(const [
              'manga',
              'anime',
              'shonen',
              'shonen jump',
              'comic',
              'comics',
              'graphic novel',
            ])
            ? 0.70
            : 0.0;
    final documentLabelScore = _maxConfidenceForKeywords(labels, const [
      'document',
      'receipt',
      'paper',
      'text',
      'invoice',
    ]);
    final structuralDocumentScore = structural.isDocumentLike ? 0.85 : 0.0;
    final documentnessScoreValue = _clamp01(
      math.max(documentLabelScore, structuralDocumentScore),
    );
    final chatUiScore = structural.isChatLike ? 0.9 : 0.0;
    final tableUiScore = structural.hasTableLikeLayout ? 0.6 : 0.0;
    final textUiScore = math.min(structural.textCoverageRatio * 1.5, 0.8);
    final animalPresenceScoreValue = _clamp01(animalLabelScore);

    final animatedAnimalLikely =
        structural.faceCount == 0 &&
        humanLabelScore < 0.25 &&
        animalLabelScore < 0.55 &&
        animalLabelScore > 0.10 &&
        documentnessScoreValue < 0.35 &&
        summary.placeCueStrength < 0.25 &&
        summary.strongPlaceCueCount == 0;

    final monochromeArtworkLikely =
        structural.faceCount == 0 &&
        humanLabelScore < 0.25 &&
        animalPresenceScoreValue < 0.25 &&
        documentnessScoreValue < 0.35 &&
        summary.peopleCueStrength < 0.35 &&
        !foodPhotographyCue &&
        !realWorldSceneAnchor;

    final screenshotLabelScore = _maxConfidenceForKeywords(labels, const [
      'screenshot',
      'screen capture',
    ]);
    final vehicleLabelScore = _maxConfidenceForKeywords(labels, const [
      'car',
      'vehicle',
      'automobile',
      'bmw',
      'wheel',
      'tire',
      'tyre',
      'road',
      'street',
      'driving',
      'transport',
      'conveyance',
    ]);

    final techLabelScore = _maxConfidenceForKeywords(labels, const [
      'screen',
      'display',
      'monitor',
      'computer',
      'laptop',
      'tablet',
      'phone',
      'smartphone',
      'mobile phone',
      'cell phone',
      'technology',
      'device',
    ]);

    final plainBackgroundGenericEnvOnly =
        humanLabelScore < 0.25 &&
        animalLabelScore < 0.25 &&
        structural.faceCount == 0 &&
        documentnessScoreValue < 0.35 &&
        summary.foodCueStrength < 0.30 &&
        summary.foodCueCount == 0 &&
        screenshotLabelScore < 0.30 &&
        techLabelScore < 0.30 &&
        vehicleLabelScore < 0.30 &&
        _maxConfidenceForKeywords(labels, const ['grass', 'land', 'outdoor', 'structure', 'sky', 'wood']) >=
            0.30;

    final emojiOverlayScore = structural.hasEmojiOverlay ? 0.70 : 0.0;
    final plainBackgroundFallbackScore = plainBackgroundGenericEnvOnly ? 0.65 : 0.0;

    return DerivedSignals(
      humanPresenceScore: _clamp01(
        math.max(
          humanLabelScore,
          math.max(structuralFaceAreaScore, structuralMultipleFacesScore),
        ),
      ),
      animalPresenceScore: animalPresenceScoreValue,
      graphicnessScore: _clamp01(
        math.max(
          graphicLabelScore,
          math.max(
            structuralGraphicScore,
            math.max(
              structuralFaceWithoutHumanLabel ? 0.70 : 0.0,
              math.max(
                isDevicePhotoContext ? 0.0 : structuralQuoteCardScore,
                math.max(
                  isLikelyNonPhotoArtwork ? 0.68 : 0.0,
                  math.max(
                    structuralMangaComicOcrScore,
                    math.max(
                      monochromeArtworkLikely ? 0.68 : 0.0,
                      math.max(
                        animatedAnimalLikely ? 0.68 : 0.0,
                        math.max(
                          emojiOverlayScore,
                          plainBackgroundFallbackScore,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      documentnessScore: documentnessScoreValue,
      sceneDensityScore: sceneDensityScoreValue,
      uiDensityScore: _clamp01(
        math.max(chatUiScore, math.max(tableUiScore, textUiScore)),
      ),
    );
  }

  static double _maxConfidenceForKeywords(
    List<ClassificationLabel> labels,
    List<String> keywords,
  ) {
    var maxConfidence = 0.0;

    for (final label in labels) {
      final normalized = label.displayName.toLowerCase();
      final matches = keywords.any(normalized.contains);
      if (matches && label.confidence > maxConfidence) {
        maxConfidence = label.confidence;
      }
    }

    return maxConfidence;
  }

  static double _clamp01(double value) {
    if (value <= 0) {
      return 0;
    }
    if (value >= 1) {
      return 1;
    }
    return value;
  }
}
