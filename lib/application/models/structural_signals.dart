class StructuralSignals {
  const StructuralSignals({
    required this.faceCount,
    required this.largestFaceAreaRatio,
    required this.hasSingleLargeFace,
    required this.textCoverageRatio,
    required this.fullOcrText,
    required this.lineCount,
    required this.blockCount,
    required this.hasChatLikeLayout,
    required this.hasTableLikeLayout,
    required this.barcodeCount,
    required this.hasQrCode,
    required this.hasMrzPattern,
    this.nonPhotoCharacterStyle = false,
    this.physicalBookVisualMedium = false,
    this.screenDeviceCueCount = 0,
  });

  final int faceCount;
  final double largestFaceAreaRatio;
  final bool hasSingleLargeFace;
  final double textCoverageRatio;
  final String fullOcrText;
  final int lineCount;
  final int blockCount;
  final bool hasChatLikeLayout;
  final bool hasTableLikeLayout;
  final int barcodeCount;
  final bool hasQrCode;
  final bool hasMrzPattern;
  /// Lightweight thumbnail-derived "cartoon/character medium" (non-photo) hint.
  final bool nonPhotoCharacterStyle;
  /// Lightweight thumbnail-derived "photographed printed cover/object" hint.
  final bool physicalBookVisualMedium;
  /// Count of "screen/device" cues derived from classification labels (not OCR).
  /// This is injected by the placement analysis builder so structural logic can
  /// distinguish photos of devices from true meme quote cards.
  final int screenDeviceCueCount;

  factory StructuralSignals.empty() {
    return const StructuralSignals(
      faceCount: 0,
      largestFaceAreaRatio: 0,
      hasSingleLargeFace: false,
      textCoverageRatio: 0,
      fullOcrText: '',
      lineCount: 0,
      blockCount: 0,
      hasChatLikeLayout: false,
      hasTableLikeLayout: false,
      barcodeCount: 0,
      hasQrCode: false,
      hasMrzPattern: false,
    );
  }

  StructuralSignals withScreenDeviceCueCount(int count) {
    if (count == screenDeviceCueCount) {
      return this;
    }
    return StructuralSignals(
      faceCount: faceCount,
      largestFaceAreaRatio: largestFaceAreaRatio,
      hasSingleLargeFace: hasSingleLargeFace,
      textCoverageRatio: textCoverageRatio,
      fullOcrText: fullOcrText,
      lineCount: lineCount,
      blockCount: blockCount,
      hasChatLikeLayout: hasChatLikeLayout,
      hasTableLikeLayout: hasTableLikeLayout,
      barcodeCount: barcodeCount,
      hasQrCode: hasQrCode,
      hasMrzPattern: hasMrzPattern,
      nonPhotoCharacterStyle: nonPhotoCharacterStyle,
      physicalBookVisualMedium: physicalBookVisualMedium,
      screenDeviceCueCount: count,
    );
  }

  bool hasAnyToken(List<String> tokens) {
    final normalizedText = fullOcrText.toLowerCase();
    for (final token in tokens) {
      final normalizedToken = token.toLowerCase();
      if (normalizedToken.trim().isEmpty) {
        continue;
      }
      if (normalizedToken.length <= 2) {
        final pattern = RegExp('\\b${RegExp.escape(normalizedToken)}\\b');
        if (pattern.hasMatch(normalizedText)) {
          return true;
        }
        continue;
      }
      if (normalizedText.contains(normalizedToken)) {
        return true;
      }
    }
    return false;
  }

  double get uiDensityScore {
    final chatUiScore = isChatLike ? 0.9 : 0.0;
    final tableUiScore = hasTableLikeLayout ? 0.6 : 0.0;
    final textUiScore = (textCoverageRatio * 1.5).clamp(0.0, 0.8);
    final value = [chatUiScore, tableUiScore, textUiScore].reduce(
      (left, right) => left > right ? left : right,
    );
    return value.clamp(0.0, 1.0);
  }

  bool get isDocumentLike {
    return textCoverageRatio >= 0.15 ||
        hasTableLikeLayout ||
        barcodeCount >= 1 ||
        hasMrzPattern;
  }

  bool get isChatLike {
    return hasChatLikeLayout && textCoverageRatio >= 0.05;
  }

  bool get _hasTwitterOrSocialOcrPattern {
    return hasAnyToken(const [
      'rt',
      'retweet',
      'like',
      'reply',
      'share',
      'follow',
      'following',
      'followers',
      'tweet',
      'posted',
      'instagram',
      'tiktok',
      'facebook',
      'linkedin',
      'comment',
      'comments',
      'likes',
      'views',
      'watch',
    ]);
  }

  bool get isTextOverlayOnPhoto {
    return faceCount >= 1 &&
        textCoverageRatio >= 0.15 &&
        !hasMrzPattern &&
        !hasChatLikeLayout &&
        !hasTableLikeLayout;
  }

  bool get isTextHeavyGraphic {
    return textCoverageRatio >= 0.18 &&
        lineCount >= 3 &&
        faceCount == 0 &&
        !hasMrzPattern &&
        !hasTableLikeLayout;
  }

  bool get isTweetOrSocialCapture {
    return textCoverageRatio >= 0.10 &&
        lineCount >= 4 &&
        hasChatLikeLayout == false &&
        _hasTwitterOrSocialOcrPattern;
  }

  bool get isDevicePhotoContext {
    return screenDeviceCueCount >= 1 && largestFaceAreaRatio < 0.08;
  }

  bool get isPhotoQuoteCardMeme {
    return textCoverageRatio >= 0.12 &&
        lineCount >= 2 &&
        !hasMrzPattern &&
        !hasTableLikeLayout &&
        !hasChatLikeLayout &&
        !isDevicePhotoContext &&
        (hasAnyToken(const [
              'said',
              'quote',
              'before',
              'after',
              'on',
              'about',
              'vs',
              'versus',
              'when',
              'if',
              'we',
              'i',
              'he',
              'she',
              'they',
              'you',
              'my',
              'the',
              'a',
              'to',
              'is',
              'are',
              'was',
              'were',
              'will',
              'can',
              'could',
              'would',
              'should',
            ]) ||
            textCoverageRatio >= 0.20);
  }

  bool get hasEmojiOverlay {
    if (fullOcrText.isEmpty) {
      return false;
    }
    return fullOcrText.contains(
      RegExp(
        r'[\u{1F600}-\u{1F64F}'
        r'\u{1F300}-\u{1F5FF}'
        r'\u{1F680}-\u{1F6FF}'
        r'\u{2600}-\u{26FF}'
        r'\u{2700}-\u{27BF}]',
        unicode: true,
      ),
    );
  }

  bool get isMemeOrPosterLike {
    return isTextOverlayOnPhoto ||
        isTextHeavyGraphic ||
        isTweetOrSocialCapture ||
        isPhotoQuoteCardMeme ||
        hasEmojiOverlay;
  }
}
