import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter_v1/data/services/structural_signal_extractor.dart';
import 'package:hive_flutter_v1/domain/entities/media_asset.dart';

void main() {
  test('when face detection returns 2 faces faceCount is 2', () async {
    final extractor = StructuralSignalExtractor(
      imageLoader: _fakeImageLoader,
      faceExtractor: (_) async => const StructuralFaceObservation(
        faceCount: 2,
        largestFaceAreaRatio: 0.12,
      ),
      textExtractor: (_) async => StructuralTextObservation.empty,
      barcodeExtractor: (_) async => StructuralBarcodeObservation.empty,
    );

    final signals = await extractor.extract(_asset('face_count_2'));

    expect(signals.faceCount, 2);
  });

  test(
    'when face detection throws faceCount is 0 and no exception propagates',
    () async {
      final extractor = StructuralSignalExtractor(
        imageLoader: _fakeImageLoader,
        faceExtractor: (_) async => throw StateError('face failed'),
        textExtractor: (_) async => StructuralTextObservation.empty,
        barcodeExtractor: (_) async => StructuralBarcodeObservation.empty,
      );

      final signals = await extractor.extract(_asset('face_throw'));

      expect(signals.faceCount, 0);
      expect(signals.largestFaceAreaRatio, 0);
    },
  );

  test(
    'when OCR returns dense text textCoverageRatio is greater than zero',
    () async {
      final extractor = StructuralSignalExtractor(
        imageLoader: _fakeImageLoader,
        faceExtractor: (_) async => StructuralFaceObservation.empty,
        textExtractor: (_) async => const StructuralTextObservation(
          lineTexts: ['invoice', 'subtotal 12.00', 'tax 2.00', 'total 14.00'],
          blockCount: 2,
          textCoverageRatio: 0.32,
        ),
        barcodeExtractor: (_) async => StructuralBarcodeObservation.empty,
      );

      final signals = await extractor.extract(_asset('dense_text'));

      expect(signals.textCoverageRatio, greaterThan(0));
    },
  );

  test(
    'when OCR text contains a time pattern and short lines hasChatLikeLayout is true',
    () async {
      final extractor = StructuralSignalExtractor(
        imageLoader: _fakeImageLoader,
        faceExtractor: (_) async => StructuralFaceObservation.empty,
        textExtractor: (_) async => const StructuralTextObservation(
          lineTexts: [
            'hey',
            '09:41',
            'where are you',
            '09:42',
            'on my way',
            '09:43',
          ],
          blockCount: 2,
          textCoverageRatio: 0.12,
        ),
        barcodeExtractor: (_) async => StructuralBarcodeObservation.empty,
      );

      final signals = await extractor.extract(_asset('chat_layout'));

      expect(signals.hasChatLikeLayout, isTrue);
    },
  );

  test(
    'when OCR text contains a 44 character mrz sequence hasMrzPattern is true',
    () async {
      final extractor = StructuralSignalExtractor(
        imageLoader: _fakeImageLoader,
        faceExtractor: (_) async => StructuralFaceObservation.empty,
        textExtractor: (_) async => const StructuralTextObservation(
          lineTexts: [
            'P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<<<<<<<<<',
            'L898902C36UTO7408122F1204159ZE184226B<<<<<10',
          ],
          blockCount: 1,
          textCoverageRatio: 0.18,
        ),
        barcodeExtractor: (_) async => StructuralBarcodeObservation.empty,
      );

      final signals = await extractor.extract(_asset('mrz_text'));

      expect(signals.hasMrzPattern, isTrue);
    },
  );

  test('when all APIs fail returns StructuralSignals.empty', () async {
    final extractor = StructuralSignalExtractor(
      imageLoader: _fakeImageLoader,
      faceExtractor: (_) async => throw StateError('face failed'),
      textExtractor: (_) async => throw StateError('text failed'),
      barcodeExtractor: (_) async => throw StateError('barcode failed'),
    );

    final signals = await extractor.extract(_asset('all_fail'));

    expect(signals.faceCount, 0);
    expect(signals.largestFaceAreaRatio, 0);
    expect(signals.hasSingleLargeFace, isFalse);
    expect(signals.textCoverageRatio, 0);
    expect(signals.fullOcrText, isEmpty);
    expect(signals.lineCount, 0);
    expect(signals.blockCount, 0);
    expect(signals.hasChatLikeLayout, isFalse);
    expect(signals.hasTableLikeLayout, isFalse);
    expect(signals.barcodeCount, 0);
    expect(signals.hasQrCode, isFalse);
    expect(signals.hasMrzPattern, isFalse);
  });

  test(
    'when prepared preview file is missing extractor returns StructuralSignals.empty',
    () async {
      final extractor = StructuralSignalExtractor(
        imageLoader: (_) async => StructuralSourceImage(
          filePath: '/tmp/hive_missing_structural_preview.jpg',
          imageWidth: 1000,
          imageHeight: 1000,
        ),
        faceExtractor: (_) async => throw StateError('should not run'),
        textExtractor: (_) async => throw StateError('should not run'),
        barcodeExtractor: (_) async => throw StateError('should not run'),
      );

      final signals = await extractor.extract(_asset('missing_preview'));

      expect(signals.faceCount, 0);
      expect(signals.textCoverageRatio, 0);
      expect(signals.hasMrzPattern, isFalse);
    },
  );

  test(
    'when prepared preview file has zero bytes extractor returns StructuralSignals.empty',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'hive_structural_zero_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });
      final zeroFile = File('${tempDir.path}/empty.jpg');
      await zeroFile.writeAsBytes(const []);

      final extractor = StructuralSignalExtractor(
        imageLoader: (_) async => StructuralSourceImage(
          filePath: zeroFile.path,
          imageWidth: 1000,
          imageHeight: 1000,
        ),
        faceExtractor: (_) async => throw StateError('should not run'),
        textExtractor: (_) async => throw StateError('should not run'),
        barcodeExtractor: (_) async => throw StateError('should not run'),
      );

      final signals = await extractor.extract(_asset('zero_preview'));

      expect(signals.faceCount, 0);
      expect(signals.textCoverageRatio, 0);
      expect(signals.barcodeCount, 0);
    },
  );

  test(
    'when image preparation returns null no ML Kit processor is called',
    () async {
      var faceCalled = false;
      var textCalled = false;
      var barcodeCalled = false;

      final extractor = StructuralSignalExtractor(
        imageLoader: (_) async => null,
        faceExtractor: (_) async {
          faceCalled = true;
          return StructuralFaceObservation.empty;
        },
        textExtractor: (_) async {
          textCalled = true;
          return StructuralTextObservation.empty;
        },
        barcodeExtractor: (_) async {
          barcodeCalled = true;
          return StructuralBarcodeObservation.empty;
        },
      );

      final signals = await extractor.extract(_asset('null_preparation'));

      expect(signals.faceCount, 0);
      expect(faceCalled, isFalse);
      expect(textCalled, isFalse);
      expect(barcodeCalled, isFalse);
    },
  );
}

Future<StructuralSourceImage?> _fakeImageLoader(MediaAsset asset) async {
  final tempDir = await Directory.systemTemp.createTemp(
    'hive_structural_test_',
  );
  final file = File('${tempDir.path}/${asset.id}.jpg');
  await file.writeAsBytes(const [1, 2, 3]);

  return StructuralSourceImage(
    filePath: file.path,
    imageWidth: 1000,
    imageHeight: 1000,
    onDispose: () async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    },
  );
}

MediaAsset _asset(String id) {
  return MediaAsset(
    id: id,
    type: MediaAssetType.image,
    createdAt: DateTime(2026, 4, 27, 12),
    modifiedAt: DateTime(2026, 4, 27, 12),
    width: 1000,
    height: 1000,
  );
}
