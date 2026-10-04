import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
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
  final double sensitivity;
  final double brightness;
  final double contrast;
  final bool isBabyMode;
  final String formalAttire;

  ProcessedPhotoPackage({
    required this.singlePhotoBytes,
    required this.printSheetBytes,
    required this.singleWidth,
    required this.singleHeight,
    required this.printSheetWidth,
    required this.printSheetHeight,
    required this.photosOnSheet,
    this.activeBgHex = '#FFFFFF',
    this.sensitivity = 1.0,
    this.brightness = 0.0,
    this.contrast = 1.0,
    this.isBabyMode = false,
    this.formalAttire = 'none',
  });
}

class PhotoComposerService {
  PhotoComposerService._();

  /// Process photo into both a single high-res compliant photo and a 4x6" pharmacy print sheet
  static Future<ProcessedPhotoPackage> processPhotoBytes({
    required Uint8List rawBytes,
    required CountrySpec spec,
    String? overrideBgHex,
    double sensitivity = 1.0,
    double brightness = 0.0,
    double contrast = 1.0,
    bool isBabyMode = false,
    String formalAttire = 'none',
  }) async {
    return compute(_processInBackground, {
      'bytes': rawBytes,
      'specId': spec.id,
      'widthMm': spec.widthMm,
      'heightMm': spec.heightMm,
      'targetDpi': spec.targetDpi,
      'bgHex': overrideBgHex ?? spec.backgroundColorHex,
      'sensitivity': sensitivity,
      'brightness': brightness,
      'contrast': contrast,
      'isBabyMode': isBabyMode,
      'formalAttire': formalAttire,
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

    final double sensitivity = (params['sensitivity'] as num?)?.toDouble() ?? 1.0;
    final double brightness = (params['brightness'] as num?)?.toDouble() ?? 0.0;
    final double contrast = (params['contrast'] as num?)?.toDouble() ?? 1.0;
    final bool isBabyMode = params['isBabyMode'] == true;
    final String formalAttire = params['formalAttire'] ?? 'none';

    // Apply brightness & contrast fine-tuning
    if (brightness != 0.0 || contrast != 1.0) {
      _applyBrightnessContrast(resizedSingle, brightness, contrast);
    }

    // Apply formal attire overlay if requested
    if (formalAttire != 'none') {
      _applyFormalAttire(resizedSingle, formalAttire);
    }

    // -------------------------------------------------------------------------
    // BIOMETRIC BACKGROUND SEGMENTATION & REPLACEMENT
    // Isolates the person from the background wall and renders target bg color
    // -------------------------------------------------------------------------
    final img.Image finishedSingle = _removeBackgroundAndReplace(
      source: resizedSingle,
      targetBgColor: bgPixel,
      sensitivity: sensitivity,
      isBabyMode: isBabyMode,
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
      sensitivity: sensitivity,
      brightness: brightness,
      contrast: contrast,
      isBabyMode: isBabyMode,
      formalAttire: formalAttire,
    );
  }

  /// On-device edge-aware flood-fill segmentation that isolates the background
  /// and replaces it with compliant solid white or light gray.
  static img.Image _removeBackgroundAndReplace({
    required img.Image source,
    required img.Color targetBgColor,
    double sensitivity = 1.0,
    bool isBabyMode = false,
  }) {
    final int width = source.width;
    final int height = source.height;

    // 1. Sample background colors from top corners and perimeter
    int sampleCount = 0;
    double sumR = 0, sumG = 0, sumB = 0;

    for (int y = 0; y < (height * 0.15).round(); y++) {
      for (int x = 0; x < width; x++) {
        if (y < (height * 0.08).round() || x < (width * 0.20).round() || x > (width * 0.80).round()) {
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

    // 2. Head & Torso Protection Zone (Centered Biometric Ellipse)
    final double centerX = width * 0.50;
    final double centerY = height * (isBabyMode ? 0.48 : 0.44);
    final double radiusX = width * (isBabyMode ? 0.32 : 0.28);
    final double radiusY = height * (isBabyMode ? 0.38 : 0.34);

    // 3. Flood-fill background detection
    final List<bool> isBg = List<bool>.filled(width * height, false);
    final List<int> queue = [];

    // Seed the perimeter pixels (top edge and upper 72% of sides)
    for (int x = 0; x < width; x++) {
      queue.add(x); // y = 0
      isBg[x] = true;
    }
    for (int y = 1; y < (height * 0.72).round(); y++) {
      queue.add(y * width); // x = 0
      isBg[y * width] = true;

      queue.add(y * width + (width - 1)); // x = width - 1
      isBg[y * width + (width - 1)] = true;
    }

    // Adaptive tolerance scaled by sensitivity
    final double baseTolerance = 52.0 * sensitivity.clamp(0.6, 2.0);
    final double neighborTolerance = 30.0 * sensitivity.clamp(0.6, 2.0);

    int head = 0;
    while (head < queue.length) {
      final int idx = queue[head++];
      final int cx = idx % width;
      final int cy = idx ~/ width;
      final currentPixel = source.getPixel(cx, cy);

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
          final bool inCoreHead = (dx * dx + dy * dy) < 0.62;

          if (!inCoreHead) {
            final p = source.getPixel(nx, ny);
            
            // Distance from global background average
            final double dr = (p.r - avgR).abs();
            final double dg = (p.g - avgG).abs();
            final double db = (p.b - avgB).abs();
            final double dist = dr * 0.299 + dg * 0.587 + db * 0.114;
            final double euclid = (dr * dr + dg * dg + db * db);

            // Local neighbor continuity difference
            final double localDr = (p.r - currentPixel.r).abs().toDouble();
            final double localDg = (p.g - currentPixel.g).abs().toDouble();
            final double localDb = (p.b - currentPixel.b).abs().toDouble();
            final double localDist = localDr * 0.299 + localDg * 0.587 + localDb * 0.114;

            final bool matchesGlobal = dist < baseTolerance || euclid < (baseTolerance * baseTolerance * 1.5);
            final bool matchesLocal = localDist < neighborTolerance && dist < (baseTolerance * 1.4);

            if (matchesGlobal || matchesLocal) {
              isBg[nIdx] = true;
              queue.add(nIdx);
            }
          }
        }
      }
    }

    // 4. Composite result with soft edge antialiasing
    final img.Image result = img.Image(width: width, height: height, numChannels: 3);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int idx = y * width + x;
        if (isBg[idx]) {
          result.setPixel(x, y, targetBgColor);
        } else {
          // Check if boundary pixel next to background for soft feathering
          int bgNeighborCount = 0;
          if (x > 0 && isBg[idx - 1]) bgNeighborCount++;
          if (x < width - 1 && isBg[idx + 1]) bgNeighborCount++;
          if (y > 0 && isBg[idx - width]) bgNeighborCount++;
          if (y < height - 1 && isBg[idx + width]) bgNeighborCount++;

          if (bgNeighborCount >= 2) {
            // Soft 15% edge blend with target background
            final srcP = source.getPixel(x, y);
            final blendedR = (srcP.r * 0.85 + targetBgColor.r * 0.15).round();
            final blendedG = (srcP.g * 0.85 + targetBgColor.g * 0.15).round();
            final blendedB = (srcP.b * 0.85 + targetBgColor.b * 0.15).round();
            result.setPixelRgb(x, y, blendedR, blendedG, blendedB);
          } else {
            result.setPixel(x, y, source.getPixel(x, y));
          }
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

  static void _applyBrightnessContrast(img.Image image, double brightness, double contrast) {
    if (brightness == 0.0 && contrast == 1.0) return;
    for (final pixel in image) {
      double r = pixel.r.toDouble();
      double g = pixel.g.toDouble();
      double b = pixel.b.toDouble();
      r = ((r - 128.0) * contrast + 128.0 + (brightness * 75.0)).clamp(0.0, 255.0);
      g = ((g - 128.0) * contrast + 128.0 + (brightness * 75.0)).clamp(0.0, 255.0);
      b = ((b - 128.0) * contrast + 128.0 + (brightness * 75.0)).clamp(0.0, 255.0);
      pixel.r = r.round();
      pixel.g = g.round();
      pixel.b = b.round();
    }
  }

  static void _applyFormalAttire(img.Image image, String style) {
    final int width = image.width;
    final int height = image.height;

    // Determine suit color based on style
    final suitColor = (style == 'navy_suit')
        ? img.ColorRgb8(24, 38, 68) // Navy Blazer
        : img.ColorRgb8(32, 34, 40); // Charcoal Executive

    final lapelColor = (style == 'navy_suit')
        ? img.ColorRgb8(16, 28, 52)
        : img.ColorRgb8(22, 24, 28);

    final shirtColor = img.ColorRgb8(250, 252, 255);
    final tieColor = img.ColorRgb8(120, 28, 36); // Classic Burgundy or Dark Slate

    final int startY = (height * 0.76).round();
    final int centerX = width ~/ 2;

    for (int y = startY; y < height; y++) {
      final double progress = (y - startY) / (height - startY);
      final int shoulderSpread = (width * (0.28 + progress * 0.32)).round();
      final int leftShoulder = (centerX - shoulderSpread).clamp(0, width - 1);
      final int rightShoulder = (centerX + shoulderSpread).clamp(0, width - 1);

      for (int x = leftShoulder; x <= rightShoulder; x++) {
        final int distFromCenter = (x - centerX).abs();
        final int vWidthAtY = ((1.0 - progress * 0.4) * (width * 0.11)).round();

        if (distFromCenter < vWidthAtY) {
          // Inside V-neck / shirt & tie area
          if (distFromCenter <= (width * 0.024).round() && progress > 0.18) {
            image.setPixel(x, y, tieColor);
          } else {
            image.setPixel(x, y, shirtColor);
          }
        } else if (distFromCenter < vWidthAtY + (width * 0.05).round()) {
          // Lapel
          image.setPixel(x, y, lapelColor);
        } else {
          // Suit jacket
          image.setPixel(x, y, suitColor);
        }
      }
    }
  }

  /// Generates a printable PDF with:
  /// - Page 1: Exact 10×15 cm (4×6") borderless sheet (optimal for photo kiosks / AirPrint)
  /// - Page 2: Standard A4 Document with centered sheet and German/US kiosk instructions
  static Future<Uint8List> generatePrintablePdf({
    required Uint8List printSheetBytes,
    required CountrySpec spec,
  }) async {
    final pdf = pw.Document();
    final image = pw.MemoryImage(printSheetBytes);

    // Page 1: Exact 10x15 cm (4x6") sheet for borderless photo printing (288 x 432 pt)
    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(288, 432, marginAll: 0),
        build: (pw.Context context) {
          return pw.FullPage(
            ignoreMargins: true,
            child: pw.Center(
              child: pw.Image(image, fit: pw.BoxFit.contain),
            ),
          );
        },
      ),
    );

    // Page 2: Standard A4 Document with sheet centered & cutting guides + localized instructions
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('SpecPass Biometric Passport Photo Sheet', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                    pw.Text('${spec.countryName} (${spec.formattedDimensions})', style: const pw.TextStyle(fontSize: 11)),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),
              pw.Container(
                width: 288,
                height: 432,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey500, width: 1),
                ),
                child: pw.Image(image, fit: pw.BoxFit.contain),
              ),
              pw.SizedBox(height: 16),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: const pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'PRINTING INSTRUCTIONS (100% SCALE):',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.black),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      '1. Print at "Actual Size" or 100% scale. Do NOT select "Fit to Printable Area".\n'
                      '2. For Germany (dm / Rossmann): At the kiosk choose "Foto sofort 10x15 cm" (cost: ~0.27 EUR). Select "Ohne Rand".\n'
                      '3. Use glossy or semi-matte photo paper. Cut along the dashed boundary lines.',
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Generates a combined multi-person Family Sheet (e.g. 2 for Dad, 2 for Mom, 2 for Child)
  /// on a single 10x15 cm (4x6") sheet for dm / Walgreens.
  static Future<Uint8List> generateFamilyPrintSheet({
    required List<Uint8List> individualPhotoBytes,
    required CountrySpec spec,
  }) async {
    const int sheetW = 1200;
    const int sheetH = 1800;

    final img.Image printSheet = img.Image(width: sheetW, height: sheetH, numChannels: 3);
    img.fill(printSheet, color: img.ColorRgb8(255, 255, 255));

    final int targetWidth = ((spec.widthMm / 25.4) * spec.targetDpi).round();
    final int targetHeight = ((spec.heightMm / 25.4) * spec.targetDpi).round();

    final int cols = (spec.widthMm > 45) ? 2 : 2;
    final int rows = (spec.widthMm > 45) ? 2 : 3;

    final int totalPhotoW = targetWidth * cols;
    final int totalPhotoH = targetHeight * rows;
    final int marginX = (sheetW - totalPhotoW) ~/ (cols + 1);
    final int marginY = (sheetH - 120 - totalPhotoH) ~/ (rows + 1) + 80;

    final List<img.Image> decodedPhotos = [];
    for (final bytes in individualPhotoBytes) {
      final d = img.decodeImage(bytes);
      if (d != null) {
        decodedPhotos.add(img.copyResize(d, width: targetWidth, height: targetHeight));
      }
    }

    if (decodedPhotos.isEmpty) return Uint8List(0);

    int photoIdx = 0;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final currentMemberImg = decodedPhotos[photoIdx % decodedPhotos.length];
        final int x = marginX + c * (targetWidth + marginX);
        final int y = marginY + r * (targetHeight + marginY);

        img.compositeImage(printSheet, currentMemberImg, dstX: x, dstY: y);
        _drawDashedBorder(printSheet, x - 1, y - 1, targetWidth + 2, targetHeight + 2);

        photoIdx++;
      }
    }

    return Uint8List.fromList(img.encodeJpg(printSheet, quality: 98));
  }

  static int _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) {
      return int.parse('FF$hex', radix: 16);
    }
    return int.parse(hex, radix: 16);
  }
}
