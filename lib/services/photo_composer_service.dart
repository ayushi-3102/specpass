import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_selfie_segmentation/google_mlkit_selfie_segmentation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
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
  }) async {
    List<double>? neuralMask;
    int? maskW;
    int? maskH;

    final targetHex = overrideBgHex ?? spec.backgroundColorHex;
    final bool isOriginalBg = targetHex.toLowerCase() == 'original' || sensitivity <= 0.05;

    // Run on-device Neural AI Segmentation (Google ML Kit) when background replacement is requested
    if (!isOriginalBg) {
      try {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/ml_seg_${DateTime.now().microsecondsSinceEpoch}.jpg');
        await tempFile.writeAsBytes(rawBytes);

        final inputImage = InputImage.fromFilePath(tempFile.path);
        final segmenter = SelfieSegmenter(
          mode: SegmenterMode.single,
          enableRawSizeMask: true,
        );

        final mask = await segmenter.processImage(inputImage);
        await segmenter.close();
        if (tempFile.existsSync()) {
          await tempFile.delete();
        }

        if (mask != null) {
          neuralMask = mask.confidences;
          maskW = mask.width;
          maskH = mask.height;
        }
      } catch (_) {
        // Gracefully falls back to color-decontaminated CPU segmentation in headless/test environments
      }
    }

    return compute(_processInBackground, {
      'bytes': rawBytes,
      'specId': spec.id,
      'widthMm': spec.widthMm,
      'heightMm': spec.heightMm,
      'targetDpi': spec.targetDpi,
      'bgHex': targetHex,
      'sensitivity': sensitivity,
      'brightness': brightness,
      'contrast': contrast,
      'isBabyMode': isBabyMode,
      'neuralMask': neuralMask,
      'maskW': maskW,
      'maskH': maskH,
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

    final double sensitivity = (params['sensitivity'] as num?)?.toDouble() ?? 1.0;
    final double brightness = (params['brightness'] as num?)?.toDouble() ?? 0.0;
    final double contrast = (params['contrast'] as num?)?.toDouble() ?? 1.0;
    final bool isBabyMode = params['isBabyMode'] == true;

    // Parse target background color (or preserve original wall if requested)
    final bool isOriginalBg = bgHex.toLowerCase() == 'original' || sensitivity <= 0.05;
    final int bgColor = isOriginalBg ? 0xFFFFFF : _hexToColor(bgHex);
    final img.Color bgPixel = img.ColorRgb8(
      (bgColor >> 16) & 0xFF,
      (bgColor >> 8) & 0xFF,
      bgColor & 0xFF,
    );

    // Apply professional studio portrait lighting and eye clarity
    _applyStudioPortraitEnhance(resizedSingle);

    // Apply brightness & contrast fine-tuning
    if (brightness != 0.0 || contrast != 1.0) {
      _applyBrightnessContrast(resizedSingle, brightness, contrast);
    }

    // -------------------------------------------------------------------------
    // BIOMETRIC BACKGROUND SEGMENTATION & REPLACEMENT
    // 1. If 'original' wall requested -> keep real wall untouched
    // 2. If Neural AI Mask available -> apply Google ML Kit semantic segmentation
    // 3. Otherwise -> apply color-decontaminated skin-safe flood fill
    // -------------------------------------------------------------------------
    final List<double>? neuralMask = params['neuralMask'] as List<double>?;
    final int? maskW = params['maskW'] as int?;
    final int? maskH = params['maskH'] as int?;

    final img.Image finishedSingle;
    if (isOriginalBg) {
      finishedSingle = resizedSingle;
    } else if (neuralMask != null && maskW != null && maskH != null) {
      finishedSingle = _applyNeuralMaskAndStudioLighting(
        source: resizedSingle,
        confidences: neuralMask,
        maskWidth: maskW,
        maskHeight: maskH,
        targetBgColor: bgPixel,
        cropX: cropX,
        cropY: cropY,
        cropW: cropW,
        cropH: cropH,
        originalW: oriented.width,
        originalH: oriented.height,
      );
    } else {
      finishedSingle = _removeBackgroundAndReplace(
        source: resizedSingle,
        targetBgColor: bgPixel,
        sensitivity: sensitivity,
        isBabyMode: isBabyMode,
      );
    }

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
    );
  }

  /// Composites the subject onto the official studio background using the Neural AI mask
  /// with sub-pixel feathering, studio lighting falloff, and exact coordinate mapping.
  static img.Image _applyNeuralMaskAndStudioLighting({
    required img.Image source,
    required List<double> confidences,
    required int maskWidth,
    required int maskHeight,
    required img.Color targetBgColor,
    required int cropX,
    required int cropY,
    required int cropW,
    required int cropH,
    required int originalW,
    required int originalH,
  }) {
    final int width = source.width;
    final int height = source.height;
    final img.Image result = img.Image(width: width, height: height, numChannels: 3);

    for (int y = 0; y < height; y++) {
      // Gentle studio lighting falloff (simulates real studio flash umbrella)
      final double studioGrad = 1.0 - (y / height) * 0.025;
      final int studioR = (targetBgColor.r * studioGrad).round().clamp(0, 255);
      final int studioG = (targetBgColor.g * studioGrad).round().clamp(0, 255);
      final int studioB = (targetBgColor.b * studioGrad).round().clamp(0, 255);

      final double normY = y / height;
      final double origY = cropY + normY * cropH;
      final int my = ((origY / originalH) * maskHeight).floor().clamp(0, maskHeight - 1);

      for (int x = 0; x < width; x++) {
        final double normX = x / width;
        final double origX = cropX + normX * cropW;
        final int mx = ((origX / originalW) * maskWidth).floor().clamp(0, maskWidth - 1);

        final double confidence = confidences[my * maskWidth + mx];

        if (confidence <= 0.08) {
          // 100% Studio background
          result.setPixelRgb(x, y, studioR, studioG, studioB);
        } else if (confidence >= 0.92) {
          // 100% Human subject
          result.setPixel(x, y, source.getPixel(x, y));
        } else {
          // Sub-pixel optical feathering on hair & clothing edges
          final double fgAlpha = (confidence - 0.08) / (0.92 - 0.08);
          final double bgAlpha = 1.0 - fgAlpha;
          final p = source.getPixel(x, y);
          final int r = (p.r * fgAlpha + studioR * bgAlpha).round().clamp(0, 255);
          final int g = (p.g * fgAlpha + studioG * bgAlpha).round().clamp(0, 255);
          final int b = (p.b * fgAlpha + studioB * bgAlpha).round().clamp(0, 255);
          result.setPixelRgb(x, y, r, g, b);
        }
      }
    }

    return result;
  }

  /// Checks whether a given RGB pixel is human skin tone using ITU-R BT.601 chrominance
  static bool _isSkinColor(num r, num g, num b) {
    if (r <= 45 || g <= 30 || b <= 20) return false;
    
    // In typical illumination: Red is greater than Green, Green is greater than or close to Blue
    final bool rgbOrder = (r > g) && (g >= (b - 6));
    final num rDiff = r - g;
    final num maxVal = math.max(r, math.max(g, b));
    final num minVal = math.min(r, math.min(g, b));
    
    if (rgbOrder && rDiff >= 10 && (maxVal - minVal) >= 14) {
      // YCbCr chrominance cluster for human skin
      final double cb = 128 - 0.168736 * r - 0.331264 * g + 0.5 * b;
      final double cr = 128 + 0.5 * r - 0.418688 * g - 0.081312 * b;
      if (cb >= 70 && cb <= 140 && cr >= 128 && cr <= 185) {
        return true;
      }
    }
    return false;
  }

  /// On-device edge-aware flood-fill segmentation that isolates the background
  /// while strictly protecting the person's face, skin, hair, and clothing.
  static img.Image _removeBackgroundAndReplace({
    required img.Image source,
    required img.Color targetBgColor,
    double sensitivity = 1.0,
    bool isBabyMode = false,
  }) {
    final int width = source.width;
    final int height = source.height;

    // 1. Sample true background color strictly from top-left and top-right corner patches
    // Never sample from the top-center where the person's head/hair is located!
    final int cornerW = (width * 0.12).round().clamp(6, 60);
    final int cornerH = (height * 0.12).round().clamp(6, 60);

    double sumR = 0, sumG = 0, sumB = 0;
    int sampleCount = 0;

    // Top-left corner
    for (int y = 0; y < cornerH; y++) {
      for (int x = 0; x < cornerW; x++) {
        final pixel = source.getPixel(x, y);
        if (!_isSkinColor(pixel.r, pixel.g, pixel.b)) {
          sumR += pixel.r;
          sumG += pixel.g;
          sumB += pixel.b;
          sampleCount++;
        }
      }
    }

    // Top-right corner
    for (int y = 0; y < cornerH; y++) {
      for (int x = width - cornerW; x < width; x++) {
        final pixel = source.getPixel(x, y);
        if (!_isSkinColor(pixel.r, pixel.g, pixel.b)) {
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
    final double bgLuma = avgR * 0.299 + avgG * 0.587 + avgB * 0.114;

    // 2. Adaptive tolerances
    final double baseTolerance = (38.0 * sensitivity.clamp(0.4, 2.0)).clamp(16.0, 70.0);
    final double neighborTolerance = (18.0 * sensitivity.clamp(0.4, 2.0)).clamp(8.0, 40.0);

    // 3. Flood-fill background detection with skin & hair boundaries
    final List<bool> isBg = List<bool>.filled(width * height, false);
    final List<int> queue = [];

    // Helper: is pixel valid background seed candidate?
    bool isCandidateBg(int x, int y) {
      final p = source.getPixel(x, y);
      if (_isSkinColor(p.r, p.g, p.b)) return false;
      
      final double pLuma = p.r * 0.299 + p.g * 0.587 + p.b * 0.114;
      // If background is light wall, dark hair / clothing must NOT be background
      if (bgLuma > 120 && pLuma < 85) return false;

      final double dr = (p.r - avgR).abs();
      final double dg = (p.g - avgG).abs();
      final double db = (p.b - avgB).abs();
      final double dist = dr * 0.299 + dg * 0.587 + db * 0.114;
      return dist < baseTolerance;
    }

    // Seed top edge corners safely (never blindly seeding hair or face in center)
    for (int x = 0; x < width; x++) {
      if (isCandidateBg(x, 0)) {
        queue.add(x);
        isBg[x] = true;
      }
    }
    // Seed sides
    for (int y = 1; y < (height * 0.75).round(); y++) {
      if (isCandidateBg(0, y)) {
        queue.add(y * width);
        isBg[y * width] = true;
      }
      final rightIdx = y * width + (width - 1);
      if (isCandidateBg(width - 1, y)) {
        queue.add(rightIdx);
        isBg[rightIdx] = true;
      }
    }

    // Central subject region for extra conservative boundary check
    final int minSubjectX = (width * 0.18).round();
    final int maxSubjectX = (width * 0.82).round();
    final int minSubjectY = (height * 0.10).round();
    final int maxSubjectY = (height * 0.88).round();

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
          final p = source.getPixel(nx, ny);

          // Rule 1: Skin is 100% NEVER background (protects forehead, cheeks, chin, neck)
          if (_isSkinColor(p.r, p.g, p.b)) {
            continue;
          }

          // Rule 2: Dark hair / eyes / beard against light background is NEVER background
          final double pLuma = p.r * 0.299 + p.g * 0.587 + p.b * 0.114;
          if (bgLuma > 120 && pLuma < 85) {
            continue;
          }

          // Rule 3: Central subject protection against low-contrast edge penetration
          final bool inSubjectZone = nx >= minSubjectX && nx <= maxSubjectX && ny >= minSubjectY && ny <= maxSubjectY;

          final double dr = (p.r - avgR).abs();
          final double dg = (p.g - avgG).abs();
          final double db = (p.b - avgB).abs();
          final double dist = dr * 0.299 + dg * 0.587 + db * 0.114;

          final double localDr = (p.r - currentPixel.r).abs().toDouble();
          final double localDg = (p.g - currentPixel.g).abs().toDouble();
          final double localDb = (p.b - currentPixel.b).abs().toDouble();
          final double localDist = localDr * 0.299 + localDg * 0.587 + localDb * 0.114;

          final double effectiveBaseTol = inSubjectZone ? (baseTolerance * 0.82) : baseTolerance;
          final double effectiveNeighborTol = inSubjectZone ? (neighborTolerance * 0.75) : neighborTolerance;

          final bool matchesGlobal = dist < effectiveBaseTol;
          final bool matchesLocal = localDist < effectiveNeighborTol && dist < (effectiveBaseTol * 1.25);

          if (matchesGlobal && matchesLocal) {
            isBg[nIdx] = true;
            queue.add(nIdx);
          }
        }
      }
    }

    // 4. Composite result with subtle studio lighting falloff and multi-pixel feathering
    final img.Image result = img.Image(width: width, height: height, numChannels: 3);

    for (int y = 0; y < height; y++) {
      // Soft natural studio illumination falloff (1.0 at top down to 0.975 at bottom)
      // This prevents harsh stark vector-white and replicates real photo studio backdrop lighting
      final double studioGrad = 1.0 - (y / height) * 0.025;
      final int studioR = (targetBgColor.r * studioGrad).round().clamp(0, 255);
      final int studioG = (targetBgColor.g * studioGrad).round().clamp(0, 255);
      final int studioB = (targetBgColor.b * studioGrad).round().clamp(0, 255);

      for (int x = 0; x < width; x++) {
        final int idx = y * width + x;
        if (isBg[idx]) {
          result.setPixelRgb(x, y, studioR, studioG, studioB);
        } else {
          // Multi-directional anti-aliasing check around subject perimeter
          int bgNeighborCount = 0;
          for (int dy = -1; dy <= 1; dy++) {
            final int ny = y + dy;
            if (ny < 0 || ny >= height) continue;
            for (int dx = -1; dx <= 1; dx++) {
              if (dx == 0 && dy == 0) continue;
              final int nx = x + dx;
              if (nx < 0 || nx >= width) continue;
              if (isBg[ny * width + nx]) bgNeighborCount++;
            }
          }

          if (bgNeighborCount > 0) {
            final srcP = source.getPixel(x, y);

            // 1. Color Decontamination: Remove old wall color cast from fine edge strands
            final double wallColorDist = (srcP.r - avgR).abs() * 0.299 + (srcP.g - avgG).abs() * 0.587 + (srcP.b - avgB).abs() * 0.114;
            double edgeR = srcP.r.toDouble();
            double edgeG = srcP.g.toDouble();
            double edgeB = srcP.b.toDouble();

            // If edge pixel has old wall color bleeding into it, neutralize the fringe
            if (wallColorDist < 48.0) {
              final double decontam = (1.0 - (wallColorDist / 48.0)) * 0.38;
              edgeR = edgeR * (1.0 - decontam) + studioR * decontam;
              edgeG = edgeG * (1.0 - decontam) + studioG * decontam;
              edgeB = edgeB * (1.0 - decontam) + studioB * decontam;
            }

            // 2. Optical Studio Light-Wrap:
            // High-end photo studios have light wrapping naturally around the subject's edges
            final double bgWeight = (bgNeighborCount / 8.0) * 0.45;
            final double fgWeight = 1.0 - bgWeight;
            final int blendedR = (edgeR * fgWeight + studioR * bgWeight).round().clamp(0, 255);
            final int blendedG = (edgeG * fgWeight + studioG * bgWeight).round().clamp(0, 255);
            final int blendedB = (edgeB * fgWeight + studioB * bgWeight).round().clamp(0, 255);
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

  /// Enhances smartphone portraits with professional studio lighting characteristics:
  /// 1. Studio Reflector Fill: Gently lifts deep shadows in eye sockets and under chin
  /// 2. Highlight Protection: Keeps skin tones vibrant without blowing out highlights
  /// 3. Crisp Eye & Facial Clarity: Calibrated unsharp mask for 300 DPI print sharpness
  static void _applyStudioPortraitEnhance(img.Image image, {
    double shadowLift = 0.16,
    double clarity = 0.14,
  }) {
    final int width = image.width;
    final int height = image.height;

    // Step 1: Shadow Fill (Reflector flash simulation)
    for (final pixel in image) {
      final double luma = pixel.r * 0.299 + pixel.g * 0.587 + pixel.b * 0.114;
      // Gentle shadow curve: lifts pixels below 135 luminance, smoothly tapering off
      if (luma < 140.0) {
        final double shadowFactor = (1.0 - luma / 140.0) * shadowLift;
        final int boost = (shadowFactor * 36.0).round();
        pixel.r = (pixel.r + boost).clamp(0, 255);
        pixel.g = (pixel.g + boost).clamp(0, 255);
        pixel.b = (pixel.b + boost).clamp(0, 255);
      }
    }

    // Step 2: Unsharp clarity enhancement on facial features (3x3 kernel)
    if (clarity > 0.02) {
      final original = img.Image.from(image);
      final double sharpWeight = clarity.clamp(0.05, 0.25);

      for (int y = 1; y < height - 1; y++) {
        for (int x = 1; x < width - 1; x++) {
          final center = original.getPixel(x, y);
          final up = original.getPixel(x, y - 1);
          final down = original.getPixel(x, y + 1);
          final left = original.getPixel(x - 1, y);
          final right = original.getPixel(x + 1, y);

          final double avgSurroundR = (up.r + down.r + left.r + right.r) / 4.0;
          final double avgSurroundG = (up.g + down.g + left.g + right.g) / 4.0;
          final double avgSurroundB = (up.b + down.b + left.b + right.b) / 4.0;

          final double diffR = center.r - avgSurroundR;
          final double diffG = center.g - avgSurroundG;
          final double diffB = center.b - avgSurroundB;

          // Limit sharpening to avoid noise halos
          final int enhancedR = (center.r + (diffR * sharpWeight).clamp(-16.0, 16.0)).round().clamp(0, 255);
          final int enhancedG = (center.g + (diffG * sharpWeight).clamp(-16.0, 16.0)).round().clamp(0, 255);
          final int enhancedB = (center.b + (diffB * sharpWeight).clamp(-16.0, 16.0)).round().clamp(0, 255);

          image.setPixelRgb(x, y, enhancedR, enhancedG, enhancedB);
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
