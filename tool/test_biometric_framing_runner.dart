import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;

void main() async {
  final photoPath = 'C:\\Users\\ayush\\Downloads\\WhatsApp Image 2026-10-04 at 11.47.04 PM.jpeg';
  final bytes = await File(photoPath).readAsBytes();
  final rawDecoded = img.decodeImage(bytes)!;
  final oriented = img.bakeOrientation(rawDecoded);
  print('Original Dimensions: ${oriented.width} x ${oriented.height}');

  final origW = oriented.width;
  final origH = oriented.height;

  // Skin cluster detection
  int skinMinX = origW, skinMaxX = 0;
  int skinMinY = origH, skinMaxY = 0;
  int skinCount = 0;

  for (int y = 0; y < origH; y++) {
    for (int x = 0; x < origW; x++) {
      final p = oriented.getPixel(x, y);
      final r = p.r;
      final g = p.g;
      final b = p.b;

      if (r > 45 && g > 30 && b > 20 && r > g && g >= (b - 6)) {
        final double cb = 128 - 0.168736 * r - 0.331264 * g + 0.5 * b;
        final double cr = 128 + 0.5 * r - 0.418688 * g - 0.081312 * b;
        if (cb >= 70 && cb <= 140 && cr >= 135 && cr <= 180) {
          skinCount++;
          if (x < skinMinX) skinMinX = x;
          if (x > skinMaxX) skinMaxX = x;
          if (y < skinMinY) skinMinY = y;
          if (y > skinMaxY) skinMaxY = y;
        }
      }
    }
  }

  print('Skin bounds: x=[$skinMinX, $skinMaxX], y=[$skinMinY, $skinMaxY]');
  final int faceH = skinMaxY - skinMinY;
  print('Face height: $faceH px');

  // Hair crown is above skinMinY
  final int crownY = math.max(0, skinMinY - (faceH * 0.22).round());
  final int chinY = skinMaxY;
  final int headHeight = chinY - crownY;
  final int centerX = (skinMinX + skinMaxX) ~/ 2;

  print('Calculated Head: Crown=$crownY, Chin=$chinY, HeadHeight=$headHeight, CenterX=$centerX');

  // Test US Passport (Aspect 1:1, target head ratio 0.62)
  final double targetAspect = 1.0;
  final double targetHeadRatio = 0.62;

  final int desiredH = (headHeight / targetHeadRatio).round();
  final int desiredW = (desiredH * targetAspect).round();
  final int topMargin = (desiredH * 0.09).round();
  final int startY = crownY - topMargin;
  final int startX = (centerX - desiredW / 2).round();

  print('Target Crop: x=$startX, y=$startY, w=$desiredW, h=$desiredH');

  final int cropX = startX.clamp(0, math.max(0, origW - desiredW));
  final int cropY = startY.clamp(0, math.max(0, origH - desiredH));
  final int cropW = math.min(desiredW, origW - cropX);
  final int cropH = math.min(desiredH, origH - cropY);

  print('Clamped Crop: x=$cropX, y=$cropY, w=$cropW, h=$cropH');

  // Generate cropped image and save to disk
  final cropped = img.copyCrop(oriented, x: cropX, y: cropY, width: cropW, height: cropH);
  final resized = img.copyResize(cropped, width: 600, height: 600);
  await File('C:\\Users\\ayush\\specpass\\test_framed_output.jpg').writeAsBytes(img.encodeJpg(resized, quality: 95));
  print('Saved test_framed_output.jpg successfully!');
}
