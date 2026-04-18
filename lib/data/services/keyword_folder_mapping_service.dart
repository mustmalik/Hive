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
        'animal',
        'cat',
        'cats',
        'dog',
        'dogs',
        'pet',
        'pets',
        'puppy',
        'kitten',
        'canine',
        'feline',
        'horse',
        'bird',
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
      final matchedRule = _resolveRule(
        labels: labelsByAssetId[asset.id] ?? const [],
      );

      assetsByCellId
          .putIfAbsent(matchedRule.cellId, () => <String>[])
          .add(asset.id);

      if (!coverAssetIdByCellId.containsKey(matchedRule.cellId)) {
        coverAssetIdByCellId[matchedRule.cellId] = asset.id;
      }

      final labelIds = labelIdsByCellId.putIfAbsent(
        matchedRule.cellId,
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

  _CellRule _resolveRule({required List<ClassificationLabel> labels}) {
    if (labels.isEmpty) {
      return _unsortedRule;
    }

    var bestRule = _unsortedRule;
    var bestScore = 0.0;

    for (final rule in _rules) {
      final score = _scoreRule(rule: rule, labels: labels);
      if (score > bestScore) {
        bestScore = score;
        bestRule = rule;
      }
    }

    if (bestScore <= 0) {
      return _unsortedRule;
    }

    return bestRule;
  }

  double _scoreRule({
    required _CellRule rule,
    required List<ClassificationLabel> labels,
  }) {
    var score = 0.0;

    for (final label in labels) {
      final haystacks = [
        label.displayName.toLowerCase(),
        label.key.toLowerCase(),
      ];

      for (final keyword in rule.keywords) {
        if (haystacks.any((value) => value.contains(keyword))) {
          score += label.confidence;
          break;
        }
      }
    }

    return score;
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
