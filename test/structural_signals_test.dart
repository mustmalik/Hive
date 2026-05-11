import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter_v1/application/models/structural_signals.dart';

void main() {
  test('isDocumentLike returns true when hasMrzPattern is true', () {
    const signals = StructuralSignals(
      faceCount: 0,
      largestFaceAreaRatio: 0,
      hasSingleLargeFace: false,
      textCoverageRatio: 0.02,
      fullOcrText: 'p<utoeriksson<<anna<maria<<<<<<<<<<<<<<<<<<<',
      lineCount: 2,
      blockCount: 1,
      hasChatLikeLayout: false,
      hasTableLikeLayout: false,
      barcodeCount: 0,
      hasQrCode: false,
      hasMrzPattern: true,
    );

    expect(signals.isDocumentLike, isTrue);
  });

  test('isDocumentLike returns true when barcodeCount is at least one', () {
    const signals = StructuralSignals(
      faceCount: 0,
      largestFaceAreaRatio: 0,
      hasSingleLargeFace: false,
      textCoverageRatio: 0.04,
      fullOcrText: 'receipt total 42.00',
      lineCount: 2,
      blockCount: 1,
      hasChatLikeLayout: false,
      hasTableLikeLayout: false,
      barcodeCount: 1,
      hasQrCode: false,
      hasMrzPattern: false,
    );

    expect(signals.isDocumentLike, isTrue);
  });

  test(
    'isChatLike returns true when hasChatLikeLayout is true and textCoverageRatio is high enough',
    () {
      const signals = StructuralSignals(
        faceCount: 1,
        largestFaceAreaRatio: 0.03,
        hasSingleLargeFace: false,
        textCoverageRatio: 0.05,
        fullOcrText: 'hey there 09:41 ok 09:42',
        lineCount: 4,
        blockCount: 3,
        hasChatLikeLayout: true,
        hasTableLikeLayout: false,
        barcodeCount: 0,
        hasQrCode: false,
        hasMrzPattern: false,
      );

      expect(signals.isChatLike, isTrue);
    },
  );

  test(
    'isMemeOrPosterLike returns true when text coverage line count and face count match',
    () {
      const signals = StructuralSignals(
        faceCount: 0,
        largestFaceAreaRatio: 0,
        hasSingleLargeFace: false,
        textCoverageRatio: 0.20,
        fullOcrText: 'top text bottom text caption line',
        lineCount: 3,
        blockCount: 2,
        hasChatLikeLayout: false,
        hasTableLikeLayout: false,
        barcodeCount: 0,
        hasQrCode: false,
        hasMrzPattern: false,
      );

      expect(signals.isMemeOrPosterLike, isTrue);
    },
  );

  test('hasAnyToken finds a match case-insensitively', () {
    const signals = StructuralSignals(
      faceCount: 0,
      largestFaceAreaRatio: 0,
      hasSingleLargeFace: false,
      textCoverageRatio: 0.18,
      fullOcrText: 'passport and visa office',
      lineCount: 2,
      blockCount: 1,
      hasChatLikeLayout: false,
      hasTableLikeLayout: true,
      barcodeCount: 0,
      hasQrCode: false,
      hasMrzPattern: false,
    );

    expect(signals.hasAnyToken(['Identity', 'VISA']), isTrue);
  });

  test('StructuralSignals.empty returns all zero and false values', () {
    final signals = StructuralSignals.empty();

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
}
