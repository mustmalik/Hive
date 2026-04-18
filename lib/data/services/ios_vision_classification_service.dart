import 'dart:io';

import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../application/services/classification_service.dart';
import '../../domain/entities/classification_label.dart';
import '../../domain/entities/media_asset.dart';

class IosVisionClassificationService implements ClassificationService {
  IosVisionClassificationService({
    double confidenceThreshold = 0.1,
    int maxLabels = 12,
    MethodChannel? methodChannel,
    Future<File?> Function(String assetId)? assetFileResolver,
    DateTime Function()? now,
  }) : _confidenceThreshold = confidenceThreshold,
       _maxLabels = maxLabels,
       _methodChannel =
           methodChannel ??
           const MethodChannel('dev.hive/classification/image_labeling'),
       _assetFileResolver = assetFileResolver,
       _now = now ?? DateTime.now;

  static const String _modelIdentifier = 'apple_vision/VNClassifyImageRequest';

  final double _confidenceThreshold;
  final int _maxLabels;
  final MethodChannel _methodChannel;
  final Future<File?> Function(String assetId)? _assetFileResolver;
  final DateTime Function() _now;

  @override
  Future<List<ClassificationLabel>> classifyAsset(MediaAsset asset) async {
    if (!_supportsClassification(asset)) {
      return const [];
    }

    final imagePath = await _resolveImagePath(asset.id);
    if (imagePath == null) {
      return const [];
    }

    final labels = await _methodChannel
        .invokeListMethod<Object?>('classifyImage', <String, Object>{
          'path': imagePath,
          'confidenceThreshold': _confidenceThreshold,
          'maxLabels': _maxLabels,
        });

    if (labels == null || labels.isEmpty) {
      return const [];
    }

    final createdAt = _now();
    final mappedByKey = <String, ClassificationLabel>{};

    for (final label in labels) {
      final mappedLabel = _mapLabel(label, createdAt: createdAt);
      if (mappedLabel == null) {
        continue;
      }

      final existing = mappedByKey[mappedLabel.key];
      if (existing == null || mappedLabel.confidence > existing.confidence) {
        mappedByKey[mappedLabel.key] = mappedLabel;
      }
    }

    final sortedLabels = mappedByKey.values.toList(growable: false)
      ..sort((left, right) => right.confidence.compareTo(left.confidence));

    return sortedLabels;
  }

  @override
  Future<Map<String, List<ClassificationLabel>>> classifyAssets(
    List<MediaAsset> assets,
  ) async {
    final results = <String, List<ClassificationLabel>>{};

    for (final asset in assets) {
      results[asset.id] = await classifyAsset(asset);
    }

    return results;
  }

  Future<String?> _resolveImagePath(String assetId) async {
    if (_assetFileResolver != null) {
      final file = await _assetFileResolver(assetId);
      return file?.path;
    }

    final entity = await AssetEntity.fromId(assetId);
    if (entity == null) {
      return null;
    }

    final File? file = await entity.file;
    return file?.path;
  }

  ClassificationLabel? _mapLabel(
    Object? labelData, {
    required DateTime createdAt,
  }) {
    if (labelData is! Map<Object?, Object?>) {
      return null;
    }

    final displayName = labelData['label'] as String?;
    final confidence = (labelData['confidence'] as num?)?.toDouble();
    if (displayName == null || confidence == null) {
      return null;
    }

    final slug = _slugify(displayName);

    return ClassificationLabel(
      id: '${_modelIdentifier}_$slug',
      key: '$_modelIdentifier:$slug',
      displayName: displayName,
      confidence: confidence,
      source: ClassificationLabelSource.onDeviceModel,
      createdAt: createdAt,
      modelIdentifier:
          labelData['modelIdentifier'] as String? ?? _modelIdentifier,
    );
  }

  bool _supportsClassification(MediaAsset asset) {
    return asset.type == MediaAssetType.image ||
        asset.type == MediaAssetType.livePhoto ||
        asset.type == MediaAssetType.screenshot;
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
}
