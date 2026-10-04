import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import '../models/country_spec.dart';

class ProcessedPhotoPackage {
  final Uint8List singlePhotoBytes;
  final Uint8List printSheetBytes;
  final int singleWidth;
  final int singleHeight;
  final int printSheetWidth;
  final int printSheetHeight;
  final int photosOnSheet;
  final String activeBgHex;

  ProcessedPhotoPackage({
    required this.singlePhotoBytes,
    required this.printSheetBytes,
    required this.singleWidth,
    required this.singleHeight,
    required this.printSheetWidth,
    required this.printSheetHeight,
    required this.photosOnSheet,
    this.activeBgHex = '#FFFFFF',
  });
}

class PhotoComposerService {
  PhotoComposerService._();

  /// Process photo into both a single high-res compliant photo and a 4x6" pharmacy print sheet
  static Future<ProcessedPhotoPackage> processPhotoBytes({
    required Uint8List rawBytes,
    required CountrySpec spec,
    String? overrideBgHex,
  }) async {
    return compute(_processInBackground, {
      'bytes': rawBytes,
      'specId': spec.id,
      'widthMm': spec.widthMm,
      'heightMm': spec.heightMm,
      'targetDpi': spec.targetDpi,
      'bgHex': overrideBgHex ?? spec.backgroundColorHex,
    });
  }

  static Future<ProcessedPhotoPackage> _processInBackground(Map<String, dynamic> params) async {
    final Uint8List rawBytes = params['bytes'];
    final double widthMm = params['widthMm'];
    final double heightMm = params['heightMm'];
    final int dpi = params['targetDpi'] ?? 300;
    final String bgHex = params['bgHex'] ?? '#FFFFFF';

    final img.Image? decoded = img.decodeImage(rawBytes);

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

    // Parse target background color
    final int bgColor = _hexToColor(bgHex);
    final img.Color bgPixel = img.ColorRgb8(
      (bgColor >> 16) & 0xFF,
      (bgColor >> 8) & 0xFF,
      bgColor & 0xFF,
    );

    // -------------------------------------------------------------------------
    // BIOMETRIC BACKGROUND SEGMENTATION & REPLACEMENT
    // Isolates the person from the background wall and renders target bg color
    // -------------------------------------------------------------------------
    final img.Image finishedSingle = _removeBackgroundAndReplace(
      source: resizedSingle,
      targetBgColor: bgPixel,
    );

    final Uint8List singleJpgBytes = Uint8List.fromList(img.encodeJpg(finishedSingle, quality: 98));

    // ----------------------------------------------------
    // BUILD 4x6" PHARMACY PRINT SHEET (1200 x 1800 px @ 300 DPI)
    // ----------------------------------------------------
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

    final Uint8List sheetJpgBytes = Uint8List.fromList(img.encodeJpg(printSheet, quality: 98));

    return ProcessedPhotoPackage(
      singlePhotoBytes: singleJpgBytes,
      printSheetBytes: sheetJpgBytes,
      singleWidth: targetWidth,
      singleHeight: targetHeight,
      printSheetWidth: sheetW,
      printSheetHeight: sheetH,
      photosOnSheet: totalPhotos,
      activeBgHex: bgHex,
    );
  }

  /// On-device edge-aware flood-fill segmentation that isolates the background
  /// and replaces it with compliant solid white or light gray.
  static img.Image _removeBackgroundAndReplace({
    required img.Image source,
    required img.Color targetBgColor,
  }) {
    final int width = source.width;
    final int height = source.height;

    // 1. Sample background colors from top corners and perimeter
    int sampleCount = 0;
    double sumR = 0, sumG = 0, sumB = 0;

    for (int y = 0; y < (height * 0.15).round(); y++) {
      for (int x = 0; x < width; x++) {
        if (y < (height * 0.08).round() || x < (width * 0.18).round() || x > (width * 0.82).round()) {
          final pixel = source.getPixel(x, y);
          sumR += pixel.r;
          sumG += pixel.g;
          sumB += pixel.b;
          sampleCount++;
        }
      }
    }

    if (sampleCount == 0) sampleCount = 1;
    final double avgR = sumR / sampleCount;
    final double avgG = sumG / sampleCount;
    final double avgB = sumB / sampleCount;

    // 2. Head & Torso Protection Zone
    final double centerX = width * 0.50;
    final double centerY = height * 0.44;
    final double radiusX = width * 0.28;
    final double radiusY = height * 0.34;

    // 3. Flood-fill background detection
    final List<bool> isBg = List<bool>.filled(width * height, false);
    final List<int> queue = [];

    // Seed the perimeter pixels (top edge and upper half of sides)
    for (int x = 0; x < width; x++) {
      queue.add(x); // y = 0
      isBg[x] = true;
    }
    for (int y = 1; y < (height * 0.70).round(); y++) {
      queue.add(y * width); // x = 0
      isBg[y * width] = true;

      queue.add(y * width + (width - 1)); // x = width - 1
      isBg[y * width + (width - 1)] = true;
    }

    const double baseTolerance = 52.0;

    int head = 0;
    while (head < queue.length) {
      final int idx = queue[head++];
      final int cx = idx % width;
      final int cy = idx ~/ width;

      final neighbors = [
        if (cx > 0) idx - 1,
        if (cx < width - 1) idx + 1,
        if (cy > 0) idx - width,
        if (cy < height - 1) idx + width,
      ];

      for (final nIdx in neighbors) {
        if (!isBg[nIdx]) {
          final int nx = nIdx % width;
          final int ny = nIdx ~/ width;

          // Protect the core facial area from being deleted
          final double dx = (nx - centerX) / radiusX;
          final double dy = (ny - centerY) / radiusY;
          final bool inCoreHead = (dx * dx + dy * dy) < 0.65;

          if (!inCoreHead) {
            final p = source.getPixel(nx, ny);
            final double dr = (p.r - avgR).abs();
            final double dg = (p.g - avgG).abs();
            final double db = (p.b - avgB).abs();
            final double dist = dr * 0.299 + dg * 0.587 + db * 0.114;
            final double euclid = (dr * dr + dg * dg + db * db);

            if (dist < baseTolerance || euclid < (baseTolerance * baseTolerance * 1.5)) {
              isBg[nIdx] = true;
              queue.add(nIdx);
            }
          }
        }
      }
    }

    // 4. Composite result with target background
    final img.Image result = img.Image(width: width, height: height, numChannels: 3);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int idx = y * width + x;
        if (isBg[idx]) {
          result.setPixel(x, y, targetBgColor);
        } else {
          result.setPixel(x, y, source.getPixel(x, y));
        }
      }
    }

    return result;
  }

  static void _drawDashedBorder(img.Image image, int x, int y, int w, int h) {
    final gray = img.ColorRgb8(190, 195, 205);
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
