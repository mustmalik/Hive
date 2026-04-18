import 'dart:io';

import 'package:flutter/services.dart';

import '../../application/models/classification_outcome.dart';
import '../../application/services/classification_service.dart';
import '../../domain/entities/classification_label.dart';
import '../../domain/entities/media_asset.dart';

class IosVisionClassificationService extends ClassificationService {
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

    try {
      final fallbackPath = await _resolveFallbackPath(asset.id);
      final response = await _methodChannel
          .invokeMapMethod<Object?, Object?>('classifyAsset', <String, Object?>{
            'assetId': asset.id,
            'fallbackPath': fallbackPath,
            'confidenceThreshold': _confidenceThreshold,
            'maxLabels': _maxLabels,
          });

      if (response == null) {
        return ClassificationOutcome(
          assetId: asset.id,
          status: ClassificationOutcomeStatus.requestFailed,
          labels: const [],
          failureReason:
              'No response was returned by the on-device classifier.',
          failureStage: 'vision_execution',
          failureCode: 'empty_classifier_response',
          classificationRan: false,
          imagePreparationSucceeded: false,
          noLabelsReturned: false,
        );
      }

      return _mapOutcome(assetId: asset.id, data: response);
    } on MissingPluginException {
      return ClassificationOutcome(
        assetId: asset.id,
        status: ClassificationOutcomeStatus.requestFailed,
        labels: const [],
        failureReason:
            'The native classification bridge is not available in this build.',
        failureStage: 'vision_request_creation',
        failureCode: 'missing_classification_bridge',
        classificationRan: false,
        imagePreparationSucceeded: false,
        noLabelsReturned: false,
      );
    } on PlatformException catch (error) {
      return ClassificationOutcome(
        assetId: asset.id,
        status: ClassificationOutcomeStatus.requestFailed,
        labels: const [],
        failureReason: error.message ?? error.code,
        failureStage: 'vision_execution',
        failureCode: error.code,
        classificationRan: false,
        imagePreparationSucceeded: false,
        noLabelsReturned: false,
      );
    } catch (_) {
      return ClassificationOutcome(
        assetId: asset.id,
        status: ClassificationOutcomeStatus.requestFailed,
        labels: const [],
        failureReason: 'The on-device classifier could not finish this asset.',
        failureStage: 'vision_execution',
        failureCode: 'unexpected_classifier_error',
        classificationRan: false,
        imagePreparationSucceeded: false,
        noLabelsReturned: false,
      );
    }
  }

  Future<String?> _resolveFallbackPath(String assetId) async {
    if (_assetFileResolver == null) {
      return null;
    }

    final file = await _assetFileResolver(assetId);
    return file?.path;
  }

  ClassificationOutcome _mapOutcome({
    required String assetId,
    required Map<Object?, Object?> data,
  }) {
    final createdAt = _now();
    final labels = _mapLabels(
      data['labels'] as List<Object?>? ?? const <Object?>[],
      createdAt: createdAt,
    );
    final rawStatus = _readString(data['status']);
    final status = _parseStatus(rawStatus, labels: labels);
    final modelIdentifier =
        _readString(data['modelIdentifier']) ??
        (labels.isEmpty ? null : labels.first.modelIdentifier) ??
        _modelIdentifier;

    return ClassificationOutcome(
      assetId: assetId,
      status: status,
      labels: labels,
      failureReason: _readString(data['failureReason']),
      failureStage: _readString(data['failureStage']),
      failureCode: _readString(data['failureCode']),
      modelIdentifier: modelIdentifier,
      sourceFormat: _readString(data['sourceFormat']),
      preparedFormat: _readString(data['preparedFormat']),
      classificationRan:
          data['classificationRan'] as bool? ?? labels.isNotEmpty,
      imagePreparationSucceeded:
          data['imagePreparationSucceeded'] as bool? ?? labels.isNotEmpty,
      noLabelsReturned:
          data['noLabelsReturned'] as bool? ??
          (status == ClassificationOutcomeStatus.noLabelsReturned),
    );
  }

  List<ClassificationLabel> _mapLabels(
    List<Object?> values, {
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

  ClassificationOutcomeStatus _parseStatus(
    String? raw, {
    required List<ClassificationLabel> labels,
  }) {
    if (raw == null || raw.isEmpty) {
      return labels.isEmpty
          ? ClassificationOutcomeStatus.noLabelsReturned
          : ClassificationOutcomeStatus.succeeded;
    }

    try {
      return ClassificationOutcomeStatus.values.byName(raw);
    } catch (_) {
      return labels.isEmpty
          ? ClassificationOutcomeStatus.requestFailed
          : ClassificationOutcomeStatus.succeeded;
    }
  }

  bool _supportsClassification(MediaAsset asset) {
    return asset.type == MediaAssetType.image ||
        asset.type == MediaAssetType.livePhoto ||
        asset.type == MediaAssetType.screenshot;
  }

  String? _readString(Object? value) {
    return value is String ? value : null;
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
