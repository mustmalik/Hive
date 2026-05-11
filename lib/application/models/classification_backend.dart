enum ClassificationBackend {
  appleVision,
  googleMlKit;

  static const ClassificationBackend fallback =
      ClassificationBackend.appleVision;

  static ClassificationBackend parse(String? value) {
    final normalized = value?.trim().toLowerCase();

    return switch (normalized) {
      'applevision' ||
      'apple_vision' ||
      'apple-vision' ||
      'applevisionbackend' => appleVision,
      'googlemlkit' ||
      'google_mlkit' ||
      'google-mlkit' ||
      'mlkit' ||
      'google_ml_kit' => googleMlKit,
      _ => fallback,
    };
  }
}
