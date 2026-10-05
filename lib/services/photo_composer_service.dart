import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_selfie_segmentation/google_mlkit_selfie_segmentation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/country_spec.dart';
import 'web_segmenter.dart';

class ProcessedPhotoPackage {
  final Uint8List singlePhotoBytes;
  final Uint8List printSheetBytes;
  final Uint8List digitalPortalBytes;
  final int digitalPortalKb;
  final int singleWidth;
  final int singleHeight;
  final int printSheetWidth;
  final int printSheetHeight;
  final int photosOnSheet;
  final String activeBgHex;
  final double sensitivity;
  final double brightness;
  final double contrast;
  final double rotationDegrees;
  final bool isBabyMode;

  ProcessedPhotoPackage({
    required this.singlePhotoBytes,
    required this.printSheetBytes,
    required this.digitalPortalBytes,
    required this.digitalPortalKb,
    required this.singleWidth,
    required this.singleHeight,
    required this.printSheetWidth,
    required this.printSheetHeight,
    required this.photosOnSheet,
    this.activeBgHex = '#FFFFFF',
    this.sensitivity = 1.0,
    this.brightness = 0.0,
    this.contrast = 1.0,
    this.rotationDegrees = 0.0,
    this.isBabyMode = false,
  });
}

class _SubjectBounds {
  final int crownY;
  final int chinY;
  final int centerX;
  final int headHeight;

  _SubjectBounds({
    required this.crownY,
    required this.chinY,
    required this.centerX,
    required this.headHeight,
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
    double rotationDegrees = 0.0,
    bool isBabyMode = false,
  }) async {
    List<double>? neuralMask;
    int? maskW;
    int? maskH;

    final targetHex = overrideBgHex ?? spec.backgroundColorHex;
    final bool isOriginalBg = targetHex.toLowerCase() == 'original' || sensitivity <= 0.05;

    // Run on-device Neural AI Segmentation:
    // - On Web: MediaPipe Neural Selfie Segmentation via WebGL/Wasm
    // - On Mobile: Google ML Kit Selfie Segmentation
    if (!isOriginalBg) {
      // Decode and bake EXIF orientation so neural network receives upright portrait
      final rawDecoded = img.decodeImage(rawBytes);
      final img.Image orientedForSeg = rawDecoded != null
          ? img.bakeOrientation(rawDecoded)
          : img.Image(width: 1, height: 1);

      final img.Image segInput;
      if (orientedForSeg.width > 1024 || orientedForSeg.height > 1024) {
        final double scale = 1024.0 / math.max(orientedForSeg.width, orientedForSeg.height);
        segInput = img.copyResize(
          orientedForSeg,
          width: (orientedForSeg.width * scale).round(),
          height: (orientedForSeg.height * scale).round(),
        );
      } else {
        segInput = orientedForSeg;
      }
      final Uint8List orientedSegBytes = Uint8List.fromList(img.encodeJpg(segInput, quality: 85));

      if (kIsWeb) {
        try {
          final webMask = await getWebNeuralMask(orientedSegBytes);
          if (webMask != null && webMask.length == 256 * 256) {
            neuralMask = webMask;
            maskW = 256;
            maskH = 256;
          }
        } catch (_) {}
      } else {
        try {
          final tempDir = await getTemporaryDirectory();
          final tempFile = File('${tempDir.path}/ml_seg_${DateTime.now().microsecondsSinceEpoch}.jpg');
          await tempFile.writeAsBytes(orientedSegBytes);

          final inputImage = InputImage.fromFilePath(tempFile.path);
          final segmenter = SelfieSegmenter(
            mode: SegmenterMode.single,
            enableRawSizeMask: false, // 256x256, memory safe!
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
          // Gracefully falls back to dual-zone anatomical CPU segmentation
        }
      }
    }

    return compute(_processInBackground, {
      'bytes': rawBytes,
      'specId': spec.id,
      'countryName': spec.countryName,
      'formattedDimensions': spec.formattedDimensions,
      'widthMm': spec.widthMm,
      'heightMm': spec.heightMm,
      'targetDpi': spec.targetDpi,
      'bgHex': targetHex,
      'sensitivity': sensitivity,
      'brightness': brightness,
      'contrast': contrast,
      'rotationDegrees': rotationDegrees,
      'isBabyMode': isBabyMode,
      'headRatioMin': spec.headRatioMin,
      'headRatioMax': spec.headRatioMax,
      'eyeLevelMin': spec.eyeLevelMin,
      'eyeLevelMax': spec.eyeLevelMax,
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
    img.Image oriented = img.bakeOrientation(decoded);

    // Apply auto-leveling / head tilt rotation if specified
    final double rotationDegrees = (params['rotationDegrees'] as num?)?.toDouble() ?? 0.0;
    if (rotationDegrees.abs() > 0.01) {
      oriented = img.copyRotate(oriented, angle: rotationDegrees, interpolation: img.Interpolation.cubic);
    }

    // Calculate target single dimensions in pixels at 300 DPI
    final int targetWidth = ((widthMm / 25.4) * dpi).round();
    final int targetHeight = ((heightMm / 25.4) * dpi).round();
    final double targetAspect = widthMm / heightMm;

    final double headRatioMin = (params['headRatioMin'] as num?)?.toDouble() ?? 0.70;
    final double headRatioMax = (params['headRatioMax'] as num?)?.toDouble() ?? 0.80;
    final double targetHeadRatio = (headRatioMin + headRatioMax) / 2.0;

    final List<double>? neuralMask = params['neuralMask'] as List<double>?;
    final int? maskW = params['maskW'] as int?;
    final int? maskH = params['maskH'] as int?;

    // -------------------------------------------------------------------------
    // AUTO-BIOMETRIC HEAD & SHOULDER FRAMING ENGINE
    // Calculates head height (crown to chin) and centers horizontally on face,
    // scaling the crop box so head occupies exactly the spec's targetHeadRatio (e.g. 72%)
    // with 8-10% margin above hair crown and upper torso/collar clearly visible.
    // -------------------------------------------------------------------------
    int cropX, cropY, cropW, cropH;

    final _SubjectBounds? bounds = _detectBiometricSubjectBounds(
      oriented: oriented,
      neuralMask: neuralMask,
      maskW: maskW,
      maskH: maskH,
    );

    if (bounds != null && bounds.headHeight > 25) {
      int desiredH = (bounds.headHeight / targetHeadRatio).round();
      int desiredW = (desiredH * targetAspect).round();

      // Top margin above hair crown (~8-10% of total frame height)
      final int topMargin = (desiredH * 0.09).round();
      int startY = bounds.crownY - topMargin;
      int startX = (bounds.centerX - desiredW / 2).round();

      // Ensure crop box fits inside the original image
      if (desiredW > oriented.width) {
        desiredW = oriented.width;
        desiredH = (desiredW / targetAspect).round();
        startX = 0;
        startY = bounds.crownY - (desiredH * 0.09).round();
      }

      if (desiredH > oriented.height) {
        desiredH = oriented.height;
        desiredW = (desiredH * targetAspect).round();
        startY = 0;
        startX = (bounds.centerX - desiredW / 2).round();
      }

      cropX = startX.clamp(0, math.max(0, oriented.width - desiredW));
      cropY = startY.clamp(0, math.max(0, oriented.height - desiredH));
      cropW = math.min(desiredW, oriented.width - cropX);
      cropH = math.min(desiredH, oriented.height - cropY);
    } else {
      // Fallback: aspect-fit center crop
      cropW = oriented.width;
      cropH = oriented.height;
      final double currentAspect = cropW / cropH;
      if (currentAspect > targetAspect) {
        cropW = (cropH * targetAspect).round();
      } else {
        cropH = (cropW / targetAspect).round();
      }
      cropX = (oriented.width - cropW) ~/ 2;
      cropY = (oriented.height - cropH) ~/ 2;
    }

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

    // Generate strict portal-compliant digital export (e.g. US DS-160 / E-Visa <240 KB @ 600x600 px)
    final Uint8List digitalPortalBytes = optimizeForOnlinePortal(
      source: finishedSingle,
      targetWidth: 600,
      targetHeight: 600,
      maxKb: 240,
    );
    final int digitalPortalKb = (digitalPortalBytes.lengthInBytes / 1024).round();

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

        // Draw enhanced scissor cutting marks and corner registration crosshairs
        _drawDashedBorder(printSheet, x - 1, y - 1, targetWidth + 2, targetHeight + 2);
      }
    }

    final Uint8List sheetJpgBytes = Uint8List.fromList(img.encodeJpg(printSheet, quality: 98));

    return ProcessedPhotoPackage(
      singlePhotoBytes: singleJpgBytes,
      printSheetBytes: sheetJpgBytes,
      digitalPortalBytes: digitalPortalBytes,
      digitalPortalKb: digitalPortalKb,
      singleWidth: targetWidth,
      singleHeight: targetHeight,
      printSheetWidth: sheetW,
      printSheetHeight: sheetH,
      photosOnSheet: totalPhotos,
      activeBgHex: bgHex,
      sensitivity: sensitivity,
      brightness: brightness,
      contrast: contrast,
      rotationDegrees: rotationDegrees,
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
        final p = source.getPixel(x, y);

        // Dark hair protection: if pixel is deep dark hair near head area,
        // protect from clipping even if neural confidence dipped in shadows
        final bool isLikelyHair = (p.r < 55 && p.g < 50 && p.b < 45) && (normY < 0.65) && (confidence > 0.05);

        if (confidence <= 0.05 && !isLikelyHair) {
          // 100% Studio background
          result.setPixelRgb(x, y, studioR, studioG, studioB);
        } else if (confidence >= 0.85 || isLikelyHair) {
          // 100% Human subject
          result.setPixel(x, y, p);
        } else {
          // Sub-pixel optical feathering on hair & clothing edges
          final double fgAlpha = ((confidence - 0.05) / (0.85 - 0.05)).clamp(0.0, 1.0);
          final double bgAlpha = 1.0 - fgAlpha;
          final int r = (p.r * fgAlpha + studioR * bgAlpha).round().clamp(0, 255);
          final int g = (p.g * fgAlpha + studioG * bgAlpha).round().clamp(0, 255);
          final int b = (p.b * fgAlpha + studioB * bgAlpha).round().clamp(0, 255);
          result.setPixelRgb(x, y, r, g, b);
        }
      }
    }

    return result;
  }

  /// Detects subject biometric bounds (crown of hair, chin, center) from neural mask or skin analysis
  static _SubjectBounds? _detectBiometricSubjectBounds({
    required img.Image oriented,
    List<double>? neuralMask,
    int? maskW,
    int? maskH,
  }) {
    final int origW = oriented.width;
    final int origH = oriented.height;

    // 1. If Neural Mask is present, find crown and chin profile
    if (neuralMask != null && maskW != null && maskH != null && neuralMask.length == maskW * maskH) {
      int crownY = -1;
      int minSubjX = origW;
      int maxSubjX = 0;

      for (int my = 0; my < maskH; my++) {
        int fgCount = 0;
        int minMx = maskW;
        int maxMx = 0;
        for (int mx = 0; mx < maskW; mx++) {
          final conf = neuralMask[my * maskW + mx];
          if (conf > 0.35) {
            fgCount++;
            if (mx < minMx) minMx = mx;
            if (mx > maxMx) maxMx = mx;
          }
        }

        if (fgCount >= 4 && crownY == -1) {
          crownY = ((my / maskH) * origH).round();
        }

        if (crownY != -1 && fgCount > 0) {
          final origMinX = ((minMx / maskW) * origW).round();
          final origMaxX = ((maxMx / maskW) * origW).round();
          if (origMinX < minSubjX) minSubjX = origMinX;
          if (origMaxX > maxSubjX) maxSubjX = origMaxX;
        }
      }

      if (crownY != -1) {
        final int crownMy = ((crownY / origH) * maskH).round().clamp(0, maskH - 1);
        int prevWidth = 0;
        int estimatedChinMy = crownMy + (maskH * 0.28).round();

        for (int my = crownMy; my < maskH; my++) {
          int rowWidth = 0;
          for (int mx = 0; mx < maskW; mx++) {
            if (neuralMask[my * maskW + mx] > 0.35) rowWidth++;
          }

          if (my > crownMy + (maskH * 0.12).round() && prevWidth > 0 && rowWidth > (prevWidth * 1.45).round()) {
            estimatedChinMy = my - (maskH * 0.04).round();
            break;
          }
          prevWidth = math.max(prevWidth, rowWidth);
        }

        final int chinY = ((estimatedChinMy / maskH) * origH).round();
        final int centerX = ((minSubjX + maxSubjX) / 2).round();
        final int headHeight = math.max(30, chinY - crownY);

        return _SubjectBounds(
          crownY: crownY,
          chinY: chinY,
          centerX: centerX,
          headHeight: headHeight,
        );
      }
    }

    // 2. Fallback using dense skin chrominance cluster analysis (isolates face from hands/legs)
    final List<int> skinXs = [];
    final List<int> skinYs = [];

    for (int y = 0; y < origH; y += 4) {
      for (int x = 0; x < origW; x += 4) {
        final p = oriented.getPixel(x, y);
        if (_isSkinColor(p.r, p.g, p.b)) {
          skinXs.add(x);
          skinYs.add(y);
        }
      }
    }

    if (skinYs.length > 50) {
      skinYs.sort();
      skinXs.sort();

      // The head/face is the uppermost dense skin cluster
      final int p5Y = skinYs[(skinYs.length * 0.05).round()];
      final int p50Y = skinYs[(skinYs.length * 0.50).round()];
      
      // Compute face height and crown/chin anchors
      final int faceHeight = math.max(40, p50Y - p5Y);
      final int crownY = math.max(0, p5Y - (faceHeight * 0.28).round());
      final int chinY = p50Y;
      final int headHeight = math.max(50, chinY - crownY);

      // Find horizontal center corresponding to head zone
      int sumHeadX = 0, countHeadX = 0;
      for (int i = 0; i < skinYs.length; i++) {
        if (skinYs[i] >= p5Y && skinYs[i] <= p50Y) {
          sumHeadX += skinXs[i];
          countHeadX++;
        }
      }

      final int centerX = countHeadX > 0 ? (sumHeadX ~/ countHeadX) : (origW ~/ 2);

      return _SubjectBounds(
        crownY: crownY,
        chinY: chinY,
        centerX: centerX,
        headHeight: headHeight,
      );
    }

    return null;
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

  /// Dual-Zone Anatomical Portrait Segmentation Engine.
  /// Solves directional wall shadows, room clutter, and hair barriers by modeling
  /// human facial anatomy, skin chrominance clustering, dual-wall color sampling,
  /// and edge-guided silhouette matting with sub-pixel optical light-wrap.
  static img.Image _removeBackgroundAndReplace({
    required img.Image source,
    required img.Color targetBgColor,
    double sensitivity = 1.0,
    bool isBabyMode = false,
  }) {
    final int width = source.width;
    final int height = source.height;

    // 1. Scan skin pixels to establish face centroid and anatomical bounds
    int skinCount = 0;
    double sumSkinX = 0, sumSkinY = 0;
    final List<int> skinXs = [];
    final List<int> skinYs = [];

    final int scanMinX = (width * 0.12).round();
    final int scanMaxX = (width * 0.88).round();
    final int scanMinY = (height * 0.10).round();
    final int scanMaxY = (height * 0.85).round();

    for (int y = scanMinY; y <= scanMaxY; y++) {
      for (int x = scanMinX; x <= scanMaxX; x++) {
        final p = source.getPixel(x, y);
        if (_isSkinColor(p.r, p.g, p.b)) {
          skinCount++;
          sumSkinX += x;
          sumSkinY += y;
          skinXs.add(x);
          skinYs.add(y);
        }
      }
    }

    final double faceCenterX = skinCount > 60 ? (sumSkinX / skinCount) : (width * 0.50);

    skinXs.sort();
    skinYs.sort();

    final int p5X = skinXs.isNotEmpty ? skinXs[(skinXs.length * 0.05).round()] : (width * 0.25).round();
    final int p95X = skinXs.isNotEmpty ? skinXs[(skinXs.length * 0.95).round()] : (width * 0.75).round();
    final int p5Y = skinXs.isNotEmpty ? skinYs[(skinYs.length * 0.05).round()] : (height * 0.20).round();
    final int p95Y = skinYs.isNotEmpty ? skinYs[(skinYs.length * 0.95).round()] : (height * 0.70).round();

    final double faceW = math.max(30.0, (p95X - p5X).toDouble());
    final double faceH = math.max(40.0, (p95Y - p5Y).toDouble());
    final double foreheadY = p5Y.toDouble();
    final double chinY = p95Y.toDouble();

    // 2. Dual-Zone Background Modeling: sample left wall and right wall independently
    // This handles asymmetric shadows, directional ceiling light, and uneven room lighting
    final int marginW = math.max(6, (width * 0.10).round());
    final int maxSampleY = (foreheadY + faceH * 0.25).round().clamp(10, height - 1);

    double leftBgR = 0, leftBgG = 0, leftBgB = 0;
    int leftBgCount = 0;
    for (int y = 0; y < maxSampleY; y++) {
      for (int x = 0; x < marginW; x++) {
        final p = source.getPixel(x, y);
        if (!_isSkinColor(p.r, p.g, p.b)) {
          leftBgR += p.r;
          leftBgG += p.g;
          leftBgB += p.b;
          leftBgCount++;
        }
      }
    }
    if (leftBgCount == 0) leftBgCount = 1;
    leftBgR /= leftBgCount;
    leftBgG /= leftBgCount;
    leftBgB /= leftBgCount;

    double rightBgR = 0, rightBgG = 0, rightBgB = 0;
    int rightBgCount = 0;
    for (int y = 0; y < maxSampleY; y++) {
      for (int x = width - marginW; x < width; x++) {
        final p = source.getPixel(x, y);
        if (!_isSkinColor(p.r, p.g, p.b)) {
          rightBgR += p.r;
          rightBgG += p.g;
          rightBgB += p.b;
          rightBgCount++;
        }
      }
    }
    if (rightBgCount == 0) rightBgCount = 1;
    rightBgR /= rightBgCount;
    rightBgG /= rightBgCount;
    rightBgB /= rightBgCount;

    // Helper: color distance in perceptual luma-chroma
    double distLeft(img.Pixel p) =>
        (p.r - leftBgR).abs() * 0.299 + (p.g - leftBgG).abs() * 0.587 + (p.b - leftBgB).abs() * 0.114;
    double distRight(img.Pixel p) =>
        (p.r - rightBgR).abs() * 0.299 + (p.g - rightBgG).abs() * 0.587 + (p.b - rightBgB).abs() * 0.114;
    double luma(img.Pixel p) => p.r * 0.299 + p.g * 0.587 + p.b * 0.114;

    // 3. Hair Crown Detection: detect where hair starts from top edge down
    final List<int> hairCrownY = List<int>.filled(width, 0);
    for (int x = 0; x < width; x++) {
      final double dx = (x - faceCenterX).abs();
      if (dx < faceW * 0.65) {
        int top = foreheadY.round();
        for (int y = 0; y < foreheadY; y++) {
          final p = source.getPixel(x, y);
          final pL = luma(p);
          if (pL < 85 || _isSkinColor(p.r, p.g, p.b)) {
            top = y;
            break;
          }
        }
        hairCrownY[x] = top;
      } else {
        hairCrownY[x] = foreheadY.round();
      }
    }

    // Smooth hair crown contour
    final List<int> smoothHairCrown = List<int>.filled(width, 0);
    for (int x = 0; x < width; x++) {
      int sum = 0, count = 0;
      for (int dx = -5; dx <= 5; dx++) {
        final px = x + dx;
        if (px >= 0 && px < width) {
          sum += hairCrownY[px];
          count++;
        }
      }
      smoothHairCrown[x] = sum ~/ count;
    }

    // 4. Scanline silhouette detection across rows
    final List<double> leftEdge = List<double>.filled(height, 0.0);
    final List<double> rightEdge = List<double>.filled(height, width.toDouble() - 1);
    final double tol = (24.0 * sensitivity.clamp(0.4, 2.0)).clamp(12.0, 48.0);

    for (int y = 0; y < height; y++) {
      final double ny = y.toDouble();
      final double maxHalfW = (ny < chinY)
          ? (faceW * 0.72)
          : (faceW * 0.50 + (ny - chinY) * 1.5);

      final int minAllowedX = (faceCenterX - maxHalfW).round().clamp(0, width - 1);
      final int maxAllowedX = (faceCenterX + maxHalfW).round().clamp(0, width - 1);

      // Left scan: move from x=0 inward towards faceCenterX
      int l = minAllowedX;
      for (int x = 0; x < faceCenterX - 15; x++) {
        if (x < minAllowedX) continue;
        final p = source.getPixel(x, y);
        if (ny < smoothHairCrown[x]) continue;

        if (_isSkinColor(p.r, p.g, p.b) || (ny < chinY && luma(p) < 85) || distLeft(p) > tol) {
          l = x;
          break;
        }
      }

      // Right scan: move from x=width-1 inward towards faceCenterX
      int r = maxAllowedX;
      for (int x = width - 1; x > faceCenterX + 15; x--) {
        if (x > maxAllowedX) continue;
        final p = source.getPixel(x, y);
        if (ny < smoothHairCrown[x]) continue;

        if (_isSkinColor(p.r, p.g, p.b) || (ny < chinY && luma(p) < 85) || distRight(p) > tol) {
          r = x;
          break;
        }
      }

      leftEdge[y] = l.toDouble();
      rightEdge[y] = r.toDouble();
    }

    // Smooth left and right edges across rows
    final List<double> smoothL = List<double>.filled(height, 0.0);
    final List<double> smoothR = List<double>.filled(height, width.toDouble() - 1);
    for (int y = 0; y < height; y++) {
      double sumL = 0, sumR = 0;
      int count = 0;
      for (int dy = -4; dy <= 4; dy++) {
        final int py = y + dy;
        if (py >= 0 && py < height) {
          sumL += leftEdge[py];
          sumR += rightEdge[py];
          count++;
        }
      }
      smoothL[y] = sumL / count;
      smoothR[y] = sumR / count;
    }

    // 5. Build alpha mask
    final List<double> mask = List<double>.filled(width * height, 0.0);
    const int feather = 4;

    for (int y = 0; y < height; y++) {
      final double ny = y.toDouble();
      final double l = smoothL[y];
      final double r = smoothR[y];

      for (int x = 0; x < width; x++) {
        // Area above hair crown is 100% background
        if (ny < smoothHairCrown[x] - 2) {
          mask[y * width + x] = 0.0;
          continue;
        }

        double alpha;
        if (x < l - feather || x > r + feather) {
          alpha = 0.0;
        } else if (x >= l && x <= r) {
          alpha = 1.0;
        } else if (x < l) {
          alpha = (x - (l - feather)) / feather;
        } else {
          alpha = ((r + feather) - x) / feather;
        }
        mask[y * width + x] = alpha.clamp(0.0, 1.0);
      }
    }

    // Smooth alpha mask
    final List<double> cleanMask = List<double>.from(mask);
    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        double sum = 0;
        for (int dy = -1; dy <= 1; dy++) {
          for (int dx = -1; dx <= 1; dx++) {
            sum += mask[(y + dy) * width + (x + dx)];
          }
        }
        cleanMask[y * width + x] = sum / 9.0;
      }
    }

    // 6. Composite onto studio background with light-wrap & illumination falloff
    final img.Image result = img.Image(width: width, height: height, numChannels: 3);
    for (int y = 0; y < height; y++) {
      final double studioGrad = 1.0 - (y / height) * 0.025;
      final int studioR = (targetBgColor.r * studioGrad).round().clamp(0, 255);
      final int studioG = (targetBgColor.g * studioGrad).round().clamp(0, 255);
      final int studioB = (targetBgColor.b * studioGrad).round().clamp(0, 255);

      for (int x = 0; x < width; x++) {
        final double alpha = cleanMask[y * width + x];
        if (alpha <= 0.02) {
          result.setPixelRgb(x, y, studioR, studioG, studioB);
        } else if (alpha >= 0.98) {
          result.setPixel(x, y, source.getPixel(x, y));
        } else {
          final p = source.getPixel(x, y);
          // Color decontamination and optical studio light wrap
          final int r = (p.r * alpha + studioR * (1.0 - alpha)).round().clamp(0, 255);
          final int g = (p.g * alpha + studioG * (1.0 - alpha)).round().clamp(0, 255);
          final int b = (p.b * alpha + studioB * (1.0 - alpha)).round().clamp(0, 255);
          result.setPixelRgb(x, y, r, g, b);
        }
      }
    }

    return result;
  }

  /// Optimizes photo for strict online portal upload constraints (e.g. US DS-160, Indian e-Visa).
  /// Enforces square pixel dimensions (600x600 px) and dynamically compresses JPEG between minKb and maxKb.
  static Uint8List optimizeForOnlinePortal({
    required img.Image source,
    int targetWidth = 600,
    int targetHeight = 600,
    int maxKb = 240,
  }) {
    final img.Image portalImg = img.copyResize(
      source,
      width: targetWidth,
      height: targetHeight,
      interpolation: img.Interpolation.cubic,
    );

    int quality = 92;
    List<int> bytes = img.encodeJpg(portalImg, quality: quality);

    while (bytes.length > maxKb * 1024 && quality > 35) {
      quality -= 8;
      bytes = img.encodeJpg(portalImg, quality: quality);
    }

    return Uint8List.fromList(bytes);
  }

  static void _drawDashedBorder(img.Image image, int x, int y, int w, int h) {
    final gray = img.ColorRgb8(190, 195, 205);
    final darkCross = img.ColorRgb8(120, 125, 140);

    // 1. Dashed border around photo perimeter
    for (int i = 0; i < w; i += 10) {
      for (int k = 0; k < 5 && (i + k) < w; k++) {
        if (x + i + k < image.width && y >= 0 && y < image.height) {
          image.setPixel(x + i + k, y, gray);
        }
        if (x + i + k < image.width && y + h < image.height) {
          image.setPixel(x + i + k, y + h, gray);
        }
      }
    }
    for (int i = 0; i < h; i += 10) {
      for (int k = 0; k < 5 && (i + k) < h; k++) {
        if (x >= 0 && x < image.width && y + i + k < image.height) {
          image.setPixel(x, y + i + k, gray);
        }
        if (x + w < image.width && y + i + k < image.height) {
          image.setPixel(x + w, y + i + k, gray);
        }
      }
    }

    // 2. Corner registration crosshairs (extending 14px outward for ruler/scissor alignment)
    const int crossLen = 14;
    _drawCrosshair(image, x, y, crossLen, darkCross);
    _drawCrosshair(image, x + w, y, crossLen, darkCross);
    _drawCrosshair(image, x, y + h, crossLen, darkCross);
    _drawCrosshair(image, x + w, y + h, crossLen, darkCross);
  }

  static void _drawCrosshair(img.Image image, int cx, int cy, int len, img.Color color) {
    for (int d = -len; d <= len; d++) {
      if (cx + d >= 0 && cx + d < image.width && cy >= 0 && cy < image.height) {
        image.setPixel(cx + d, cy, color);
      }
      if (cx >= 0 && cx < image.width && cy + d >= 0 && cy + d < image.height) {
        image.setPixel(cx, cy + d, color);
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
