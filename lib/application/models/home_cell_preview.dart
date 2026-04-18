class HomeCellPreview {
  const HomeCellPreview({
    required this.id,
    required this.name,
    required this.assetCount,
    required this.summary,
    required this.styleKey,
    this.featured = false,
  });

  final String id;
  final String name;
  final int assetCount;
  final String summary;
  final String styleKey;
  final bool featured;
}
