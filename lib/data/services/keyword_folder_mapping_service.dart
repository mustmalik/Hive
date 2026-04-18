import '../../application/models/asset_mapping_explanation.dart';
import '../../application/services/folder_mapping_service.dart';
import '../../domain/entities/classification_label.dart';
import '../../domain/entities/folder_cell.dart';
import '../../domain/entities/manual_override.dart';
import '../../domain/entities/media_asset.dart';

class KeywordFolderMappingService implements FolderMappingService {
  KeywordFolderMappingService({DateTime Function()? now})
    : _now = now ?? DateTime.now;

  static const List<_CellRule> _rules = [
    _CellRule(
      cellId: 'pets',
      cellName: 'Pets',
      description: 'Pets, familiar faces, and daily companions',
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
    ),
    _CellRule(
      cellId: 'travel',
      cellName: 'Travel',
      description: 'Trips, landmarks, and places worth revisiting',
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
        'road',
        'destination',
      },
    ),
    _CellRule(
      cellId: 'food',
      cellName: 'Food',
      description: 'Meals, drinks, and things worth ordering again',
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
      },
    ),
    _CellRule(
      cellId: 'basketball',
      cellName: 'Basketball',
      description: 'Courtside moments, games, and training clips',
      keywords: {
        'basketball',
        'basketball hoop',
        'basketball court',
        'sports equipment',
        'ball',
        'athlete',
        'jersey',
        'stadium',
        'arena',
        'sport venue',
      },
    ),
  ];

  static const _CellRule _unsortedRule = _CellRule(
    cellId: 'unsorted',
    cellName: 'Unsorted',
    description: 'Assets that still need a stronger signal',
    keywords: {},
  );

  static const double _fallbackThreshold = 0.24;
  static const int _maxExplanationLabels = 4;

  final DateTime Function() _now;

  @override
  Future<List<FolderCell>> buildSuggestedCells({
    required List<MediaAsset> assets,
    required Map<String, List<ClassificationLabel>> labelsByAssetId,
    List<ManualOverride> overrides = const [],
  }) async {
    final now = _now();
    final assetsByCellId = <String, List<String>>{};
    final labelIdsByCellId = <String, Set<String>>{};
    final coverAssetIdByCellId = <String, String>{};

    for (final asset in assets) {
      final explanation = explainPlacement(
        asset: asset,
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
          ),
        )
        .toList(growable: false);
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

    if (topLabels.isEmpty) {
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
      final current = _scoreRule(rule: rule, labels: topLabels);
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
    required List<ClassificationLabel> labels,
  }) {
    var score = 0.0;
    final matchedKeywords = <String>{};

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
    if (normalized.contains(normalizedKeyword) ||
        normalizedKeyword.contains(normalized)) {
      return 1.0;
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
      return 0.92;
    }

    final coverage = overlap / keywordTokens.length;
    if (coverage >= 0.5) {
      return 0.62;
    }

    return 0.38;
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
    required this.keywords,
  });

  final String cellId;
  final String cellName;
  final String description;
  final Set<String> keywords;
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
