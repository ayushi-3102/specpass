import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:specpass/data/country_specs_data.dart';
import 'package:specpass/services/photo_composer_service.dart';

void main() {
  test('PhotoComposerService background segmentation test', () async {
    // Create a 400x500 test portrait image with a gray background (#A0A0A0)
    // and a colored face/torso in the center (#D29B78 skin tone, dark hair)
    final img.Image testImage = img.Image(width: 400, height: 500, numChannels: 3);
    // Fill with gray background
    img.fill(testImage, color: img.ColorRgb8(160, 160, 160));

    // Draw a face in center (x: 150..250, y: 150..280) with skin tone
    final skin = img.ColorRgb8(210, 155, 120);
    final hair = img.ColorRgb8(40, 30, 25);
    final shirt = img.ColorRgb8(20, 50, 120);

    // Hair
    img.fillRect(testImage, x1: 140, y1: 100, x2: 260, y2: 170, color: hair);
    // Face
    img.fillRect(testImage, x1: 150, y1: 150, x2: 250, y2: 280, color: skin);
    // Torso / Shirt
    img.fillRect(testImage, x1: 80, y1: 280, x2: 320, y2: 499, color: shirt);

    final Uint8List rawBytes = Uint8List.fromList(img.encodeJpg(testImage));

    final spec = CountrySpecsData.allSpecs.first;

    final package = await PhotoComposerService.processPhotoBytes(
      rawBytes: rawBytes,
      spec: spec,
      overrideBgHex: '#FFFFFF',
    );

    expect(package.singlePhotoBytes, isNotEmpty);
    expect(package.printSheetBytes, isNotEmpty);
    expect(package.singleWidth, 600); // 2.0 inches (50.8mm) @ 300 DPI is exactly 600px
    expect(package.singleHeight, 600);
    expect(package.printSheetWidth, 1200);
    expect(package.printSheetHeight, 1800);

    // Decode processed single image
    final processedImg = img.decodeImage(package.singlePhotoBytes)!;
    
    // Top-left corner (10, 10) must be pure white (#FFFFFF = 255, 255, 255)
    final topLeft = processedImg.getPixel(10, 10);
    expect(topLeft.r, greaterThanOrEqualTo(250));
    expect(topLeft.g, greaterThanOrEqualTo(250));
    expect(topLeft.b, greaterThanOrEqualTo(250));

    // Top-right corner (590, 10) must be pure white
    final topRight = processedImg.getPixel(590, 10);
    expect(topRight.r, greaterThanOrEqualTo(250));
    expect(topRight.g, greaterThanOrEqualTo(250));
    expect(topRight.b, greaterThanOrEqualTo(250));

    // Center face (301, 260) must retain skin tone (NOT white)
    final facePixel = processedImg.getPixel(301, 260);
    expect(facePixel.r, inInclusiveRange(180, 240));
    expect(facePixel.g, inInclusiveRange(130, 180));

    // Test PDF generation
    final pdfBytes = await PhotoComposerService.generatePrintablePdf(
      printSheetBytes: package.printSheetBytes,
      spec: spec,
    );
    expect(pdfBytes, isNotEmpty);
    // PDF file header is %PDF
    expect(String.fromCharCodes(pdfBytes.sublist(0, 4)), '%PDF');

    // Test Family Print Sheet generation (combining 2 photos)
    final familySheet = await PhotoComposerService.generateFamilyPrintSheet(
      individualPhotoBytes: [package.singlePhotoBytes, package.singlePhotoBytes],
      spec: spec,
    );
    expect(familySheet, isNotEmpty);

    // Test Brightness & Contrast Adjustment
    final enhancedPackage = await PhotoComposerService.processPhotoBytes(
      rawBytes: rawBytes,
      spec: spec,
      brightness: 0.15,
      contrast: 1.20,
    );
    expect(enhancedPackage.singlePhotoBytes, isNotEmpty);

    // Test Natural Wall (Authentic) & Studio Off-White presets
    final naturalWallPackage = await PhotoComposerService.processPhotoBytes(
      rawBytes: rawBytes,
      spec: spec,
      overrideBgHex: 'original',
    );
    expect(naturalWallPackage.singlePhotoBytes, isNotEmpty);
    expect(naturalWallPackage.activeBgHex, equals('original'));

    final studioOffWhitePackage = await PhotoComposerService.processPhotoBytes(
      rawBytes: rawBytes,
      spec: spec,
      overrideBgHex: '#F8F9FA',
    );
    expect(studioOffWhitePackage.singlePhotoBytes, isNotEmpty);
    expect(studioOffWhitePackage.activeBgHex, equals('#F8F9FA'));

    // Test Baby Mode processing (infant relaxed geometry)
    final babyPackage = await PhotoComposerService.processPhotoBytes(
      rawBytes: rawBytes,
      spec: spec,
      isBabyMode: true,
    );
    expect(babyPackage.singlePhotoBytes, isNotEmpty);
  });
}
