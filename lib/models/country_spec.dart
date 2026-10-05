enum DocumentPurpose {
  all,
  passport,
  visa,
  drivingLicense,
  studentCard,
  residencePermit,
  customId;

  String get label {
    switch (this) {
      case DocumentPurpose.all:
        return 'All Presets';
      case DocumentPurpose.passport:
        return 'Passport';
      case DocumentPurpose.visa:
        return 'Visa';
      case DocumentPurpose.drivingLicense:
        return 'Driving License';
      case DocumentPurpose.studentCard:
        return 'Student ID';
      case DocumentPurpose.residencePermit:
        return 'Green Card / PR';
      case DocumentPurpose.customId:
        return 'Custom';
    }
  }

  String get iconEmoji {
    switch (this) {
      case DocumentPurpose.all:
        return '🌐';
      case DocumentPurpose.passport:
        return '🛂';
      case DocumentPurpose.visa:
        return '✈️';
      case DocumentPurpose.drivingLicense:
        return '🪪';
      case DocumentPurpose.studentCard:
        return '🎓';
      case DocumentPurpose.residencePermit:
        return '🏛️';
      case DocumentPurpose.customId:
        return '📐';
    }
  }
}

class CountrySpec {
  final String id;
  final String countryCode;
  final String countryName;
  final String documentTitle;
  final String flagEmoji;
  final DocumentPurpose purpose;
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
    this.purpose = DocumentPurpose.passport,
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

  // Target biometric head ratio (midpoint of consular requirement)
  double get targetHeadRatio => (headRatioMin + headRatioMax) / 2.0;

  // 4x6 inch print sheet calculation (4x6 inches = 101.6 x 152.4 mm)
  int get printSheetRows {
    if (widthMm > 45 || heightMm > 50) return 2; // For 2x2" (51x51mm), 50x70mm, 40x60mm
    return 3; // Standard 3 rows for 35x45mm, 33x48mm (2 cols x 3 rows = 6 photos)
  }

  int get printSheetCols {
    if (widthMm > 45) return 2; // 4 photos on 4x6"
    return 2; // 2 columns for 35x45mm
  }

  int get photosPerSheet => printSheetRows * printSheetCols;
}
