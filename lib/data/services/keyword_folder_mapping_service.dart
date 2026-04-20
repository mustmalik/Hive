import '../../application/models/asset_mapping_explanation.dart';
import '../../application/services/folder_mapping_service.dart';
import '../../domain/entities/classification_label.dart';
import '../../domain/entities/folder_cell.dart';
import '../../domain/entities/manual_override.dart';
import '../../domain/entities/media_asset.dart';

class KeywordFolderMappingService implements FolderMappingService {
  KeywordFolderMappingService({DateTime Function()? now})
    : _now = now ?? DateTime.now;

  static const Set<String> _familyCueKeywords = {
    'family',
    'parent',
    'parents',
    'mother',
    'father',
    'mom',
    'dad',
    'baby',
    'infant',
    'toddler',
    'child',
    'children',
    'siblings',
    'brother',
    'sister',
    'wedding',
    'bride',
    'groom',
    'couple',
    'husband',
    'wife',
    'spouse',
    'newborn',
    'son',
    'daughter',
    'grandmother',
    'grandfather',
    'grandma',
    'grandpa',
    'relative',
    'reunion',
  };

  static const Set<String> _peopleCueKeywords = {
    'person',
    'people',
    'human',
    'human being',
    'portrait',
    'selfie',
    'face',
    'head',
    'facial expression',
    'smile',
    'man',
    'woman',
    'boy',
    'girl',
    'crowd',
    'group',
    'adult',
    'teen',
    'teenager',
    'friend',
    'friends',
  };

  static const Set<String> _screenshotFilenameKeywords = {
    'screenshot',
    'screen shot',
    'screen capture',
    'screen_recording',
    'screen recording',
  };

  static const Set<String> _screenshotCueKeywords = {
    'screenshot',
    'screen',
    'screen capture',
    'user interface',
    'interface',
    'software',
    'web page',
    'website',
    'application',
    'app',
    'text message',
    'message',
    'notification',
    'menu',
    'chat',
    'social media',
    'display',
  };

  static const Set<String> _animationCueKeywords = {
    'cartoon',
    'animation',
    'anime',
    'animated cartoon',
    'illustration',
    'drawing',
    'graphic design',
    'comic',
    'meme',
    'sticker',
    'mascot',
    'clip art',
    'fictional character',
    'character',
    'digital art',
    'artwork',
    'sketch',
    'doodle',
    'avatar',
    'pixel art',
  };

  static const Set<String> _animationFilenameKeywords = {
    'meme',
    'sticker',
    'anime',
    'cartoon',
    'comic',
    'reaction',
    'avatar',
    'gif',
  };

  static const List<_CellRule> _rules = [
    _CellRule(
      cellId: 'family',
      cellName: 'Family',
      description: 'Parents, siblings, children, and close shared moments',
      styleKey: 'family',
      featured: true,
      keywords: {
        'family',
        'parent',
        'parents',
        'mother',
        'father',
        'mom',
        'dad',
        'baby',
        'infant',
        'toddler',
        'child',
        'children',
        'siblings',
        'brother',
        'sister',
        'wedding',
        'bride',
        'groom',
        'couple',
        'husband',
        'wife',
        'spouse',
        'newborn',
        'son',
        'daughter',
        'grandmother',
        'grandfather',
        'grandma',
        'grandpa',
        'relative',
        'reunion',
      },
      priorityBias: 0.14,
    ),
    _CellRule(
      cellId: 'people',
      cellName: 'People',
      description: 'Portraits, selfies, crowds, and human moments',
      styleKey: 'people',
      featured: true,
      keywords: {
        'person',
        'people',
        'human',
        'human being',
        'portrait',
        'selfie',
        'face',
        'head',
        'facial expression',
        'smile',
        'man',
        'woman',
        'boy',
        'girl',
        'crowd',
        'group',
        'adult',
        'teen',
        'teenager',
        'friend',
        'friends',
      },
      priorityBias: 0.16,
    ),
    _CellRule(
      cellId: 'pets',
      cellName: 'Pets',
      description: 'Pets, familiar faces, and daily companions',
      styleKey: 'pets',
      featured: true,
      keywords: {
        'dog',
        'dogs',
        'puppy',
        'canine',
        'pet',
        'pets',
        'animal',
        'mammal',
        'domestic animal',
        'companion animal',
        'domestic dog',
        'golden retriever',
        'retriever',
        'cat',
        'cats',
        'kitten',
        'feline',
        'domestic cat',
      },
      priorityBias: 0.14,
    ),
    _CellRule(
      cellId: 'travel',
      cellName: 'Travel',
      description: 'Trips, landmarks, and places worth revisiting',
      styleKey: 'travel',
      keywords: {
        'travel',
        'vacation',
        'tourism',
        'tourist',
        'beach',
        'ocean',
        'mountain',
        'landscape',
        'city',
        'skyline',
        'bridge',
        'airplane',
        'aircraft',
        'airport',
        'hotel',
        'road trip',
        'destination',
        'landmark',
      },
    ),
    _CellRule(
      cellId: 'food',
      cellName: 'Food',
      description: 'Meals, drinks, and things worth ordering again',
      styleKey: 'food',
      keywords: {
        'food',
        'meal',
        'dish',
        'dessert',
        'drink',
        'beverage',
        'cuisine',
        'pizza',
        'burger',
        'pasta',
        'salad',
        'bread',
        'fruit',
        'vegetable',
        'produce',
        'plate',
        'restaurant',
        'coffee',
      },
    ),
    _CellRule(
      cellId: 'screenshots',
      cellName: 'Screenshots',
      description: 'Captured screens, app states, and saved references',
      styleKey: 'screenshots',
      keywords: {
        'screenshot',
        'screen',
        'screen capture',
        'user interface',
        'interface',
        'software',
        'web page',
        'application',
        'app',
        'text message',
        'message',
        'notification',
        'menu',
        'chat',
        'social media',
        'website',
        'display',
      },
      assetTypes: {MediaAssetType.screenshot},
      priorityBias: 0.25,
    ),
    _CellRule(
      cellId: 'devices_tech',
      cellName: 'Devices / Tech',
      description: 'Gadgets, workstations, and everyday tech scenes',
      styleKey: 'tech',
      keywords: {
        'computer',
        'laptop',
        'desktop computer',
        'monitor',
        'keyboard',
        'mouse',
        'tablet computer',
        'tablet',
        'mobile phone',
        'smartphone',
        'camera',
        'electronics',
        'technology',
        'device',
        'headphones',
        'headset',
      },
    ),
    _CellRule(
      cellId: 'documents_receipts',
      cellName: 'Documents / Receipts',
      description: 'Paperwork, receipts, and reference documents',
      styleKey: 'documents',
      keywords: {
        'document',
        'text',
        'paper',
        'receipt',
        'invoice',
        'bill',
        'form',
        'letter',
        'menu',
        'certificate',
        'page',
        'poster',
      },
      priorityBias: 0.08,
    ),
    _CellRule(
      cellId: 'sports',
      cellName: 'Sports',
      description: 'Courts, fields, games, and training moments',
      styleKey: 'sports',
      keywords: {
        'sport',
        'sports',
        'athlete',
        'stadium',
        'arena',
        'court',
        'field',
        'ball',
        'basketball',
        'basketball hoop',
        'basketball court',
        'football',
        'soccer',
        'tennis',
        'baseball',
        'running',
        'gym',
        'jersey',
        'race',
      },
      priorityBias: 0.08,
    ),
    _CellRule(
      cellId: 'animation_cartoon_meme',
      cellName: 'Animation / Cartoon / Meme',
      description: 'Cartoons, anime, memes, and stylized art',
      styleKey: 'animation',
      keywords: {
        'cartoon',
        'animation',
        'anime',
        'animated cartoon',
        'illustration',
        'drawing',
        'graphic design',
        'comic',
        'meme',
        'sticker',
        'mascot',
        'clip art',
        'fictional character',
        'character',
        'digital art',
        'artwork',
        'sketch',
        'doodle',
        'avatar',
        'pixel art',
      },
      priorityBias: 0.16,
    ),
  ];

  static const _CellRule _unsortedRule = _CellRule(
    cellId: 'unsorted',
    cellName: 'Unsorted',
    description: 'Assets that still need a stronger signal',
    styleKey: 'unsorted',
    keywords: {},
  );

  static const double _fallbackThreshold = 0.26;
  static const int _maxExplanationLabels = 4;

  final DateTime Function() _now;

  @override
  Future<List<FolderCell>> buildSuggestedCells({
    required List<MediaAsset> assets,
    required Map<String, List<ClassificationLabel>> labelsByAssetId,
    List<ManualOverride> overrides = const [],
  }) async {
    final now = _now();
    final includeOverridesByAssetId = _resolveIncludeOverrides(overrides);
    final assetsByCellId = <String, List<String>>{};
    final labelIdsByCellId = <String, Set<String>>{};
    final coverAssetIdByCellId = <String, String>{};

    for (final asset in assets) {
      final override = includeOverridesByAssetId[asset.id];
      final explanation = override == null
          ? explainPlacement(
              asset: asset,
              labels: labelsByAssetId[asset.id] ?? const [],
            )
          : _manualOverrideExplanation(
              asset: asset,
              cellId: override.cellId!,
              labels: labelsByAssetId[asset.id] ?? const [],
            );

      assetsByCellId
          .putIfAbsent(explanation.cellId, () => <String>[])
          .add(asset.id);

      if (!coverAssetIdByCellId.containsKey(explanation.cellId)) {
        coverAssetIdByCellId[explanation.cellId] = asset.id;
      }

      final labelIds = labelIdsByCellId.putIfAbsent(
        explanation.cellId,
        () => <String>{},
      );
      for (final label
          in labelsByAssetId[asset.id] ?? const <ClassificationLabel>[]) {
        labelIds.add(label.id);
      }
    }

    final orderedRules = [
      ..._rules.where((rule) => assetsByCellId.containsKey(rule.cellId)),
      if (assetsByCellId.containsKey(_unsortedRule.cellId)) _unsortedRule,
    ];

    return orderedRules
        .map(
          (rule) => FolderCell(
            id: rule.cellId,
            name: rule.cellName,
            origin: FolderCellOrigin.suggested,
            createdAt: now,
            updatedAt: now,
            description: rule.description,
            coverAssetId: coverAssetIdByCellId[rule.cellId],
            labelIds: (labelIdsByCellId[rule.cellId] ?? const <String>{})
                .toList(growable: false),
            assetIds: List<String>.unmodifiable(
              assetsByCellId[rule.cellId] ?? const <String>[],
            ),
            isPinned: rule.featured,
          ),
        )
        .toList(growable: false);
  }

  Map<String, ManualOverride> _resolveIncludeOverrides(
    List<ManualOverride> overrides,
  ) {
    final result = <String, ManualOverride>{};

    for (final override in overrides) {
      if (override.action != ManualOverrideAction.includeInCell ||
          override.cellId == null) {
        continue;
      }

      final existing = result[override.assetId];
      if (existing == null || override.createdAt.isAfter(existing.createdAt)) {
        result[override.assetId] = override;
      }
    }

    return result;
  }

  AssetMappingExplanation _manualOverrideExplanation({
    required MediaAsset asset,
    required String cellId,
    required List<ClassificationLabel> labels,
  }) {
    final rule = _ruleForCellId(cellId) ?? _unsortedRule;
    final sortedLabels = List<ClassificationLabel>.from(labels)
      ..sort((left, right) => right.confidence.compareTo(left.confidence));

    return AssetMappingExplanation(
      cellId: rule.cellId,
      cellName: rule.cellName,
      score: 1.5,
      usedFallback: false,
      topLabels: sortedLabels
          .take(_maxExplanationLabels)
          .toList(growable: false),
      matchedKeywords: const ['manual override'],
      isManualOverride: true,
    );
  }

  _CellRule? _ruleForCellId(String cellId) {
    for (final rule in _rules) {
      if (rule.cellId == cellId) {
        return rule;
      }
    }
    if (_unsortedRule.cellId == cellId) {
      return _unsortedRule;
    }
    return null;
  }

  @override
  AssetMappingExplanation explainPlacement({
    required MediaAsset asset,
    required List<ClassificationLabel> labels,
  }) {
    final sortedLabels = List<ClassificationLabel>.from(labels)
      ..sort((left, right) => right.confidence.compareTo(left.confidence));
    final topLabels = sortedLabels
        .take(_maxExplanationLabels)
        .toList(growable: false);

    if (topLabels.isEmpty && asset.type != MediaAssetType.screenshot) {
      return AssetMappingExplanation(
        cellId: _unsortedRule.cellId,
        cellName: _unsortedRule.cellName,
        score: 0,
        usedFallback: true,
        topLabels: const [],
      );
    }

    _RuleScore? bestScore;
    for (final rule in _rules) {
      final current = _scoreRule(rule: rule, asset: asset, labels: topLabels);
      if (bestScore == null || current.score > bestScore.score) {
        bestScore = current;
      }
    }

    if (bestScore == null || bestScore.score < _fallbackThreshold) {
      return AssetMappingExplanation(
        cellId: _unsortedRule.cellId,
        cellName: _unsortedRule.cellName,
        score: bestScore?.score ?? 0,
        usedFallback: true,
        topLabels: topLabels,
        matchedKeywords: bestScore?.matchedKeywords ?? const [],
      );
    }

    return AssetMappingExplanation(
      cellId: bestScore.rule.cellId,
      cellName: bestScore.rule.cellName,
      score: bestScore.score,
      usedFallback: false,
      topLabels: topLabels,
      matchedKeywords: bestScore.matchedKeywords,
    );
  }

  _RuleScore _scoreRule({
    required _CellRule rule,
    required MediaAsset asset,
    required List<ClassificationLabel> labels,
  }) {
    var score = rule.priorityBias;
    final matchedKeywords = <String>{};
    final normalizedFilename = _normalize(asset.originalFilename ?? '');
    final filenameTokens = _tokenize(normalizedFilename);

    if (rule.assetTypes.contains(asset.type)) {
      score += 0.9;
      matchedKeywords.add(asset.type.name);
    }

    for (var index = 0; index < labels.length; index++) {
      final label = labels[index];
      final normalized = _normalize(label.displayName);
      final tokens = _tokenize(normalized);
      final rankWeight = 1 - (index * 0.12);
      final effectiveWeight = rankWeight < 0.55 ? 0.55 : rankWeight;

      for (final keyword in rule.keywords) {
        final keywordMatch = _keywordMatch(
          keyword: keyword,
          tokens: tokens,
          normalized: normalized,
        );
        if (keywordMatch <= 0) {
          continue;
        }

        score += label.confidence * effectiveWeight * keywordMatch;
        matchedKeywords.add(keyword);
      }
    }

    score += _applyRuleSpecificBoosts(
      rule: rule,
      asset: asset,
      labels: labels,
      normalizedFilename: normalizedFilename,
      filenameTokens: filenameTokens,
      matchedKeywords: matchedKeywords,
    );

    return _RuleScore(
      rule: rule,
      score: score,
      matchedKeywords: matchedKeywords.toList(growable: false),
    );
  }

  double _keywordMatch({
    required String keyword,
    required Set<String> tokens,
    required String normalized,
  }) {
    final normalizedKeyword = _normalize(keyword);
    if (normalized == normalizedKeyword) {
      return 1.18;
    }

    if (tokens.contains(normalizedKeyword)) {
      return 1.0;
    }

    final allowSubstringMatch =
        normalized.contains(' ') ||
        normalizedKeyword.contains(' ') ||
        (normalized.length >= 7 && normalizedKeyword.length >= 7);

    if (allowSubstringMatch &&
        (normalized.contains(normalizedKeyword) ||
            normalizedKeyword.contains(normalized))) {
      return 0.96;
    }

    final keywordTokens = _tokenize(normalizedKeyword);
    if (keywordTokens.isEmpty) {
      return 0;
    }

    final overlap = tokens.intersection(keywordTokens).length;
    if (overlap == 0) {
      return 0;
    }

    if (overlap == keywordTokens.length || overlap == tokens.length) {
      return 0.9;
    }

    final coverage = overlap / keywordTokens.length;
    if (coverage >= 0.5) {
      return 0.62;
    }

    return 0.38;
  }

  double _applyRuleSpecificBoosts({
    required _CellRule rule,
    required MediaAsset asset,
    required List<ClassificationLabel> labels,
    required String normalizedFilename,
    required Set<String> filenameTokens,
    required Set<String> matchedKeywords,
  }) {
    final cueSummary = _summarizeSignals(labels);

    return switch (rule.cellId) {
      'family' => _familyBoost(
        cueSummary: cueSummary,
        normalizedFilename: normalizedFilename,
        matchedKeywords: matchedKeywords,
      ),
      'people' => _peopleBoost(
        cueSummary: cueSummary,
        matchedKeywords: matchedKeywords,
      ),
      'screenshots' => _screenshotBoost(
        asset: asset,
        cueSummary: cueSummary,
        normalizedFilename: normalizedFilename,
        filenameTokens: filenameTokens,
        matchedKeywords: matchedKeywords,
      ),
      'animation_cartoon_meme' => _animationBoost(
        cueSummary: cueSummary,
        normalizedFilename: normalizedFilename,
        filenameTokens: filenameTokens,
        matchedKeywords: matchedKeywords,
      ),
      _ => 0,
    };
  }

  double _familyBoost({
    required _CueSummary cueSummary,
    required String normalizedFilename,
    required Set<String> matchedKeywords,
  }) {
    var bonus = 0.0;

    if (cueSummary.familyCueCount > 0) {
      bonus += 0.18;
      matchedKeywords.add('family cue');
    }

    if (cueSummary.familyCueCount > 0 && cueSummary.peopleCueCount > 0) {
      bonus += 0.34;
      matchedKeywords.add('shared family moment');
    }

    if (normalizedFilename.contains('family')) {
      bonus += 0.45;
      matchedKeywords.add('filename family');
    }

    return bonus;
  }

  double _peopleBoost({
    required _CueSummary cueSummary,
    required Set<String> matchedKeywords,
  }) {
    var bonus = 0.0;

    if (cueSummary.peopleCueCount > 0) {
      bonus += 0.18;
      matchedKeywords.add('people cue');
    }

    if (cueSummary.peopleCueCount > 0 && cueSummary.familyCueCount == 0) {
      bonus += 0.24;
      matchedKeywords.add('general people signal');
    }

    if (cueSummary.crowdCueCount > 0) {
      bonus += 0.16;
      matchedKeywords.add('crowd or group');
    }

    return bonus;
  }

  double _screenshotBoost({
    required MediaAsset asset,
    required _CueSummary cueSummary,
    required String normalizedFilename,
    required Set<String> filenameTokens,
    required Set<String> matchedKeywords,
  }) {
    var bonus = 0.0;
    var hasScreenshotSignal = false;

    if (asset.type == MediaAssetType.screenshot) {
      bonus += 0.42;
      matchedKeywords.add('native screenshot');
      hasScreenshotSignal = true;
    }

    if (_matchesFilenameCue(
      normalizedFilename: normalizedFilename,
      filenameTokens: filenameTokens,
      cues: _screenshotFilenameKeywords,
    )) {
      bonus += 0.72;
      matchedKeywords.add('filename screenshot');
      hasScreenshotSignal = true;
    }

    if (cueSummary.screenshotCueCount > 0) {
      bonus += 0.18 + (cueSummary.screenshotCueCount * 0.08);
      matchedKeywords.add('ui signal');
      hasScreenshotSignal = true;
    }

    if (hasScreenshotSignal &&
        asset.width > 0 &&
        asset.height > 0 &&
        (asset.width - asset.height).abs() > 180) {
      bonus += 0.06;
      matchedKeywords.add('screen aspect');
    }

    return bonus;
  }

  double _animationBoost({
    required _CueSummary cueSummary,
    required String normalizedFilename,
    required Set<String> filenameTokens,
    required Set<String> matchedKeywords,
  }) {
    var bonus = 0.0;

    if (_matchesFilenameCue(
      normalizedFilename: normalizedFilename,
      filenameTokens: filenameTokens,
      cues: _animationFilenameKeywords,
    )) {
      bonus += 0.55;
      matchedKeywords.add('filename stylized');
    }

    if (cueSummary.animationCueCount > 0) {
      bonus += 0.24 + (cueSummary.animationCueCount * 0.09);
      matchedKeywords.add('stylized cue');
    }

    if (cueSummary.animationCueCount >= 2) {
      bonus += 0.2;
      matchedKeywords.add('strong stylized cluster');
    }

    return bonus;
  }

  _CueSummary _summarizeSignals(List<ClassificationLabel> labels) {
    var familyCueCount = 0;
    var peopleCueCount = 0;
    var screenshotCueCount = 0;
    var animationCueCount = 0;
    var crowdCueCount = 0;

    for (final label in labels) {
      final normalized = _normalize(label.displayName);
      final tokens = _tokenize(normalized);

      if (_matchesCueSet(
        normalized: normalized,
        tokens: tokens,
        cues: _familyCueKeywords,
      )) {
        familyCueCount += 1;
      }

      if (_matchesCueSet(
        normalized: normalized,
        tokens: tokens,
        cues: _peopleCueKeywords,
      )) {
        peopleCueCount += 1;
      }

      if (_matchesCueSet(
        normalized: normalized,
        tokens: tokens,
        cues: _screenshotCueKeywords,
      )) {
        screenshotCueCount += 1;
      }

      if (_matchesCueSet(
        normalized: normalized,
        tokens: tokens,
        cues: _animationCueKeywords,
      )) {
        animationCueCount += 1;
      }

      if (tokens.contains('crowd') ||
          tokens.contains('group') ||
          normalized.contains('group photo')) {
        crowdCueCount += 1;
      }
    }

    return _CueSummary(
      familyCueCount: familyCueCount,
      peopleCueCount: peopleCueCount,
      screenshotCueCount: screenshotCueCount,
      animationCueCount: animationCueCount,
      crowdCueCount: crowdCueCount,
    );
  }

  bool _matchesCueSet({
    required String normalized,
    required Set<String> tokens,
    required Set<String> cues,
  }) {
    for (final cue in cues) {
      if (_keywordMatch(keyword: cue, tokens: tokens, normalized: normalized) >
          0) {
        return true;
      }
    }
    return false;
  }

  bool _matchesFilenameCue({
    required String normalizedFilename,
    required Set<String> filenameTokens,
    required Set<String> cues,
  }) {
    if (normalizedFilename.isEmpty) {
      return false;
    }

    for (final cue in cues) {
      if (_keywordMatch(
            keyword: cue,
            tokens: filenameTokens,
            normalized: normalizedFilename,
          ) >
          0) {
        return true;
      }
    }

    return false;
  }

  String _normalize(String value) {
    final trimmed = value.toLowerCase().replaceAll(RegExp(r'[_:/-]+'), ' ');
    return trimmed
        .replaceAll(RegExp(r'[^a-z0-9 ]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Set<String> _tokenize(String value) {
    if (value.isEmpty) {
      return const <String>{};
    }

    return value.split(' ').where((token) => token.isNotEmpty).toSet();
  }
}

class _CellRule {
  const _CellRule({
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

class _RuleScore {
  const _RuleScore({
    required this.rule,
    required this.score,
    required this.matchedKeywords,
  });

  final _CellRule rule;
  final double score;
  final List<String> matchedKeywords;
}

class _CueSummary {
  const _CueSummary({
    required this.familyCueCount,
    required this.peopleCueCount,
    required this.screenshotCueCount,
    required this.animationCueCount,
    required this.crowdCueCount,
  });

  final int familyCueCount;
  final int peopleCueCount;
  final int screenshotCueCount;
  final int animationCueCount;
  final int crowdCueCount;
}
