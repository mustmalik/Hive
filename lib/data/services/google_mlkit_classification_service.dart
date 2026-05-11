import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../application/models/classification_outcome.dart';
import '../../application/services/classification_service.dart';
import '../../domain/entities/classification_label.dart';
import '../../domain/entities/media_asset.dart';

typedef GoogleMlKitImageProcessor =
    Future<List<GoogleMlKitLabelResult>> Function(InputImage inputImage);

class GoogleMlKitLabelResult {
  const GoogleMlKitLabelResult({
    required this.label,
    required this.confidence,
    required this.index,
  });

  final String label;
  final double confidence;
  final int index;
}

class GoogleMlKitClassificationService extends ClassificationService {
  GoogleMlKitClassificationService({
    double confidenceThreshold = 0.1,
    int maxLabels = 12,
    Future<File?> Function(String assetId)? assetFileResolver,
    GoogleMlKitImageProcessor? imageProcessor,
    Future<Directory> Function()? temporaryDirectoryProvider,
    DateTime Function()? now,
  }) : _maxLabels = maxLabels,
       _assetFileResolver = assetFileResolver,
       _imageProcessor =
           imageProcessor ??
           ((inputImage) => _processWithMlKit(
             inputImage,
             confidenceThreshold: confidenceThreshold,
           )),
       _temporaryDirectoryProvider =
           temporaryDirectoryProvider ?? getTemporaryDirectory,
       _now = now ?? DateTime.now;

  static const String _modelIdentifier =
      'google_mlkit/image_labeling/base_model';
  static final Map<String, ImageLabeler> _sharedImageLabelersByThreshold = {};

  final int _maxLabels;
  final Future<File?> Function(String assetId)? _assetFileResolver;
  final GoogleMlKitImageProcessor _imageProcessor;
  final Future<Directory> Function() _temporaryDirectoryProvider;
  final DateTime Function() _now;

  static Future<void> disposeSharedResources() async {
    final labelers = _sharedImageLabelersByThreshold.values.toList(
      growable: false,
    );
    _sharedImageLabelersByThreshold.clear();

    for (final labeler in labelers) {
      try {
        await labeler.close();
      } catch (_) {
        if (kDebugMode) {
          debugPrint(
            'GoogleMlKitClassificationService: unable to close shared labeler.',
          );
        }
      }
    }
  }

  @override
  Future<ClassificationOutcome> classifyAssetDetailed(MediaAsset asset) async {
    if (!_supportsClassification(asset)) {
      return ClassificationOutcome(
        assetId: asset.id,
        status: ClassificationOutcomeStatus.unsupportedAsset,
        labels: const [],
        failureReason:
            'This asset type is not currently classifiable on device.',
        failureStage: 'load_image_data',
        failureCode: 'unsupported_asset_type',
        classificationRan: false,
        imagePreparationSucceeded: false,
        noLabelsReturned: false,
      );
    }

    _PreparedGoogleMlKitInput? preparedInput;

    try {
      preparedInput = await _prepareInput(asset);
      if (preparedInput == null) {
        return ClassificationOutcome(
          assetId: asset.id,
          status: ClassificationOutcomeStatus.imagePreparationFailed,
          labels: const [],
          failureReason:
              'Google ML Kit could not load a usable local image for this asset.',
          failureStage: 'load_image_data',
          failureCode: 'unable_to_resolve_input_image',
          modelIdentifier: _modelIdentifier,
          classificationRan: false,
          imagePreparationSucceeded: false,
          noLabelsReturned: false,
        );
      }

      final mlKitLabels = await _imageProcessor(preparedInput.inputImage);
      final labels = _mapLabels(
        mlKitLabels,
        createdAt: _now(),
      ).take(_maxLabels).toList(growable: false);

      if (labels.isEmpty) {
        return ClassificationOutcome(
          assetId: asset.id,
          status: ClassificationOutcomeStatus.noLabelsReturned,
          labels: const [],
          failureReason:
              'Google ML Kit returned no labels above the current threshold.',
          failureStage: null,
          failureCode: null,
          modelIdentifier: _modelIdentifier,
          sourceFormat: preparedInput.sourceFormat,
          preparedFormat: preparedInput.preparedFormat,
          classificationRan: true,
          imagePreparationSucceeded: true,
          noLabelsReturned: true,
        );
      }

      return ClassificationOutcome(
        assetId: asset.id,
        status: ClassificationOutcomeStatus.succeeded,
        labels: labels,
        modelIdentifier: _modelIdentifier,
        sourceFormat: preparedInput.sourceFormat,
        preparedFormat: preparedInput.preparedFormat,
        classificationRan: true,
        imagePreparationSucceeded: true,
        noLabelsReturned: false,
      );
    } on MissingPluginException {
      return ClassificationOutcome(
        assetId: asset.id,
        status: ClassificationOutcomeStatus.requestFailed,
        labels: const [],
        failureReason:
            'The Google ML Kit image labeling plugin is not available in this build.',
        failureStage: 'mlkit_execution',
        failureCode: 'missing_google_mlkit_plugin',
        modelIdentifier: _modelIdentifier,
        sourceFormat: preparedInput?.sourceFormat,
        preparedFormat: preparedInput?.preparedFormat,
        classificationRan: false,
        imagePreparationSucceeded: preparedInput != null,
        noLabelsReturned: false,
      );
    } on PlatformException catch (error) {
      return ClassificationOutcome(
        assetId: asset.id,
        status: ClassificationOutcomeStatus.requestFailed,
        labels: const [],
        failureReason: error.message ?? error.code,
        failureStage: 'mlkit_execution',
        failureCode: error.code,
        modelIdentifier: _modelIdentifier,
        sourceFormat: preparedInput?.sourceFormat,
        preparedFormat: preparedInput?.preparedFormat,
        classificationRan: false,
        imagePreparationSucceeded: preparedInput != null,
        noLabelsReturned: false,
      );
    } catch (_) {
      return ClassificationOutcome(
        assetId: asset.id,
        status: ClassificationOutcomeStatus.requestFailed,
        labels: const [],
        failureReason: 'Google ML Kit could not finish this asset.',
        failureStage: 'mlkit_execution',
        failureCode: 'unexpected_google_mlkit_error',
        modelIdentifier: _modelIdentifier,
        sourceFormat: preparedInput?.sourceFormat,
        preparedFormat: preparedInput?.preparedFormat,
        classificationRan: false,
        imagePreparationSucceeded: preparedInput != null,
        noLabelsReturned: false,
      );
    } finally {
      await preparedInput?.dispose();
    }
  }

  Future<_PreparedGoogleMlKitInput?> _prepareInput(MediaAsset asset) async {
    if (_assetFileResolver != null) {
      final resolvedByResolver = await _resolveInjectedFile(asset.id);
      if (resolvedByResolver == null) {
        return null;
      }

      return _PreparedGoogleMlKitInput.file(
        file: resolvedByResolver,
        sourceFormat: 'asset_file_resolver',
        preparedFormat: 'input_image/file_path',
      );
    }

    final entity = await AssetEntity.fromId(asset.id);
    if (entity == null) {
      return null;
    }

    final originalFile = await entity.originFile;
    if (originalFile != null) {
      return _PreparedGoogleMlKitInput.file(
        file: originalFile,
        sourceFormat: 'photo_manager/original_file',
        preparedFormat: 'input_image/file_path',
      );
    }

    final previewFile = await entity.file;
    if (previewFile != null) {
      return _PreparedGoogleMlKitInput.file(
        file: previewFile,
        sourceFormat: 'photo_manager/preview_file',
        preparedFormat: 'input_image/file_path',
      );
    }

    final originalBytes = await entity.originBytes;
    if (originalBytes != null) {
      return _writeTemporaryInput(
        asset: asset,
        bytes: originalBytes,
        sourceFormat: 'photo_manager/original_bytes',
        preferredExtension: _preferredExtension(asset.originalFilename),
      );
    }

    final previewWidth = (asset.width > 0 ? asset.width : 1800)
        .clamp(1200, 2200)
        .toInt();
    final previewHeight = (asset.height > 0 ? asset.height : 1800)
        .clamp(1200, 2200)
        .toInt();
    final previewBytes = await entity.thumbnailDataWithSize(
      ThumbnailSize(previewWidth, previewHeight),
      quality: 92,
    );

    if (previewBytes == null) {
      return null;
    }

    return _writeTemporaryInput(
      asset: asset,
      bytes: previewBytes,
      sourceFormat: 'photo_manager/preview_bytes',
      preferredExtension: 'jpg',
    );
  }

  Future<File?> _resolveInjectedFile(String assetId) async {
    if (_assetFileResolver == null) {
      return null;
    }

    return _assetFileResolver(assetId);
  }

  Future<_PreparedGoogleMlKitInput> _writeTemporaryInput({
    required MediaAsset asset,
    required Uint8List bytes,
    required String sourceFormat,
    required String preferredExtension,
  }) async {
    final directory = await _temporaryDirectoryProvider();
    final extension = preferredExtension.startsWith('.')
        ? preferredExtension
        : '.${preferredExtension.toLowerCase()}';
    final filename =
        'hive_mlkit_${_slugify(asset.id)}_'
        '${_now().microsecondsSinceEpoch}$extension';
    final file = File('${directory.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);

    return _PreparedGoogleMlKitInput.temporaryFile(
      file: file,
      sourceFormat: sourceFormat,
      preparedFormat: 'input_image/temp_file$extension',
    );
  }

  List<ClassificationLabel> _mapLabels(
    List<GoogleMlKitLabelResult> values, {
    required DateTime createdAt,
  }) {
    final mappedByKey = <String, ClassificationLabel>{};

    for (final value in values) {
      final mappedLabel = _mapLabel(value, createdAt: createdAt);
      if (mappedLabel == null) {
        continue;
      }

      final existing = mappedByKey[mappedLabel.key];
      if (existing == null || mappedLabel.confidence > existing.confidence) {
        mappedByKey[mappedLabel.key] = mappedLabel;
      }
    }

    final sorted = mappedByKey.values.toList(growable: false)
      ..sort((left, right) => right.confidence.compareTo(left.confidence));
    return sorted;
  }

  ClassificationLabel? _mapLabel(
    GoogleMlKitLabelResult label, {
    required DateTime createdAt,
  }) {
    final displayName = label.label.trim();
    if (displayName.isEmpty) {
      return null;
    }

    final slug = _slugify(displayName);
    final labelIndex = label.index >= 0 ? label.index : 0;

    return ClassificationLabel(
      id: '${_modelIdentifier}_${labelIndex}_$slug',
      key: '$_modelIdentifier:$labelIndex:$slug',
      displayName: displayName,
      confidence: label.confidence,
      source: ClassificationLabelSource.onDeviceModel,
      createdAt: createdAt,
      modelIdentifier: _modelIdentifier,
    );
  }

  bool _supportsClassification(MediaAsset asset) {
    return asset.type == MediaAssetType.image ||
        asset.type == MediaAssetType.livePhoto ||
        asset.type == MediaAssetType.screenshot;
  }

  String _preferredExtension(String? filename) {
    if (filename == null) {
      return 'jpg';
    }

    final extensionIndex = filename.lastIndexOf('.');
    if (extensionIndex < 0 || extensionIndex == filename.length - 1) {
      return 'jpg';
    }

    final extension = filename.substring(extensionIndex + 1).toLowerCase();
    return switch (extension) {
      'jpg' || 'jpeg' || 'png' || 'heic' || 'heif' || 'webp' => extension,
      _ => 'jpg',
    };
  }

  String _slugify(String value) {
    final buffer = StringBuffer();
    var lastWasSeparator = false;

    for (final codeUnit in value.toLowerCase().codeUnits) {
      final isAlphaNumeric =
          (codeUnit >= 97 && codeUnit <= 122) ||
          (codeUnit >= 48 && codeUnit <= 57);
      if (isAlphaNumeric) {
        buffer.writeCharCode(codeUnit);
        lastWasSeparator = false;
      } else if (buffer.isNotEmpty && !lastWasSeparator) {
        buffer.write('_');
        lastWasSeparator = true;
      }
    }

    final slug = buffer.toString().replaceAll(RegExp(r'_+$'), '');
    return slug.isEmpty ? 'unknown' : slug;
  }

  static Future<List<GoogleMlKitLabelResult>> _processWithMlKit(
    InputImage inputImage, {
    required double confidenceThreshold,
  }) async {
    final imageLabeler = _sharedImageLabelersByThreshold.putIfAbsent(
      confidenceThreshold.toStringAsFixed(4),
      () => ImageLabeler(
        options: ImageLabelerOptions(confidenceThreshold: confidenceThreshold),
      ),
    );

    final labels = await imageLabeler.processImage(inputImage);
    return labels
        .map(
          (label) => GoogleMlKitLabelResult(
            label: label.label,
            confidence: label.confidence,
            index: label.index,
          ),
        )
        .toList(growable: false);
  }
}

class _PreparedGoogleMlKitInput {
  _PreparedGoogleMlKitInput._({
    required this.file,
    required this.sourceFormat,
    required this.preparedFormat,
    required this.deleteOnDispose,
  });

  factory _PreparedGoogleMlKitInput.file({
    required File file,
    required String sourceFormat,
    required String preparedFormat,
  }) {
    return _PreparedGoogleMlKitInput._(
      file: file,
      sourceFormat: sourceFormat,
      preparedFormat: preparedFormat,
      deleteOnDispose: false,
    );
  }

  factory _PreparedGoogleMlKitInput.temporaryFile({
    required File file,
    required String sourceFormat,
    required String preparedFormat,
  }) {
    return _PreparedGoogleMlKitInput._(
      file: file,
      sourceFormat: sourceFormat,
      preparedFormat: preparedFormat,
      deleteOnDispose: true,
    );
  }

  final File file;
  final String sourceFormat;
  final String preparedFormat;
  final bool deleteOnDispose;

  InputImage get inputImage => InputImage.fromFilePath(file.path);

  Future<void> dispose() async {
    if (!deleteOnDispose) {
      return;
    }

    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Best-effort cleanup for temporary input files.
    }
  }
}
