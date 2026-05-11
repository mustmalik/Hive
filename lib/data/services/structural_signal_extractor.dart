import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../application/models/structural_signals.dart';
import '../../domain/entities/media_asset.dart';

typedef StructuralImageLoader =
    Future<StructuralSourceImage?> Function(MediaAsset asset);
typedef StructuralFaceExtractor =
    Future<StructuralFaceObservation> Function(StructuralSourceImage source);
typedef StructuralTextExtractor =
    Future<StructuralTextObservation> Function(StructuralSourceImage source);
typedef StructuralBarcodeExtractor =
    Future<StructuralBarcodeObservation> Function(StructuralSourceImage source);

class StructuralSourceImage {
  StructuralSourceImage({
    required this.filePath,
    required this.imageWidth,
    required this.imageHeight,
    this.thumbnailBytes,
    this.onDispose,
  });

  final String? filePath;
  final int imageWidth;
  final int imageHeight;
  final Uint8List? thumbnailBytes;
  final Future<void> Function()? onDispose;

  Future<bool> isUsable() async {
    final path = filePath;
    if (path == null || path.isEmpty) {
      return false;
    }

    final file = File(path);
    if (!await file.exists()) {
      return false;
    }

    return await file.length() > 0;
  }

  Future<int> fileSizeBytes() async {
    final path = filePath;
    if (path == null || path.isEmpty) {
      return 0;
    }

    final file = File(path);
    if (!await file.exists()) {
      return 0;
    }

    return file.length();
  }

  Future<InputImage?> createInputImage() async {
    if (!await isUsable()) {
      return null;
    }

    return InputImage.fromFilePath(filePath!);
  }

  Future<void> dispose() async {
    if (onDispose != null) {
      await onDispose!();
    }
  }
}

class StructuralFaceObservation {
  const StructuralFaceObservation({
    required this.faceCount,
    required this.largestFaceAreaRatio,
  });

  final int faceCount;
  final double largestFaceAreaRatio;

  static const empty = StructuralFaceObservation(
    faceCount: 0,
    largestFaceAreaRatio: 0,
  );
}

class StructuralTextObservation {
  const StructuralTextObservation({
    required this.lineTexts,
    required this.blockCount,
    required this.textCoverageRatio,
  });

  final List<String> lineTexts;
  final int blockCount;
  final double textCoverageRatio;

  int get lineCount => lineTexts.length;

  String get fullText => lineTexts.join('\n');

  static const empty = StructuralTextObservation(
    lineTexts: <String>[],
    blockCount: 0,
    textCoverageRatio: 0,
  );
}

class StructuralBarcodeObservation {
  const StructuralBarcodeObservation({
    required this.barcodeCount,
    required this.hasQrCode,
  });

  final int barcodeCount;
  final bool hasQrCode;

  static const empty = StructuralBarcodeObservation(
    barcodeCount: 0,
    hasQrCode: false,
  );
}

class StructuralSignalExtractor {
  StructuralSignalExtractor({
    Future<Directory> Function()? temporaryDirectoryProvider,
    StructuralImageLoader? imageLoader,
    StructuralFaceExtractor? faceExtractor,
    StructuralTextExtractor? textExtractor,
    StructuralBarcodeExtractor? barcodeExtractor,
  }) : _imageLoader =
           imageLoader ??
           ((asset) => _loadSourceImage(
             asset,
             temporaryDirectoryProvider ?? getTemporaryDirectory,
           )),
       _faceExtractor = faceExtractor ?? _runFaceDetection,
       _textExtractor = textExtractor ?? _runTextRecognition,
       _barcodeExtractor = barcodeExtractor ?? _runBarcodeScanning;

  final StructuralImageLoader _imageLoader;
  final StructuralFaceExtractor _faceExtractor;
  final StructuralTextExtractor _textExtractor;
  final StructuralBarcodeExtractor _barcodeExtractor;

  static FaceDetector? _sharedFaceDetector;
  static TextRecognizer? _sharedTextRecognizer;
  static BarcodeScanner? _sharedBarcodeScanner;

  Future<StructuralSignals> extract(MediaAsset asset) async {
    StructuralSourceImage? source;

    try {
      source = await _imageLoader(asset);
      if (source == null || !await source.isUsable()) {
        _logFailure(
          'Unable to resolve safe structural preview image.',
          asset.id,
        );
        return StructuralSignals.empty();
      }

      final preparedPath = source.filePath;
      final preparedSize = await source.fileSizeBytes();
      if (kDebugMode && preparedPath != null) {
        debugPrint(
          'StructuralSignalExtractor[${asset.id}]: prepared safe preview input '
          '$preparedPath ($preparedSize bytes)',
        );
      }

      final futures = await Future.wait<Object>([
        _extractFaces(source, asset.id),
        _extractText(source, asset.id),
        _extractBarcodes(source, asset.id),
      ]);

      final faceObservation = futures[0] as StructuralFaceObservation;
      final textObservation = futures[1] as StructuralTextObservation;
      final barcodeObservation = futures[2] as StructuralBarcodeObservation;

      final fullOcrText = textObservation.fullText.toLowerCase();
      final hasMrzPattern = _hasMrzPattern(textObservation.lineTexts);
      final hasTableLikeLayout = _hasTableLikeLayout(
        lineTexts: textObservation.lineTexts,
        blockCount: textObservation.blockCount,
      );
      final hasChatLikeLayout = _hasChatLikeLayout(
        lineTexts: textObservation.lineTexts,
        hasTableLikeLayout: hasTableLikeLayout,
      );
      final largestFaceAreaRatio = _clamp01(
        faceObservation.largestFaceAreaRatio,
      );
      final textCoverageRatio = _clamp01(textObservation.textCoverageRatio);
      final hasSingleLargeFace =
          faceObservation.faceCount == 1 && largestFaceAreaRatio >= 0.08;

      // Emergency stabilization: disable experimental thumbnail style detectors.
      // Keep defaults false so core placement remains label/ocr/face driven.
      const nonPhotoCharacterStyle = false;
      const physicalBookVisualMedium = false;

      if (faceObservation.faceCount == 0 &&
          largestFaceAreaRatio == 0 &&
          textCoverageRatio == 0 &&
          fullOcrText.isEmpty &&
          textObservation.lineCount == 0 &&
          textObservation.blockCount == 0 &&
          !hasChatLikeLayout &&
          !hasTableLikeLayout &&
          barcodeObservation.barcodeCount == 0 &&
          !barcodeObservation.hasQrCode &&
          !hasMrzPattern) {
        return StructuralSignals.empty();
      }

      return StructuralSignals(
        faceCount: faceObservation.faceCount,
        largestFaceAreaRatio: largestFaceAreaRatio,
        hasSingleLargeFace: hasSingleLargeFace,
        textCoverageRatio: textCoverageRatio,
        fullOcrText: fullOcrText,
        lineCount: textObservation.lineCount,
        blockCount: textObservation.blockCount,
        hasChatLikeLayout: hasChatLikeLayout,
        hasTableLikeLayout: hasTableLikeLayout,
        barcodeCount: barcodeObservation.barcodeCount,
        hasQrCode: barcodeObservation.hasQrCode,
        hasMrzPattern: hasMrzPattern,
        nonPhotoCharacterStyle: nonPhotoCharacterStyle,
        physicalBookVisualMedium: physicalBookVisualMedium,
      );
    } catch (error, stackTrace) {
      _logFailure(
        'Structural signal extraction failed unexpectedly.',
        asset.id,
        error: error,
        stackTrace: stackTrace,
      );
      return StructuralSignals.empty();
    } finally {
      await source?.dispose();
    }
  }

  Future<StructuralFaceObservation> _extractFaces(
    StructuralSourceImage source,
    String assetId,
  ) async {
    try {
      return await _faceExtractor(source);
    } catch (error, stackTrace) {
      _logFailure(
        'Face detection failed.',
        assetId,
        error: error,
        stackTrace: stackTrace,
      );
      return StructuralFaceObservation.empty;
    }
  }

  Future<StructuralTextObservation> _extractText(
    StructuralSourceImage source,
    String assetId,
  ) async {
    try {
      return await _textExtractor(source);
    } catch (error, stackTrace) {
      _logFailure(
        'Text recognition failed.',
        assetId,
        error: error,
        stackTrace: stackTrace,
      );
      return StructuralTextObservation.empty;
    }
  }

  Future<StructuralBarcodeObservation> _extractBarcodes(
    StructuralSourceImage source,
    String assetId,
  ) async {
    try {
      return await _barcodeExtractor(source);
    } catch (error, stackTrace) {
      _logFailure(
        'Barcode scanning failed.',
        assetId,
        error: error,
        stackTrace: stackTrace,
      );
      return StructuralBarcodeObservation.empty;
    }
  }

  static Future<StructuralSourceImage?> _loadSourceImage(
    MediaAsset asset,
    Future<Directory> Function() temporaryDirectoryProvider,
  ) async {
    final entity = await AssetEntity.fromId(asset.id);
    if (entity == null) {
      return null;
    }

    final thumbnailBytes = await entity.thumbnailDataWithSize(
      const ThumbnailSize(1024, 1024),
      quality: 92,
    );
    if (thumbnailBytes == null || thumbnailBytes.isEmpty) {
      _logFailure('Unable to resolve safe structural preview image.', asset.id);
      return null;
    }

    return _writeTemporaryInput(
      asset: asset,
      bytes: thumbnailBytes,
      temporaryDirectoryProvider: temporaryDirectoryProvider,
      width: _resolvedDimension(asset.width, fallback: 1024),
      height: _resolvedDimension(asset.height, fallback: 1024),
      preferredExtension: 'jpg',
    );
  }

  static Future<StructuralSourceImage?> _writeTemporaryInput({
    required MediaAsset asset,
    required Uint8List bytes,
    required Future<Directory> Function() temporaryDirectoryProvider,
    required int width,
    required int height,
    required String preferredExtension,
  }) async {
    if (bytes.isEmpty) {
      return null;
    }

    final directory = await temporaryDirectoryProvider();
    final extension = preferredExtension.startsWith('.')
        ? preferredExtension
        : '.${preferredExtension.toLowerCase()}';
    final file = File(
      '${directory.path}/'
      'hive_structural_${_slugify(asset.id)}_'
      '${DateTime.now().microsecondsSinceEpoch}$extension',
    );

    try {
      await file.writeAsBytes(bytes, flush: true);
      if (!await file.exists() || await file.length() <= 0) {
        await _deleteFileBestEffort(file);
        return null;
      }
    } catch (_) {
      await _deleteFileBestEffort(file);
      return null;
    }

    return StructuralSourceImage(
      filePath: file.path,
      imageWidth: width,
      imageHeight: height,
      thumbnailBytes: bytes,
      onDispose: () async {
        if (await file.exists()) {
          await file.delete();
        }
      },
    );
  }


  static Future<void> _deleteFileBestEffort(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      return;
    }
  }

  static Future<StructuralFaceObservation> _runFaceDetection(
    StructuralSourceImage source,
  ) async {
    final inputImage = await source.createInputImage();
    if (inputImage == null) {
      return StructuralFaceObservation.empty;
    }

    final faces = await _faceDetector.processImage(inputImage);
    final imageArea = math.max(
      1.0,
      source.imageWidth.toDouble() * source.imageHeight.toDouble(),
    );
    var largestFaceAreaRatio = 0.0;

    for (final face in faces) {
      final areaRatio = _clamp01(
        (face.boundingBox.width * face.boundingBox.height) / imageArea,
      );
      if (areaRatio > largestFaceAreaRatio) {
        largestFaceAreaRatio = areaRatio;
      }
    }

    return StructuralFaceObservation(
      faceCount: faces.length,
      largestFaceAreaRatio: largestFaceAreaRatio,
    );
  }

  static Future<StructuralTextObservation> _runTextRecognition(
    StructuralSourceImage source,
  ) async {
    final inputImage = await source.createInputImage();
    if (inputImage == null) {
      return StructuralTextObservation.empty;
    }

    final recognizedText = await _textRecognizer.processImage(inputImage);
    final imageArea = math.max(
      1.0,
      source.imageWidth.toDouble() * source.imageHeight.toDouble(),
    );
    final lineTexts = <String>[];
    var totalTextAreaRatio = 0.0;

    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        lineTexts.add(line.text);
        totalTextAreaRatio += _clamp01(
          (line.boundingBox.width * line.boundingBox.height) / imageArea,
        );
      }
    }

    if (lineTexts.isEmpty && recognizedText.text.trim().isNotEmpty) {
      lineTexts.addAll(
        recognizedText.text
            .split('\n')
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty),
      );
    }

    return StructuralTextObservation(
      lineTexts: List<String>.unmodifiable(lineTexts),
      blockCount: recognizedText.blocks.length,
      textCoverageRatio: _clamp01(totalTextAreaRatio),
    );
  }

  static Future<StructuralBarcodeObservation> _runBarcodeScanning(
    StructuralSourceImage source,
  ) async {
    final inputImage = await source.createInputImage();
    if (inputImage == null) {
      return StructuralBarcodeObservation.empty;
    }

    final barcodes = await _barcodeScanner.processImage(inputImage);
    return StructuralBarcodeObservation(
      barcodeCount: barcodes.length,
      hasQrCode: barcodes.any(
        (barcode) => barcode.format == BarcodeFormat.qrCode,
      ),
    );
  }

  static FaceDetector get _faceDetector {
    return _sharedFaceDetector ??= FaceDetector(
      options: FaceDetectorOptions(performanceMode: FaceDetectorMode.fast),
    );
  }

  static TextRecognizer get _textRecognizer {
    return _sharedTextRecognizer ??=
        TextRecognizer(script: TextRecognitionScript.latin);
  }

  static BarcodeScanner get _barcodeScanner {
    return _sharedBarcodeScanner ??=
        BarcodeScanner(formats: const [BarcodeFormat.all]);
  }

  static Future<void> disposeSharedDetectors() async {
    final faceDetector = _sharedFaceDetector;
    final textRecognizer = _sharedTextRecognizer;
    final barcodeScanner = _sharedBarcodeScanner;
    _sharedFaceDetector = null;
    _sharedTextRecognizer = null;
    _sharedBarcodeScanner = null;

    if (faceDetector != null) {
      try {
        await faceDetector.close();
      } catch (_) {}
    }
    if (textRecognizer != null) {
      try {
        await textRecognizer.close();
      } catch (_) {}
    }
    if (barcodeScanner != null) {
      try {
        await barcodeScanner.close();
      } catch (_) {}
    }
  }

  static bool _hasChatLikeLayout({
    required List<String> lineTexts,
    required bool hasTableLikeLayout,
  }) {
    if (hasTableLikeLayout || lineTexts.length < 6) {
      return false;
    }

    final timePattern = RegExp(r'\b\d{1,2}:\d{2}\b');
    final hasTimePattern = lineTexts.any(
      (line) => timePattern.hasMatch(line.toLowerCase()),
    );
    if (!hasTimePattern) {
      return false;
    }

    final averageLineLength = _averageLineLength(lineTexts);
    final shortLineCount = lineTexts
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && line.length < 40)
        .length;

    return averageLineLength < 40 && shortLineCount >= 4;
  }

  static bool _hasTableLikeLayout({
    required List<String> lineTexts,
    required int blockCount,
  }) {
    if (lineTexts.isEmpty) {
      return false;
    }

    final rawText = lineTexts.join('\n');
    if (RegExp(r'\t| {2,}').hasMatch(rawText)) {
      return true;
    }

    final numericCurrencyLines = lineTexts.where((line) {
      final trimmed = line.trim();
      return RegExp(r'\d').hasMatch(trimmed) &&
          RegExp(r'[$€£¥%]').hasMatch(trimmed);
    }).length;
    if (numericCurrencyLines >= 3) {
      return true;
    }

    return lineTexts.length >= 8 &&
        blockCount >= 3 &&
        _averageLineLength(lineTexts) < 25;
  }

  static bool _hasMrzPattern(List<String> lineTexts) {
    final mrzPattern = RegExp(r'[A-Z0-9<]{44,}');
    for (final line in lineTexts) {
      final normalized = line.toUpperCase().replaceAll(' ', '');
      if (mrzPattern.hasMatch(normalized)) {
        return true;
      }
    }
    return false;
  }

  static double _averageLineLength(List<String> lineTexts) {
    final nonEmptyLines = lineTexts
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    if (nonEmptyLines.isEmpty) {
      return 0;
    }

    final totalLength = nonEmptyLines.fold<int>(
      0,
      (total, line) => total + line.length,
    );
    return totalLength / nonEmptyLines.length;
  }

  static int _resolvedDimension(int dimension, {required int fallback}) {
    return dimension > 0 ? dimension : fallback;
  }

  static String _slugify(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  static double _clamp01(double value) {
    if (value <= 0) {
      return 0;
    }
    if (value >= 1) {
      return 1;
    }
    return value;
  }

  static void _logFailure(
    String message,
    String assetId, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!kDebugMode) {
      return;
    }

    debugPrint('StructuralSignalExtractor[$assetId]: $message');
    if (error != null) {
      debugPrint('StructuralSignalExtractor[$assetId] error: $error');
    }
    if (stackTrace != null) {
      debugPrint(stackTrace.toString());
    }
  }
}
