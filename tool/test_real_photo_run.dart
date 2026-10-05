import 'dart:io';
import 'package:image/image.dart' as img;
import '../lib/data/country_specs_data.dart';
import '../lib/models/country_spec.dart';
import '../lib/services/photo_composer_service.dart';

void main() async {
  final photoPath = 'C:\\Users\\ayush\\Downloads\\My photo.jpg';
  final file = File(photoPath);
  if (!file.existsSync()) {
    print('File not found: $photoPath');
    return;
  }

  final bytes = await file.readAsBytes();
  final spec = CountrySpecsData.findById('US_PASSPORT'); // 2x2" 51x51mm @ 300 DPI (600x600 px)

  print('Processing ${spec.countryName} - ${spec.documentTitle} (${spec.formattedDimensions})...');
  final package = await PhotoComposerService.processPhotoBytes(
    rawBytes: bytes,
    spec: spec,
    overrideBgHex: '#FFFFFF',
  );

  print('Result single dimensions: ${package.singleWidth} x ${package.singleHeight} px');
  print('Result print sheet dimensions: ${package.printSheetWidth} x ${package.printSheetHeight} px');
  print('Digital portal file size: ${package.digitalPortalKb} KB (Limit: 240 KB)');
  print('Active background: ${package.activeBgHex}');

  final outSingle = File('C:\\Users\\ayush\\specpass\\test_my_photo_single.jpg');
  await outSingle.writeAsBytes(package.singlePhotoBytes);
  print('Saved single photo to ${outSingle.path}');

  final outSheet = File('C:\\Users\\ayush\\specpass\\test_my_photo_sheet.jpg');
  await outSheet.writeAsBytes(package.printSheetBytes);
  print('Saved print sheet to ${outSheet.path}');
}
