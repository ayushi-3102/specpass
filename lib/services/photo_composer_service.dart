import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import '../models/country_spec.dart';

class ProcessedPhotoPackage {
  final File singlePhotoFile;
  final File printSheetFile;
  final int singleWidth;
  final int singleHeight;
  final int printSheetWidth;
  final int printSheetHeight;
  final int photosOnSheet;

  ProcessedPhotoPackage({
    required this.singlePhotoFile,
    required this.printSheetFile,
    required this.singleWidth,
    required this.singleHeight,
    required this.printSheetWidth,
    required this.printSheetHeight,
    required this.photosOnSheet,
  });
}

class PhotoComposerService {
  PhotoComposerService._();

  /// Process photo into both a single high-res compliant photo and a 4x6" pharmacy print sheet
  static Future<ProcessedPhotoPackage> processPhoto({
    required File sourceImageFile,
    required CountrySpec spec,
  }) async {
    return compute(_processInBackground, {
      'path': sourceImageFile.path,
      'specId': spec.id,
      'widthMm': spec.widthMm,
      'heightMm': spec.heightMm,
      'targetDpi': spec.targetDpi,
      'bgHex': spec.backgroundColorHex,
    });
  }

  static Future<ProcessedPhotoPackage> _processInBackground(Map<String, dynamic> params) async {
    final String sourcePath = params['path'];
    final double widthMm = params['widthMm'];
    final double heightMm = params['heightMm'];
    final int dpi = params['targetDpi'] ?? 300;
    final String bgHex = params['bgHex'] ?? '#FFFFFF';

    final bytes = await File(sourcePath).readAsBytes();
    final img.Image? decoded = img.decodeImage(bytes);

    if (decoded == null) {
      throw Exception('Could not decode photo format.');
    }

    // Fix phone orientation
    final img.Image oriented = img.bakeOrientation(decoded);

    // Calculate target single dimensions in pixels at 300 DPI
    final int targetWidth = ((widthMm / 25.4) * dpi).round();
    final int targetHeight = ((heightMm / 25.4) * dpi).round();
    final double targetAspect = widthMm / heightMm;

    // Crop to target aspect ratio centered
    int cropW = oriented.width;
    int cropH = oriented.height;
    final double currentAspect = cropW / cropH;

    if (currentAspect > targetAspect) {
      cropW = (cropH * targetAspect).round();
    } else {
      cropH = (cropW / targetAspect).round();
    }

    final int cropX = (oriented.width - cropW) ~/ 2;
    final int cropY = (oriented.height - cropH) ~/ 2;

    final img.Image cropped = img.copyCrop(
      oriented,
      x: cropX,
      y: cropY,
      width: cropW,
      height: cropH,
    );

    // Resize to target dimensions
    final img.Image resizedSingle = img.copyResize(
      cropped,
      width: targetWidth,
      height: targetHeight,
      interpolation: img.Interpolation.cubic,
    );

    // Parse background color
    final int bgColor = _hexToColor(bgHex);
    final img.Color bgPixel = img.ColorRgb8(
      (bgColor >> 16) & 0xFF,
      (bgColor >> 8) & 0xFF,
      bgColor & 0xFF,
    );

    // Create a pristine background canvas and blend
    final img.Image finishedSingle = img.Image(
      width: targetWidth,
      height: targetHeight,
      numChannels: 3,
    );
    img.fill(finishedSingle, color: bgPixel);
    img.compositeImage(finishedSingle, resizedSingle, blend: img.BlendMode.direct);

    // Save Single Photo
    final tempDir = await getTemporaryDirectory();
    final String singlePath = '${tempDir.path}/specpass_single_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final File singleFile = File(singlePath);
    await singleFile.writeAsBytes(img.encodeJpg(finishedSingle, quality: 98));

    // ----------------------------------------------------
    // BUILD 4x6" PHARMACY PRINT SHEET (1200 x 1800 px @ 300 DPI)
    // ----------------------------------------------------
    // 4 inches = 101.6 mm, 6 inches = 152.4 mm
    // At 300 DPI: Width = 1200, Height = 1800 (Portrait) or 1800 x 1200 (Landscape)
    const int sheetW = 1200;
    const int sheetH = 1800;

    final img.Image printSheet = img.Image(width: sheetW, height: sheetH, numChannels: 3);
    // Fill sheet with crisp white photo paper
    img.fill(printSheet, color: img.ColorRgb8(255, 255, 255));

    // Determine grid rows & columns
    final int cols = (widthMm > 45) ? 2 : 2;
    final int rows = (widthMm > 45) ? 2 : 3;
    final int totalPhotos = cols * rows;

    // Calculate margins and spacing
    final int totalPhotoW = targetWidth * cols;
    final int totalPhotoH = targetHeight * rows;
    final int marginX = (sheetW - totalPhotoW) ~/ (cols + 1);
    final int marginY = (sheetH - 120 - totalPhotoH) ~/ (rows + 1) + 80;

    // Place photos and cutting guidelines
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final int x = marginX + c * (targetWidth + marginX);
        final int y = marginY + r * (targetHeight + marginY);

        img.compositeImage(printSheet, finishedSingle, dstX: x, dstY: y);

        // Draw thin scissor cutting outline around photo
        _drawDashedBorder(printSheet, x - 1, y - 1, targetWidth + 2, targetHeight + 2);
      }
    }

    // Save Print Sheet
    final String sheetPath = '${tempDir.path}/specpass_4x6_sheet_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final File sheetFile = File(sheetPath);
    await sheetFile.writeAsBytes(img.encodeJpg(printSheet, quality: 98));

    return ProcessedPhotoPackage(
      singlePhotoFile: singleFile,
      printSheetFile: sheetFile,
      singleWidth: targetWidth,
      singleHeight: targetHeight,
      printSheetWidth: sheetW,
      printSheetHeight: sheetH,
      photosOnSheet: totalPhotos,
    );
  }

  static void _drawDashedBorder(img.Image image, int x, int y, int w, int h) {
    final gray = img.ColorRgb8(190, 195, 205);
    // Draw top & bottom dashed lines
    for (int i = 0; i < w; i += 8) {
      for (int k = 0; k < 4 && (i + k) < w; k++) {
        if (x + i + k < image.width && y >= 0 && y < image.height) {
          image.setPixel(x + i + k, y, gray);
        }
        if (x + i + k < image.width && y + h < image.height) {
          image.setPixel(x + i + k, y + h, gray);
        }
      }
    }
    // Draw left & right dashed lines
    for (int i = 0; i < h; i += 8) {
      for (int k = 0; k < 4 && (i + k) < h; k++) {
        if (x >= 0 && x < image.width && y + i + k < image.height) {
          image.setPixel(x, y + i + k, gray);
        }
        if (x + w < image.width && y + i + k < image.height) {
          image.setPixel(x + w, y + i + k, gray);
        }
      }
    }
  }

  static int _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) {
      return int.parse('FF$hex', radix: 16);
    }
    return int.parse(hex, radix: 16);
  }
}
