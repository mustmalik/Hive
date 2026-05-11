import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter_v1/application/models/asset_mapping_explanation.dart';
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
    expect(explanation.secondarySupport, contains('general people signal'));
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
      expect(
        explanation.secondarySupport,
        contains('confident people cluster'),
      );
    },
  );

  test('maps former family cues into People', () {
    final explanation = service.explainPlacement(
      asset: _imageAsset(id: 'family_1'),
      labels: [
        _label('family', 0.94),
        _label('child', 0.87),
        _label('person', 0.8),
      ],
    );

    expect(explanation.cellId, 'people');
    expect(explanation.usedFallback, isFalse);
  });

  test('keeps generic group photos in People', () {
    final explanation = service.explainPlacement(
      asset: _imageAsset(id: 'people_group_1'),
      labels: [
        _label('friends', 0.81),
        _label('group', 0.72),
        _label('smile', 0.64),
      ],
    );

    expect(explanation.cellId, 'people');
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
    expect(explanation.primaryEvidence, contains('filename screenshot'));
  });

  test('keeps WhatsApp-style chat screenshots in Screenshots over People', () {
    final explanation = service.explainPlacement(
      asset: _imageAsset(id: 'screen_chat_1', width: 1179, height: 2556),
      labels: [
        _label('whatsapp', 0.88),
        _label('text message', 0.84),
        _label('face', 0.56),
      ],
    );

    expect(explanation.cellId, 'screenshots');
    expect(explanation.cellId, isNot('people'));
    expect(explanation.usedFallback, isFalse);
  });

  test('keeps UI-heavy screenshots with background faces in Screenshots', () {
    final explanation = service.explainPlacement(
      asset: _imageAsset(
        id: 'screen_face_1',
        filename: 'IMG_20260420.PNG',
        width: 1179,
        height: 2556,
      ),
      labels: [
        _label('user interface', 0.85),
        _label('notification', 0.76),
        _label('person', 0.58),
      ],
    );

    expect(explanation.cellId, 'screenshots');
    expect(explanation.cellId, isNot('people'));
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
    expect(explanation.secondarySupport, contains('strong place cluster'));
  });

  test('maps mosque and architecture imagery into Places over Pets', () {
    final explanation = service.explainPlacement(
      asset: _imageAsset(id: 'place_3'),
      labels: [
        _label('mosque', 0.88),
        _label('architecture', 0.8),
        _label('pet', 0.54),
      ],
    );

    expect(explanation.cellId, 'places');
    expect(explanation.cellId, isNot('pets'));
    expect(explanation.usedFallback, isFalse);
  });

  test('keeps skyline scenery in Places instead of broad Travel', () {
    final explanation = service.explainPlacement(
      asset: _imageAsset(id: 'place_4'),
      labels: [
        _label('skyline', 0.84),
        _label('architecture', 0.73),
        _label('travel', 0.66),
      ],
    );

    expect(explanation.cellId, 'places');
    expect(explanation.cellId, isNot('travel'));
    expect(explanation.usedFallback, isFalse);
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
    expect(explanation.secondarySupport, contains('strong food cluster'));
  });

  test('keeps strong plated food out of Unsorted', () {
    final explanation = service.explainPlacement(
      asset: _imageAsset(id: 'food_2'),
      labels: [
        _label('sushi', 0.79),
        _label('plate', 0.68),
        _label('dinner', 0.63),
      ],
    );

    expect(explanation.cellId, 'food');
    expect(explanation.usedFallback, isFalse);
  });

  test('keeps Travel for real trip logistics context', () {
    final explanation = service.explainPlacement(
      asset: _imageAsset(id: 'travel_1'),
      labels: [
        _label('airport', 0.86),
        _label('suitcase', 0.74),
        _label('terminal', 0.69),
      ],
    );

    expect(explanation.cellId, 'travel');
    expect(explanation.usedFallback, isFalse);
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
    expect(explanation.primaryEvidence, contains('video asset'));
  });

  test(
    'routes screenshot-typed assets with primary people evidence into People',
    () {
      final explanation = service.explainPlacement(
        asset: MediaAsset(
          id: 'screen_native_1',
          type: MediaAssetType.screenshot,
          createdAt: DateTime(2026, 4, 20, 12),
          modifiedAt: DateTime(2026, 4, 20, 12),
          width: 1179,
          height: 2556,
          originalFilename: 'IMG_0420.PNG',
        ),
        labels: [
          _label('person', 0.97),
          _label('family', 0.93),
          _label('basketball', 0.88),
        ],
      );

      expect(explanation.cellId, 'people');
      expect(explanation.cellId, isNot('screenshots'));
      expect(explanation.cellId, isNot('sports'));
    },
  );

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
    expect(explanation.secondarySupport, contains('screen signal dominates'));
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
    expect(explanation.secondarySupport, contains('document style routing'));
    expect(
      explanation.matchedKeywords,
      isNot(contains('document style routing')),
    );
  });

  test(
    'prefers Documents for passport or ID copies even with visible faces',
    () {
      final explanation = service.explainPlacement(
        asset: _imageAsset(
          id: 'document_people_2',
          filename: 'id_copy_scan.jpg',
        ),
        labels: [
          _label('id card', 0.92),
          _label('document', 0.84),
          _label('face', 0.69),
          _label('person', 0.61),
        ],
      );

      expect(explanation.cellId, 'documents_receipts');
      expect(explanation.cellId, isNot('people'));
      expect(explanation.usedFallback, isFalse);
    },
  );

  test('prefers Documents for paperwork-like copies with incidental faces', () {
    final explanation = service.explainPlacement(
      asset: _imageAsset(id: 'document_people_3', filename: 'form_scan.jpg'),
      labels: [
        _label('form', 0.83),
        _label('paper', 0.74),
        _label('face', 0.52),
      ],
    );

    expect(explanation.cellId, 'documents_receipts');
    expect(explanation.cellId, isNot('people'));
  });

  test('lets chat-like UI screenshots beat weaker document-style text', () {
    final explanation = service.explainPlacement(
      asset: _imageAsset(id: 'screen_document_1', width: 1179, height: 2556),
      labels: [
        _label('whatsapp', 0.84),
        _label('chat', 0.8),
        _label('document', 0.58),
        _label('text', 0.56),
      ],
    );

    expect(explanation.cellId, 'screenshots');
    expect(explanation.cellId, isNot('documents_receipts'));
  });

  test(
    'keeps github style login pages out of Documents despite heavy text',
    () {
      final explanation = service.explainPlacement(
        asset: _imageAsset(
          id: 'login_screen_1',
          filename: 'github_login_monitor.jpg',
          width: 1440,
          height: 900,
        ),
        labels: [
          _label('browser', 0.91),
          _label('website', 0.88),
          _label('user interface', 0.86),
          _label('menu', 0.81),
          _label('document', 0.7),
          _label('text', 0.68),
        ],
      );

      expect(explanation.cellId, isNot('documents_receipts'));
      expect(
        explanation.cellId,
        anyOf('screenshots', 'devices_tech', 'unsorted'),
      );
    },
  );

  test('keeps laptop and monitor imagery out of Places', () {
    final explanation = service.explainPlacement(
      asset: _imageAsset(id: 'screen_device_1', width: 1440, height: 900),
      labels: [
        _label('laptop', 0.92),
        _label('monitor', 0.86),
        _label('landscape', 0.42),
      ],
    );

    expect(explanation.cellId, 'devices_tech');
    expect(explanation.cellId, isNot('places'));
    expect(explanation.usedFallback, isFalse);
  });

  test('presentation assets do not surface weak animal fallback', () {
    final explanation = service.explainPlacement(
      asset: _imageAsset(id: 'presentation_1', width: 1600, height: 900),
      labels: [
        _label('presentation', 0.89),
        _label('slideshow', 0.82),
        _label('classroom', 0.74),
        _label('animal', 0.29),
      ],
    );

    expect(explanation.cellId, isNot('places'));
    expect(explanation.cellId, isNot('documents_receipts'));
    expect(
      explanation.fallbackReason,
      isNot(UnsortedFallbackReason.lowConfidenceAnimal),
    );
  });

  test(
    'screen presentation assets do not drift into Documents on weak text',
    () {
      final explanation = service.explainPlacement(
        asset: _imageAsset(
          id: 'presentation_document_1',
          filename: 'presentation_board.jpg',
          width: 1600,
          height: 900,
        ),
        labels: [
          _label('monitor', 0.84),
          _label('presentation', 0.88),
          _label('slides', 0.81),
          _label('projector', 0.72),
          _label('document', 0.46),
          _label('text', 0.44),
        ],
      );

      expect(explanation.cellId, isNot('documents_receipts'));
      expect(explanation.cellId, 'devices_tech');
    },
  );

  test('keeps receipt and invoice style paperwork in Documents', () {
    final explanation = service.explainPlacement(
      asset: _imageAsset(
        id: 'receipt_document_1',
        filename: 'receipt_scan.jpg',
      ),
      labels: [
        _label('receipt', 0.9),
        _label('invoice', 0.82),
        _label('document', 0.78),
        _label('text', 0.62),
      ],
    );

    expect(explanation.cellId, 'documents_receipts');
    expect(explanation.usedFallback, isFalse);
  });

  test('does not let weak pet cues overpower stronger nature signals', () {
    final explanation = service.explainPlacement(
      asset: _imageAsset(id: 'pet_false_positive_1'),
      labels: [
        _label('pet', 0.56),
        _label('landscape', 0.88),
        _label('sky', 0.73),
      ],
    );

    expect(explanation.cellId, 'nature');
    expect(explanation.cellId, isNot('pets'));
  });

  test('does not let a weak pet cue hijack a selfie-like photo', () {
    final explanation = service.explainPlacement(
      asset: _imageAsset(id: 'pet_false_positive_2'),
      labels: [
        _label('selfie', 0.87),
        _label('face', 0.76),
        _label('pet', 0.53),
      ],
    );

    expect(explanation.cellId, 'people');
    expect(explanation.cellId, isNot('pets'));
  });

  test('keeps portrait-like human photos out of Unsorted', () {
    final explanation = service.explainPlacement(
      asset: _imageAsset(id: 'people_4'),
      labels: [
        _label('face', 0.61),
        _label('smile', 0.57),
        _label('woman', 0.49),
      ],
    );

    expect(explanation.cellId, 'people');
    expect(explanation.usedFallback, isFalse);
  });

  test('keeps obvious selfie-like human photos out of Pets and Unsorted', () {
    final explanation = service.explainPlacement(
      asset: _imageAsset(id: 'people_pet_1'),
      labels: [
        _label('selfie', 0.79),
        _label('person', 0.72),
        _label('smile', 0.66),
        _label('pet', 0.54),
      ],
    );

    expect(explanation.cellId, 'people');
    expect(explanation.cellId, isNot('pets'));
    expect(explanation.usedFallback, isFalse);
  });

  test('does not let weak sports cues hijack logo and text heavy images', () {
    final explanation = service.explainPlacement(
      asset: _imageAsset(id: 'sports_false_positive_1'),
      labels: [
        _label('jersey', 0.59),
        _label('logo', 0.71),
        _label('text', 0.68),
      ],
    );

    expect(explanation.cellId, isNot('sports'));
    expect(explanation.usedFallback, isTrue);
    expect(
      explanation.fallbackReason,
      UnsortedFallbackReason.lowConfidenceSports,
    );
  });

  test('does not let sports apparel noise beat a human-centered photo', () {
    final explanation = service.explainPlacement(
      asset: _imageAsset(id: 'sports_false_positive_2'),
      labels: [
        _label('person', 0.74),
        _label('selfie', 0.69),
        _label('jersey', 0.58),
      ],
    );

    expect(explanation.cellId, 'people');
    expect(explanation.cellId, isNot('sports'));
  });

  test('keeps strong sports scenes in Sports when real context exists', () {
    final explanation = service.explainPlacement(
      asset: _imageAsset(id: 'sports_1'),
      labels: [
        _label('basketball court', 0.83),
        _label('athlete', 0.72),
        _label('ball', 0.68),
      ],
    );

    expect(explanation.cellId, 'sports');
    expect(explanation.usedFallback, isFalse);
  });

  test('keeps clustered people evidence out of Unsorted', () {
    final explanation = service.explainPlacement(
      asset: _imageAsset(id: 'people_3'),
      labels: [
        _label('woman', 0.63),
        _label('smile', 0.58),
        _label('portrait', 0.55),
      ],
    );

    expect(explanation.cellId, 'people');
    expect(explanation.usedFallback, isFalse);
  });

  test('keeps clustered nature evidence out of Unsorted', () {
    final explanation = service.explainPlacement(
      asset: _imageAsset(id: 'place_2'),
      labels: [
        _label('landscape', 0.58),
        _label('nature', 0.52),
        _label('sky', 0.49),
      ],
    );

    expect(explanation.cellId, 'nature');
    expect(explanation.usedFallback, isFalse);
  });

  test('maps stylized cartoon assets into Animation', () {
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

    expect(explanation.cellId, 'animation');
    expect(explanation.usedFallback, isFalse);
    expect(explanation.primaryEvidence, contains('animation artwork route'));
  });

  test('keeps poster-style stylized graphics out of Pets', () {
    final explanation = service.explainPlacement(
      asset: _imageAsset(id: 'animation_pet_1'),
      labels: [
        _label('poster', 0.9),
        _label('graphic design', 0.84),
        _label('cartoon', 0.81),
        _label('text', 0.78),
        _label('pet', 0.56),
      ],
    );

    expect(explanation.cellId, 'memes');
    expect(explanation.cellId, isNot('pets'));
    expect(explanation.cellId, isNot('documents_receipts'));
    expect(explanation.usedFallback, isFalse);
  });

  test(
    'routes meme and text overlay graphics into Animation instead of Unsorted',
    () {
      final explanation = service.explainPlacement(
        asset: _imageAsset(id: 'animation_2'),
        labels: [
          _label('meme', 0.82),
          _label('cartoon', 0.79),
          _label('text', 0.77),
          _label('font', 0.72),
        ],
      );

      expect(explanation.cellId, 'memes');
      expect(explanation.usedFallback, isFalse);
    },
  );

  test(
    'routes reposted screenshot-like graphics into Animation, not Screenshots',
    () {
      final explanation = service.explainPlacement(
        asset: _imageAsset(
          id: 'animation_screen_like_1',
          filename: 'Screenshot_reshared_card.jpg',
          width: 1179,
          height: 2556,
        ),
        labels: [
          _label('user interface', 0.88),
          _label('text', 0.82),
          _label('graphic design', 0.78),
          _label('meme', 0.74),
          _label('cartoon', 0.70),
        ],
      );

      expect(explanation.cellId, 'memes');
      expect(explanation.cellId, isNot('screenshots'));
      expect(explanation.cellId, isNot('documents_receipts'));
      expect(explanation.usedFallback, isFalse);
    },
  );

  test('routes sports fixture graphics into Sports instead of Places', () {
    final explanation = service.explainPlacement(
      asset: _imageAsset(id: 'sports_graphic_1'),
      labels: [
        _label('scoreboard', 0.88),
        _label('tournament', 0.82),
        _label('text', 0.76),
        _label('city', 0.7),
      ],
    );

    expect(explanation.cellId, 'sports');
    expect(explanation.cellId, isNot('places'));
    expect(explanation.cellId, isNot('documents_receipts'));
    expect(explanation.usedFallback, isFalse);
  });

  test('keeps weak single-animal evidence out of Pets', () {
    final explanation = service.explainPlacement(
      asset: _imageAsset(id: 'pet_gate_1'),
      labels: [_label('dog', 0.74)],
    );

    expect(explanation.cellId, 'unsorted');
    expect(explanation.cellId, isNot('pets'));
    expect(explanation.usedFallback, isTrue);
    expect(
      explanation.fallbackReason,
      UnsortedFallbackReason.lowConfidenceAnimal,
    );
  });

  test('keeps real pet photos in Pets when direct evidence is strong', () {
    final explanation = service.explainPlacement(
      asset: _imageAsset(id: 'pet_real_1'),
      labels: [_label('dog', 0.91), _label('puppy', 0.87), _label('pet', 0.82)],
    );

    expect(explanation.cellId, 'pets');
    expect(explanation.usedFallback, isFalse);
  });

  test('falls back to Unsorted for weak unmapped labels', () {
    final explanation = service.explainPlacement(
      asset: _imageAsset(id: 'unsorted_1'),
      labels: [_label('texture', 0.32), _label('pattern', 0.29)],
    );

    expect(explanation.cellId, 'unsorted');
    expect(explanation.usedFallback, isTrue);
    expect(explanation.fallbackReason, UnsortedFallbackReason.noSignal);
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
