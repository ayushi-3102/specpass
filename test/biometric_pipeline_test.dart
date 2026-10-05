import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:specpass/data/country_specs_data.dart';
import 'package:specpass/services/photo_composer_service.dart';

void main() {
  test('Verify full offline biometric processing pipeline on real 12MP user photo', () async {
    final photoPath = 'C:\\Users\\ayush\\Downloads\\My photo.jpg';
    final file = File(photoPath);
    if (!file.existsSync()) {
      print('File not found: $photoPath, skipping test');
      return;
    }

    final bytes = await file.readAsBytes();
    final spec = CountrySpecsData.findById('US_PASSPORT');

    print('Processing ${spec.countryName} - ${spec.documentTitle} (${spec.formattedDimensions})...');
    final package = await PhotoComposerService.processPhotoBytes(
      rawBytes: bytes,
      spec: spec,
      overrideBgHex: '#FFFFFF',
    );

    print('SUCCESS: Single Photo dimensions = ${package.singleWidth} x ${package.singleHeight} px');
    print('SUCCESS: Print Sheet dimensions = ${package.printSheetWidth} x ${package.printSheetHeight} px');
    print('SUCCESS: Digital Portal file size = ${package.digitalPortalKb} KB (Max limit 240 KB)');
    print('SUCCESS: Active Background = ${package.activeBgHex}');

    final outSingle = File('C:\\Users\\ayush\\specpass\\test_my_photo_single.jpg');
    await outSingle.writeAsBytes(package.singlePhotoBytes);
    print('Saved single photo to ${outSingle.path}');

    final outSheet = File('C:\\Users\\ayush\\specpass\\test_my_photo_sheet.jpg');
    await outSheet.writeAsBytes(package.printSheetBytes);
    print('Saved print sheet to ${outSheet.path}');

    expect(package.singleWidth, 600);
    expect(package.singleHeight, 600);
    expect(package.printSheetWidth, 1200);
    expect(package.printSheetHeight, 1800);
    expect(package.digitalPortalKb, lessThanOrEqualTo(240));
  });
}
