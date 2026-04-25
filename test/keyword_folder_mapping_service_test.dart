import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter_v1/data/services/keyword_folder_mapping_service.dart';
import 'package:hive_flutter_v1/domain/entities/classification_label.dart';
import 'package:hive_flutter_v1/domain/entities/media_asset.dart';

void main() {
  final service = KeywordFolderMappingService(
    now: () => DateTime(2026, 4, 20, 12),
  );

  test('maps generic portrait signals into People', () {
    final explanation = service.explainPlacement(
      asset: _imageAsset(id: 'people_1'),
      labels: [
        _label('portrait', 0.94),
        _label('face', 0.88),
        _label('person', 0.82),
      ],
    );

    expect(explanation.cellId, 'people');
    expect(explanation.usedFallback, isFalse);
    expect(explanation.matchedKeywords, contains('general people signal'));
  });

  test(
    'maps real people photos into People even without portrait-perfect labels',
    () {
      final explanation = service.explainPlacement(
        asset: _imageAsset(id: 'people_2'),
        labels: [
          _label('woman', 0.79),
          _label('smile', 0.68),
          _label('friends', 0.62),
        ],
      );

      expect(explanation.cellId, 'people');
      expect(explanation.usedFallback, isFalse);
      expect(explanation.matchedKeywords, contains('confident people cluster'));
    },
  );

  test('maps stronger family cues into Family over People', () {
    final explanation = service.explainPlacement(
      asset: _imageAsset(id: 'family_1'),
      labels: [
        _label('family', 0.94),
        _label('child', 0.87),
        _label('person', 0.8),
      ],
    );

    expect(explanation.cellId, 'family');
    expect(explanation.usedFallback, isFalse);
    expect(explanation.matchedKeywords, contains('shared family moment'));
  });

  test('maps screenshot-like filenames and UI labels into Screenshots', () {
    final explanation = service.explainPlacement(
      asset: _imageAsset(
        id: 'screen_1',
        filename: 'Screenshot 2026-04-20 at 08.41.10.png',
        width: 1179,
        height: 2556,
      ),
      labels: [_label('user interface', 0.84), _label('text message', 0.77)],
    );

    expect(explanation.cellId, 'screenshots');
    expect(explanation.usedFallback, isFalse);
    expect(explanation.matchedKeywords, contains('filename screenshot'));
  });

  test('maps scenery and location imagery into Places', () {
    final explanation = service.explainPlacement(
      asset: _imageAsset(id: 'place_1', filename: 'sunset_overlook.jpg'),
      labels: [
        _label('landscape', 0.9),
        _label('sky', 0.78),
        _label('bridge', 0.61),
      ],
    );

    expect(explanation.cellId, 'places');
    expect(explanation.usedFallback, isFalse);
    expect(explanation.matchedKeywords, contains('strong place cluster'));
  });

  test('maps strong food imagery into Food instead of Unsorted', () {
    final explanation = service.explainPlacement(
      asset: _imageAsset(id: 'food_1'),
      labels: [
        _label('dish', 0.82),
        _label('plate', 0.76),
        _label('restaurant', 0.63),
      ],
    );

    expect(explanation.cellId, 'food');
    expect(explanation.usedFallback, isFalse);
    expect(explanation.matchedKeywords, contains('strong food cluster'));
  });

  test('routes video assets into Videos deterministically', () {
    final explanation = service.explainPlacement(
      asset: MediaAsset(
        id: 'video_1',
        type: MediaAssetType.video,
        createdAt: DateTime(2026, 4, 20, 12),
        modifiedAt: DateTime(2026, 4, 20, 12),
        width: 1920,
        height: 1080,
        duration: const Duration(seconds: 9),
        originalFilename: 'IMG_0420.MOV',
      ),
      labels: const [],
    );

    expect(explanation.cellId, 'videos');
    expect(explanation.usedFallback, isFalse);
    expect(explanation.matchedKeywords, contains('video asset'));
  });

  test('prefers Screenshots over People when UI signals are stronger', () {
    final explanation = service.explainPlacement(
      asset: _imageAsset(
        id: 'screen_people_1',
        filename: 'Screenshot 2026-04-20 at 10.11.12.png',
        width: 1179,
        height: 2556,
      ),
      labels: [
        _label('text message', 0.91),
        _label('user interface', 0.88),
        _label('person', 0.57),
      ],
    );

    expect(explanation.cellId, 'screenshots');
    expect(explanation.matchedKeywords, contains('screen signal dominates'));
  });

  test('prefers Documents over People for passport-like assets with faces', () {
    final explanation = service.explainPlacement(
      asset: _imageAsset(
        id: 'document_people_1',
        filename: 'passport_scan.jpg',
      ),
      labels: [
        _label('passport', 0.95),
        _label('document', 0.86),
        _label('face', 0.71),
        _label('person', 0.64),
      ],
    );

    expect(explanation.cellId, 'documents_receipts');
    expect(explanation.matchedKeywords, contains('identity document'));
  });

  test('does not let weak pet cues overpower stronger place signals', () {
    final explanation = service.explainPlacement(
      asset: _imageAsset(id: 'pet_false_positive_1'),
      labels: [
        _label('pet', 0.56),
        _label('landscape', 0.88),
        _label('sky', 0.73),
      ],
    );

    expect(explanation.cellId, 'places');
    expect(explanation.cellId, isNot('pets'));
  });

  test('maps stylized cartoon and meme-like assets into Animation', () {
    final explanation = service.explainPlacement(
      asset: _imageAsset(
        id: 'animation_1',
        filename: 'funny_meme_reaction.png',
      ),
      labels: [
        _label('cartoon', 0.9),
        _label('fictional character', 0.82),
        _label('illustration', 0.8),
      ],
    );

    expect(explanation.cellId, 'animation_cartoon_meme');
    expect(explanation.usedFallback, isFalse);
    expect(explanation.matchedKeywords, contains('strong stylized cluster'));
  });

  test('falls back to Unsorted for weak unmapped labels', () {
    final explanation = service.explainPlacement(
      asset: _imageAsset(id: 'unsorted_1'),
      labels: [_label('texture', 0.32), _label('pattern', 0.29)],
    );

    expect(explanation.cellId, 'unsorted');
    expect(explanation.usedFallback, isTrue);
  });
}

MediaAsset _imageAsset({
  required String id,
  String? filename,
  int width = 1200,
  int height = 1600,
}) {
  return MediaAsset(
    id: id,
    type: MediaAssetType.image,
    createdAt: DateTime(2026, 4, 20, 12),
    modifiedAt: DateTime(2026, 4, 20, 12),
    width: width,
    height: height,
    originalFilename: filename ?? 'IMG_$id.HEIC',
  );
}

ClassificationLabel _label(String name, double confidence) {
  return ClassificationLabel(
    id: name,
    key: name,
    displayName: name,
    confidence: confidence,
    source: ClassificationLabelSource.onDeviceModel,
    createdAt: DateTime(2026, 4, 20, 12),
    modelIdentifier: 'test',
  );
}
