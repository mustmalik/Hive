import '../../application/models/classification_outcome.dart';
import '../../domain/entities/classification_label.dart';
import '../../domain/entities/folder_cell.dart';
import '../../domain/entities/media_asset.dart';
import '../../domain/entities/scan_run.dart';
import '../services/local_scan_result_store.dart';

StoredScanSnapshot copyStoredScanSnapshot(
  StoredScanSnapshot snapshot, {
  List<Map<String, dynamic>>? cells,
  List<Map<String, dynamic>>? assets,
  List<Map<String, dynamic>>? classifications,
  List<Map<String, dynamic>>? runs,
}) {
  return StoredScanSnapshot(
    cells: cells ?? snapshot.cells,
    assets: assets ?? snapshot.assets,
    classifications: classifications ?? snapshot.classifications,
    runs: runs ?? snapshot.runs,
  );
}

Map<String, dynamic> folderCellToJson(FolderCell cell) {
  return {
    'id': cell.id,
    'name': cell.name,
    'origin': cell.origin.name,
    'createdAt': cell.createdAt.toIso8601String(),
    'updatedAt': cell.updatedAt.toIso8601String(),
    'description': cell.description,
    'coverAssetId': cell.coverAssetId,
    'labelIds': cell.labelIds,
    'assetIds': cell.assetIds,
    'isPinned': cell.isPinned,
  };
}

FolderCell folderCellFromJson(Map<String, dynamic> json) {
  return FolderCell(
    id: json['id'] as String? ?? 'unknown',
    name: json['name'] as String? ?? 'Cell',
    origin: FolderCellOrigin.values.byName(
      json['origin'] as String? ?? FolderCellOrigin.suggested.name,
    ),
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    updatedAt:
        DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    description: json['description'] as String?,
    coverAssetId: json['coverAssetId'] as String?,
    labelIds: (json['labelIds'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<String>()
        .toList(growable: false),
    assetIds: (json['assetIds'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<String>()
        .toList(growable: false),
    isPinned: json['isPinned'] as bool? ?? false,
  );
}

Map<String, dynamic> mediaAssetToJson(MediaAsset asset) {
  return {
    'id': asset.id,
    'type': asset.type.name,
    'createdAt': asset.createdAt.toIso8601String(),
    'modifiedAt': asset.modifiedAt.toIso8601String(),
    'width': asset.width,
    'height': asset.height,
    'durationMs': asset.duration.inMilliseconds,
    'originalFilename': asset.originalFilename,
    'isFavorite': asset.isFavorite,
    'isHidden': asset.isHidden,
  };
}

MediaAsset mediaAssetFromJson(Map<String, dynamic> json) {
  return MediaAsset(
    id: json['id'] as String? ?? 'unknown',
    type: MediaAssetType.values.byName(
      json['type'] as String? ?? MediaAssetType.other.name,
    ),
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    modifiedAt:
        DateTime.tryParse(json['modifiedAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    width: json['width'] as int? ?? 0,
    height: json['height'] as int? ?? 0,
    duration: Duration(milliseconds: json['durationMs'] as int? ?? 0),
    originalFilename: json['originalFilename'] as String?,
    isFavorite: json['isFavorite'] as bool? ?? false,
    isHidden: json['isHidden'] as bool? ?? false,
  );
}

Map<String, dynamic> scanRunToJson(ScanRun run) {
  return {
    'id': run.id,
    'status': run.status.name,
    'startedAt': run.startedAt.toIso8601String(),
    'completedAt': run.completedAt?.toIso8601String(),
    'discoveredAssetCount': run.discoveredAssetCount,
    'classifiedAssetCount': run.classifiedAssetCount,
    'generatedCellCount': run.generatedCellCount,
    'errorMessage': run.errorMessage,
    'currentStageLabel': run.currentStageLabel,
    'currentItemTitle': run.currentItemTitle,
    'latestDetectedCellName': run.latestDetectedCellName,
  };
}

ScanRun scanRunFromJson(Map<String, dynamic> json) {
  return ScanRun(
    id: json['id'] as String? ?? 'unknown',
    status: ScanRunStatus.values.byName(
      json['status'] as String? ?? ScanRunStatus.completed.name,
    ),
    startedAt:
        DateTime.tryParse(json['startedAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    completedAt: DateTime.tryParse(json['completedAt'] as String? ?? ''),
    discoveredAssetCount: json['discoveredAssetCount'] as int? ?? 0,
    classifiedAssetCount: json['classifiedAssetCount'] as int? ?? 0,
    generatedCellCount: json['generatedCellCount'] as int? ?? 0,
    errorMessage: json['errorMessage'] as String?,
    currentStageLabel: json['currentStageLabel'] as String?,
    currentItemTitle: json['currentItemTitle'] as String?,
    latestDetectedCellName: json['latestDetectedCellName'] as String?,
  );
}

Map<String, dynamic> classificationEntryToJson(
  String assetId,
  List<ClassificationLabel> labels,
) {
  return classificationOutcomeToJson(
    ClassificationOutcome(
      assetId: assetId,
      status: labels.isEmpty
          ? ClassificationOutcomeStatus.noLabelsReturned
          : ClassificationOutcomeStatus.succeeded,
      labels: labels,
      classificationRan: true,
      imagePreparationSucceeded: true,
      noLabelsReturned: labels.isEmpty,
      modelIdentifier: labels.isEmpty ? null : labels.first.modelIdentifier,
    ),
  );
}

Map<String, dynamic> classificationOutcomeToJson(
  ClassificationOutcome outcome,
) {
  return {
    'assetId': outcome.assetId,
    'status': outcome.status.name,
    'labels': outcome.labels
        .map(classificationLabelToJson)
        .toList(growable: false),
    'failureReason': outcome.failureReason,
    'failureStage': outcome.failureStage,
    'failureCode': outcome.failureCode,
    'modelIdentifier': outcome.modelIdentifier,
    'sourceFormat': outcome.sourceFormat,
    'preparedFormat': outcome.preparedFormat,
    'classificationRan': outcome.classificationRan,
    'imagePreparationSucceeded': outcome.imagePreparationSucceeded,
    'noLabelsReturned': outcome.noLabelsReturned,
  };
}

({String assetId, List<ClassificationLabel> labels})
classificationEntryFromJson(Map<String, dynamic> json) {
  final outcome = classificationOutcomeFromJson(json);
  return (assetId: outcome.assetId, labels: outcome.labels);
}

ClassificationOutcome classificationOutcomeFromJson(Map<String, dynamic> json) {
  final labels = (json['labels'] as List<dynamic>? ?? const <dynamic>[])
      .whereType<Map>()
      .map(
        (entry) => classificationLabelFromJson(entry.cast<String, dynamic>()),
      )
      .toList(growable: false);

  return ClassificationOutcome(
    assetId: json['assetId'] as String? ?? '',
    status: _classificationOutcomeStatusFromJson(
      json['status'] as String?,
      labels: labels,
    ),
    labels: labels,
    failureReason: json['failureReason'] as String?,
    failureStage: json['failureStage'] as String?,
    failureCode: json['failureCode'] as String?,
    modelIdentifier: json['modelIdentifier'] as String?,
    sourceFormat: json['sourceFormat'] as String?,
    preparedFormat: json['preparedFormat'] as String?,
    classificationRan:
        json['classificationRan'] as bool? ??
        labels.isNotEmpty ||
            (json['status'] as String?) ==
                ClassificationOutcomeStatus.noLabelsReturned.name,
    imagePreparationSucceeded:
        json['imagePreparationSucceeded'] as bool? ??
        labels.isNotEmpty ||
            (json['status'] as String?) ==
                ClassificationOutcomeStatus.noLabelsReturned.name,
    noLabelsReturned:
        json['noLabelsReturned'] as bool? ??
        ((json['status'] as String?) ==
                ClassificationOutcomeStatus.noLabelsReturned.name &&
            labels.isEmpty),
  );
}

ClassificationOutcomeStatus _classificationOutcomeStatusFromJson(
  String? raw, {
  required List<ClassificationLabel> labels,
}) {
  if (raw == null || raw.isEmpty) {
    return labels.isEmpty
        ? ClassificationOutcomeStatus.noLabelsReturned
        : ClassificationOutcomeStatus.succeeded;
  }

  return ClassificationOutcomeStatus.values.byName(raw);
}

Map<String, dynamic> classificationLabelToJson(ClassificationLabel label) {
  return {
    'id': label.id,
    'key': label.key,
    'displayName': label.displayName,
    'confidence': label.confidence,
    'source': label.source.name,
    'createdAt': label.createdAt.toIso8601String(),
    'modelIdentifier': label.modelIdentifier,
  };
}

ClassificationLabel classificationLabelFromJson(Map<String, dynamic> json) {
  return ClassificationLabel(
    id: json['id'] as String? ?? 'unknown',
    key: json['key'] as String? ?? 'unknown',
    displayName: json['displayName'] as String? ?? 'Unknown',
    confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
    source: ClassificationLabelSource.values.byName(
      json['source'] as String? ?? ClassificationLabelSource.onDeviceModel.name,
    ),
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    modelIdentifier: json['modelIdentifier'] as String?,
  );
}
