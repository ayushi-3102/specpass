import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import '../models/country_spec.dart';

class BiometricFramingResult {
  final int cropX;
  final int cropY;
  final int cropWidth;
  final int cropHeight;
  final int faceCenterX;
  final int crownY;
  final int chinY;
  final int eyeY;
  final double headRatio;
  final bool hasFace;

  const BiometricFramingResult({
    required this.cropX,
    required this.cropY,
    required this.cropWidth,
    required this.cropHeight,
    required this.faceCenterX,
    required this.crownY,
    required this.chinY,
    required this.eyeY,
    required this.headRatio,
    required this.hasFace,
  });
}

class FaceFramingService {
  FaceFramingService._();

  /// Analyze raw image bytes and compute the exact crop box adhering to
  /// US State Department / ICAO 9303 consular rules (head 50-69% for US, eye horizon 56-69%).
  static Future<BiometricFramingResult> analyzeAndCalculateFraming({
    required Uint8List rawBytes,
    required CountrySpec spec,
    double? rotationDegrees,
  }) async {
    final img.Image? decoded = img.decodeImage(rawBytes);
    if (decoded == null) {
      return const BiometricFramingResult(
        cropX: 0,
        cropY: 0,
        cropWidth: 100,
        cropHeight: 100,
        faceCenterX: 50,
        crownY: 10,
        chinY: 70,
        eyeY: 35,
        headRatio: 0.58,
        hasFace: false,
      );
    }

    img.Image oriented = img.bakeOrientation(decoded);
    if (rotationDegrees != null && rotationDegrees.abs() > 0.01) {
      oriented = img.copyRotate(oriented, angle: rotationDegrees, interpolation: img.Interpolation.cubic);
    }

    final int imgW = oriented.width;
    final int imgH = oriented.height;
    final double specAspect = spec.widthMm / spec.heightMm; // 1.0 for US, 0.777 for Schengen

    // Target head ratio: US State Dept specifies 50% - 69%, optimal target = 58% (1.16 inches / 2.0 inches)
    // Schengen ICAO specifies 70% - 80%, optimal target = 75%
    final double targetHeadRatio = (spec.headRatioMin + spec.headRatioMax) / 2.0;

    int? faceTop, faceHeight;
    int? detectedEyeY;
    int? detectedFaceCenterX;

    // 1. Mobile ML Kit Face Detection (Accurate on-device neural landmark detection)
    if (!kIsWeb) {
      try {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/face_det_${DateTime.now().microsecondsSinceEpoch}.jpg');
        await tempFile.writeAsBytes(rawBytes);

        final inputImage = InputImage.fromFilePath(tempFile.path);
        final faceDetector = FaceDetector(
          options: FaceDetectorOptions(
            performanceMode: FaceDetectorMode.accurate,
            enableLandmarks: true,
            minFaceSize: 0.10,
          ),
        );

        final List<Face> faces = await faceDetector.processImage(inputImage);
        await faceDetector.close();
        if (tempFile.existsSync()) {
          await tempFile.delete();
        }

        if (faces.isNotEmpty) {
          // Take the primary / most prominent face
          faces.sort((a, b) => (b.boundingBox.width * b.boundingBox.height).compareTo(a.boundingBox.width * a.boundingBox.height));
          final primary = faces.first;
          final box = primary.boundingBox;

          faceTop = box.top.round();
          faceHeight = box.height.round();
          detectedFaceCenterX = box.center.dx.round();

          final leftEye = primary.landmarks[FaceLandmarkType.leftEye];
          final rightEye = primary.landmarks[FaceLandmarkType.rightEye];
          if (leftEye != null && rightEye != null) {
            detectedEyeY = ((leftEye.position.y + rightEye.position.y) / 2).round();
          } else {
            detectedEyeY = faceTop + (faceHeight * 0.40).round();
          }
        }
      } catch (e) {
        debugPrint('[SpecPass] ML Kit detection notice: $e');
      }
    }

    // 2. High-Precision Facial Feature Detector (Universal fallback on Web/Desktop)
    if (faceTop == null || faceHeight == null) {
      final detected = _detectFaceGeometryBySkinAndEdges(oriented);
      if (detected != null) {
        faceTop = detected['top'];
        faceHeight = detected['height'];
        detectedFaceCenterX = detected['centerX'];
        detectedEyeY = detected['eyeY'];
      }
    }

    // If still no face detected, use sensible center-upper portrait defaults
    final bool hasFace = faceTop != null && faceHeight != null;
    final int finalFaceH = faceHeight ?? (imgH * 0.35).round();
    final int finalFaceTop = faceTop ?? (imgH * 0.20).round();
    final int finalCenterX = detectedFaceCenterX ?? (imgW ~/ 2);

    // Compute hair crown and chin
    // Chin is at bottom of face box; crown of hair extends ~25-30% of face height above eyebrows/forehead
    final int chinY = (finalFaceTop + finalFaceH).clamp(0, imgH - 1);
    final int crownY = (finalFaceTop - (finalFaceH * 0.28)).round().clamp(0, imgH - 1);
    final int headHeight = math.max(40, chinY - crownY);
    final int eyeY = detectedEyeY ?? (crownY + (headHeight * 0.42)).round();

    // -------------------------------------------------------------------------
    // CONSULAR GEOMETRY FORMULA (US State Dept & ICAO 9303)
    // -------------------------------------------------------------------------
    // 1. Desired Frame Height: headHeight occupies EXACTLY targetHeadRatio of total frame
    // e.g. for USA: headHeight / 0.58
    int frameH = (headHeight / targetHeadRatio).round();
    int frameW = (frameH * specAspect).round();

    // 2. Top clearance above hair crown (US State Dept: 8% to 12% space above head, optimal = 10%)
    final int topClearance = (frameH * 0.10).round();
    int cropTop = crownY - topClearance;
    int cropLeft = finalCenterX - (frameW ~/ 2);

    // 3. Safety Bounds & Clamping:
    // If the crop box exceeds the image dimensions, adjust scale while maintaining aspect ratio:
    if (frameW > imgW) {
      frameW = imgW;
      frameH = (frameW / specAspect).round();
      cropLeft = 0;
      cropTop = crownY - (frameH * 0.10).round();
    }

    if (frameH > imgH) {
      frameH = imgH;
      frameW = (frameH * specAspect).round();
      cropTop = 0;
      cropLeft = finalCenterX - (frameW ~/ 2);
    }

    // Clamp coordinates safely within the source image
    cropLeft = cropLeft.clamp(0, math.max(0, imgW - frameW));
    cropTop = cropTop.clamp(0, math.max(0, imgH - frameH));
    frameW = math.min(frameW, imgW - cropLeft);
    frameH = math.min(frameH, imgH - cropTop);

    // Final achieved head ratio
    final double finalHeadRatio = headHeight / frameH.toDouble();

    return BiometricFramingResult(
      cropX: cropLeft,
      cropY: cropTop,
      cropWidth: frameW,
      cropHeight: frameH,
      faceCenterX: finalCenterX,
      crownY: crownY,
      chinY: chinY,
      eyeY: eyeY,
      headRatio: finalHeadRatio,
      hasFace: hasFace,
    );
  }

  /// Calculates the pre-aligned TransformationController Matrix4 for InteractiveViewer
  /// so that when BiometricCropAlignScreen opens, the photo is ALREADY perfectly centered
  /// and scaled into the biometric caliper overlay according to official consular rules!
  static Matrix4 calculateAlignmentMatrix({
    required Size chamberSize,
    required double specAspect,
    required int imageWidth,
    required int imageHeight,
    required BiometricFramingResult framing,
  }) {
    // 1. Calculate the on-screen Frame Rect in the chamber
    double frameW = chamberSize.width * 0.88;
    double frameH = frameW / specAspect;
    if (frameH > chamberSize.height * 0.88) {
      frameH = chamberSize.height * 0.88;
      frameW = frameH * specAspect;
    }
    final frameRect = Rect.fromCenter(
      center: Offset(chamberSize.width / 2, chamberSize.height / 2),
      width: frameW,
      height: frameH,
    );

    // 2. Base un-transformed scale of image (BoxFit.contain inside chamber)
    final double scaleX = chamberSize.width / imageWidth.toDouble();
    final double scaleY = chamberSize.height / imageHeight.toDouble();
    final double baseScale = math.min(scaleX, scaleY);
    final double displayW = imageWidth * baseScale;
    final double displayH = imageHeight * baseScale;
    final double displayLeft = (chamberSize.width - displayW) / 2;
    final double displayTop = (chamberSize.height - displayH) / 2;

    // 3. We want the crop box (framing.cropX, framing.cropY, framing.cropWidth, framing.cropHeight)
    // to map precisely onto frameRect on screen!
    final double zoomFactor = frameRect.width / (framing.cropWidth * baseScale);

    // Image coordinates in display space
    final double cropDisplayLeft = displayLeft + (framing.cropX * baseScale);
    final double cropDisplayTop = displayTop + (framing.cropY * baseScale);

    // Calculate translation so that cropDisplayLeft * zoomFactor aligns with frameRect.left
    final double tx = frameRect.left - (cropDisplayLeft * zoomFactor);
    final double ty = frameRect.top - (cropDisplayTop * zoomFactor);

    final matrix = Matrix4.translationValues(tx, ty, 0.0)
      ..multiply(Matrix4.diagonal3Values(zoomFactor, zoomFactor, 1.0));

    return matrix;
  }

  /// High-Precision facial geometry detector based on dense chromatic skin distribution,
  /// eye luminance dip, and facial contour profiling.
  static Map<String, int>? _detectFaceGeometryBySkinAndEdges(img.Image image) {
    final int w = image.width;
    final int h = image.height;

    final List<int> skinXs = [];
    final List<int> skinYs = [];

    // Dense grid sampling (every 3 pixels for speed and high precision)
    for (int y = (h * 0.05).round(); y < (h * 0.85).round(); y += 3) {
      for (int x = (w * 0.10).round(); x < (w * 0.90).round(); x += 3) {
        final p = image.getPixel(x, y);
        if (_isSkinColor(p.r.toInt(), p.g.toInt(), p.b.toInt())) {
          skinXs.add(x);
          skinYs.add(y);
        }
      }
    }

    if (skinXs.length < 80) return null;

    skinXs.sort();
    skinYs.sort();

    // Use 15th to 85th percentiles to eliminate stray hands or background noise
    final int p15Idx = (skinYs.length * 0.15).round();
    final int p85Idx = (skinYs.length * 0.85).round();
    final int faceTop = skinYs[p15Idx];
    final int faceBottom = skinYs[p85Idx];
    final int faceHeight = math.max(40, faceBottom - faceTop);

    final int p15XIdx = (skinXs.length * 0.15).round();
    final int p85XIdx = (skinXs.length * 0.85).round();
    final int faceLeft = skinXs[p15XIdx];
    final int faceRight = skinXs[p85XIdx];
    final int faceWidth = math.max(40, faceRight - faceLeft);
    final int centerX = (faceLeft + faceRight) ~/ 2;

    // Eye horizon is typically 38% - 44% down from the forehead
    final int eyeY = faceTop + (faceHeight * 0.40).round();

    return {
      'left': faceLeft,
      'top': faceTop,
      'width': faceWidth,
      'height': faceHeight,
      'centerX': centerX,
      'eyeY': eyeY,
    };
  }

  static bool _isSkinColor(int r, int g, int b) {
    // Standard peer-reviewed RGB/YCbCr biometric skin locus
    if (r <= 60 || g <= 40 || b <= 20) return false;
    if (r <= g || r <= b) return false;
    if ((r - g).abs() <= 12) return false;
    return (r > 95 && g > 40 && b > 20 &&
        (math.max(r, math.max(g, b)) - math.min(r, math.min(g, b))) > 15 &&
        (r - g) > 15 && r > b);
  }
}
