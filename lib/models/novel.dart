class Novel {
  final String title;
  /// e.g. assets/books/crime_and_punishment.epub
  final String assetFilePath;
  /// e.g. assets/covers/crime_and_punishment.jpg
  final String coverAssetPath;
  /// URL for downloading PDF (for Arabic novels)
  final String? downloadUrl;

  const Novel({
    required this.title,
    required this.assetFilePath,
    required this.coverAssetPath,
    this.downloadUrl,
  });
}















