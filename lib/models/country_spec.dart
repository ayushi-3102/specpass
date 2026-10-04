class CountrySpec {
  final String id;
  final String countryCode;
  final String countryName;
  final String documentTitle;
  final String flagEmoji;
  final double widthMm;
  final double heightMm;
  final int targetDpi;
  final double headRatioMin;
  final double headRatioMax;
  final double eyeLevelMin;
  final double eyeLevelMax;
  final String backgroundColorHex;
  final String backgroundName;
  final String formattedDimensions;
  final String standardTag;
  final String notes;

  const CountrySpec({
    required this.id,
    required this.countryCode,
    required this.countryName,
    required this.documentTitle,
    required this.flagEmoji,
    required this.widthMm,
    required this.heightMm,
    this.targetDpi = 300,
    required this.headRatioMin,
    required this.headRatioMax,
    required this.eyeLevelMin,
    required this.eyeLevelMax,
    required this.backgroundColorHex,
    required this.backgroundName,
    required this.formattedDimensions,
    this.standardTag = 'ICAO 9303',
    required this.notes,
  });

  int get widthPixels => ((widthMm / 25.4) * targetDpi).round();
  int get heightPixels => ((heightMm / 25.4) * targetDpi).round();
  double get aspectRatio => widthMm / heightMm;

  // 4x6 inch print sheet calculation (4x6 inches = 101.6 x 152.4 mm)
  // At 300 DPI, 4x6 inches is 1200 x 1800 px (or 1800 x 1200 px landscape)
  int get printSheetRows {
    if (widthMm > 45) return 2; // For 2x2" (51x51mm), 2 rows x 3 cols or 2x2
    return 2; // Standard 2 rows
  }

  int get printSheetCols {
    if (widthMm > 45) return 2; // 4 photos on 4x6"
    return 3; // 6 photos on 4x6" for 35x45mm
  }

  int get photosPerSheet => printSheetRows * printSheetCols;
}
