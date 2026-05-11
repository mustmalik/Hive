import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:hive_flutter_v1/application/models/classification_outcome.dart';
import 'package:hive_flutter_v1/data/services/google_mlkit_classification_service.dart';
import 'package:hive_flutter_v1/domain/entities/media_asset.dart';

void main() {
  test('Google ML Kit service maps labels into HIVE outcomes', () async {
    InputImage? capturedInput;
    final service = GoogleMlKitClassificationService(
      assetFileResolver: (_) async => File('/tmp/hive_mlkit_test_asset.jpg'),
      imageProcessor: (inputImage) async {
        capturedInput = inputImage;
        return const [
          GoogleMlKitLabelResult(label: 'Dog', confidence: 0.91, index: 17),
          GoogleMlKitLabelResult(label: 'Pet', confidence: 0.63, index: 51),
        ];
      },
      now: () => DateTime(2026, 4, 25, 12),
    );

    final outcome = await service.classifyAssetDetailed(_imageAsset());

    expect(capturedInput, isNotNull);
    expect(capturedInput!.filePath, '/tmp/hive_mlkit_test_asset.jpg');
    expect(outcome.status, ClassificationOutcomeStatus.succeeded);
    expect(outcome.classificationRan, isTrue);
    expect(outcome.imagePreparationSucceeded, isTrue);
    expect(outcome.modelIdentifier, 'google_mlkit/image_labeling/base_model');
    expect(outcome.sourceFormat, 'asset_file_resolver');
    expect(outcome.preparedFormat, 'input_image/file_path');
    expect(outcome.labels, hasLength(2));
    expect(outcome.labels.first.displayName, 'Dog');
    expect(outcome.labels.first.confidence, 0.91);
    expect(
      outcome.labels.first.key,
      'google_mlkit/image_labeling/base_model:17:dog',
    );
  });

  test('Google ML Kit service reports no-label outcomes cleanly', () async {
    final service = GoogleMlKitClassificationService(
      assetFileResolver: (_) async => File('/tmp/hive_mlkit_test_asset.jpg'),
      imageProcessor: (_) async => const [],
    );

    final outcome = await service.classifyAssetDetailed(_imageAsset());

    expect(outcome.status, ClassificationOutcomeStatus.noLabelsReturned);
    expect(outcome.labels, isEmpty);
    expect(outcome.classificationRan, isTrue);
    expect(outcome.noLabelsReturned, isTrue);
    expect(
      outcome.failureReason,
      'Google ML Kit returned no labels above the current threshold.',
    );
  });

  test(
    'Google ML Kit service fails safely when no input image is available',
    () async {
      final service = GoogleMlKitClassificationService(
        assetFileResolver: (_) async => null,
        imageProcessor: (_) async => throw StateError('should not run'),
      );

      final outcome = await service.classifyAssetDetailed(_imageAsset());

      expect(
        outcome.status,
        ClassificationOutcomeStatus.imagePreparationFailed,
      );
      expect(outcome.classificationRan, isFalse);
      expect(outcome.imagePreparationSucceeded, isFalse);
      expect(outcome.failureCode, 'unable_to_resolve_input_image');
    },
  );
}

MediaAsset _imageAsset() {
  return MediaAsset(
    id: 'asset_1',
    type: MediaAssetType.image,
    createdAt: DateTime(2026, 4, 18),
    modifiedAt: DateTime(2026, 4, 18),
    width: 3024,
    height: 4032,
    originalFilename: 'IMG_0001.HEIC',
  );
}
