import 'package:flutter/foundation.dart';

import '../../application/models/classification_backend.dart';
import '../../application/services/classification_service.dart';
import 'google_mlkit_classification_service.dart';
import 'ios_vision_classification_service.dart';

class ClassificationServiceFactory {
  const ClassificationServiceFactory._();

  static const _classificationBackendEnvKey = 'HIVE_CLASSIFICATION_BACKEND';

  static ClassificationService create({
    ClassificationBackend? backend,
  }) {
    final resolvedBackend =
        backend ??
        ClassificationBackend.parse(
          const String.fromEnvironment(_classificationBackendEnvKey),
        );

    if (kDebugMode) {
      debugPrint(
        '[HIVE-ENGINE] Using '
        '${resolvedBackend == ClassificationBackend.googleMlKit ? "MLKit" : "AppleVision"} '
        'for labeling',
      );
    }

    return switch (resolvedBackend) {
      ClassificationBackend.appleVision => IosVisionClassificationService(),
      ClassificationBackend.googleMlKit => GoogleMlKitClassificationService(),
    };
  }

  static String engineNameForService(ClassificationService service) {
    return service is GoogleMlKitClassificationService
        ? 'MLKit'
        : 'AppleVision';
  }
}
