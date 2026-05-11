import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter_v1/application/models/classification_backend.dart';
import 'package:hive_flutter_v1/data/services/classification_service_factory.dart';
import 'package:hive_flutter_v1/data/services/google_mlkit_classification_service.dart';
import 'package:hive_flutter_v1/data/services/ios_vision_classification_service.dart';

void main() {
  test('ClassificationBackend.parse defaults safely to Apple Vision', () {
    expect(
      ClassificationBackend.parse(null),
      ClassificationBackend.appleVision,
    );
    expect(
      ClassificationBackend.parse('unknown-backend'),
      ClassificationBackend.appleVision,
    );
  });

  test('ClassificationBackend.parse recognizes Google ML Kit aliases', () {
    expect(
      ClassificationBackend.parse('googleMlKit'),
      ClassificationBackend.googleMlKit,
    );
    expect(
      ClassificationBackend.parse('google_ml_kit'),
      ClassificationBackend.googleMlKit,
    );
  });

  test('ClassificationServiceFactory defaults to Apple Vision', () {
    final service = ClassificationServiceFactory.create();

    expect(service, isA<IosVisionClassificationService>());
  });

  test('ClassificationServiceFactory can create Google ML Kit service', () {
    final service = ClassificationServiceFactory.create(
      backend: ClassificationBackend.googleMlKit,
    );

    expect(service, isA<GoogleMlKitClassificationService>());
  });
}
