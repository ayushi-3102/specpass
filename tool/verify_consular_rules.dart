import 'package:flutter_test/flutter_test.dart';
import 'package:specpass/data/country_specs_data.dart';

void main() {
  test('Verify Consular Dimensions and Head Cut Rules for all Country Presets', () {
    final specs = CountrySpecsData.allSpecs;
    expect(specs.isNotEmpty, true);

    print('\n========================================================================');
    print('VERIFYING CONSULAR RULES & DIMENSIONS FOR ${specs.length} OFFICIAL PRESETS');
    print('========================================================================\n');

    for (final spec in specs) {
      // 1. Check DPI
      expect(spec.targetDpi, 300, reason: '${spec.id} must be 300 DPI');

      // 2. Check Pixels at 300 DPI
      final int expectedWidthPx = ((spec.widthMm / 25.4) * 300).round();
      final int expectedHeightPx = ((spec.heightMm / 25.4) * 300).round();

      expect(spec.widthPixels, expectedWidthPx, reason: '${spec.id} width px match');
      expect(spec.heightPixels, expectedHeightPx, reason: '${spec.id} height px match');

      // 3. Check Aspect Ratio
      final double expectedAspect = spec.widthMm / spec.heightMm;
      expect((spec.aspectRatio - expectedAspect).abs() < 0.001, true);

      // 4. Check Biometric Head Height Ratio
      expect(spec.headRatioMin > 0.30, true, reason: '${spec.id} min head ratio must be > 30%');
      expect(spec.headRatioMax < 0.90, true, reason: '${spec.id} max head ratio must be < 90%');
      expect(spec.headRatioMax > spec.headRatioMin, true, reason: '${spec.id} max > min ratio');

      // 5. Check Eye Horizon Level Bounds
      expect(spec.eyeLevelMin >= 0.50, true, reason: '${spec.id} eye level min must be >= 50% from bottom');
      expect(spec.eyeLevelMax <= 0.75, true, reason: '${spec.id} eye level max must be <= 75% from bottom');

      // 6. Check Print Sheet Packing on 4x6" (1200 x 1800 px)
      expect(spec.printSheetCols >= 2, true);
      expect(spec.printSheetRows >= 2, true);
      final int totalPhotos = spec.photosPerSheet;
      expect(totalPhotos >= 4, true, reason: '${spec.id} must pack at least 4 photos on 4x6" sheet');

      // Total dimensions check for 4x6" paper
      final int totalW = spec.widthPixels * spec.printSheetCols;
      final int totalH = spec.heightPixels * spec.printSheetRows;
      expect(totalW <= 1200, true, reason: '${spec.id} print grid width exceeds 1200px photo paper');
      expect(totalH <= 1800, true, reason: '${spec.id} print grid height exceeds 1800px photo paper');

      print('✓ ${spec.countryCode} [${spec.countryName} - ${spec.documentTitle}]');
      print('   • Dimensions: ${spec.widthMm} x ${spec.heightMm} mm -> ${spec.widthPixels} x ${spec.heightPixels} px @ 300 DPI');
      print('   • Head Ratio: ${(spec.headRatioMin * 100).toStringAsFixed(0)}% - ${(spec.headRatioMax * 100).toStringAsFixed(0)}% (Target: ${(spec.targetHeadRatio * 100).toStringAsFixed(1)}%)');
      print('   • Eye Horizon: ${(spec.eyeLevelMin * 100).toStringAsFixed(0)}% - ${(spec.eyeLevelMax * 100).toStringAsFixed(0)}% from bottom');
      print('   • Background: ${spec.backgroundName} (${spec.backgroundColorHex})');
      print('   • 4x6" Print Sheet: ${spec.printSheetCols}x${spec.printSheetRows} grid = $totalPhotos photos\n');
    }

    print('========================================================================');
    print('ALL CONSULAR RULES AND PHOTO CUT DIMENSIONS PASSED PERFECTLY!');
    print('========================================================================\n');
  });
}
