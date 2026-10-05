import 'dart:io';
import 'package:image/image.dart' as img;

void main() async {
  final photoPath = 'C:\\Users\\ayush\\Downloads\\My photo.jpg';
  final bytes = await File(photoPath).readAsBytes();
  final raw = img.decodeImage(bytes)!;
  final oriented = img.bakeOrientation(raw);

  print('Original 12MP Image: ${oriented.width} x ${oriented.height}');

  // 1. Locate Face Centroid using ITU-R BT.601 skin chrominance cluster
  int skinCount = 0;
  double sumSkinX = 0, sumSkinY = 0;
  List<int> skinXs = [];
  List<int> skinYs = [];

  for (int y = 0; y < oriented.height; y += 4) {
    for (int x = 0; x < oriented.width; x += 4) {
      final p = oriented.getPixel(x, y);
      final r = p.r, g = p.g, b = p.b;

      if (r > 60 && g > 40 && b > 25 && r > g && g >= (b - 6)) {
        final double cb = 128 - 0.168736 * r - 0.331264 * g + 0.5 * b;
        final double cr = 128 + 0.5 * r - 0.418688 * g - 0.081312 * b;
        if (cb >= 80 && cb <= 135 && cr >= 138 && cr <= 175) {
          skinCount++;
          sumSkinX += x;
          sumSkinY += y;
          skinXs.add(x);
          skinYs.add(y);
        }
      }
    }
  }

  skinXs.sort();
  skinYs.sort();

  // Find dense cluster (face)
  final int faceCenterX = (sumSkinX / skinCount).round();
  final int faceCenterY = skinYs[(skinYs.length * 0.35).round()]; // upper skin cluster is face

  final int p10Y = skinYs[(skinYs.length * 0.05).round()];
  final int p60Y = skinYs[(skinYs.length * 0.60).round()];
  final int estFaceH = p60Y - p10Y;

  print('Detected Face Location: x=$faceCenterX, y=$faceCenterY, estHeight=$estFaceH px');

  // 2. Pre-crop to Upper Torso Portrait around the face
  // Target head height should be ~72% of total passport height
  final int targetPortraitH = (estFaceH * 1.5).round();
  final int targetPortraitW = targetPortraitH; // 1:1 square for US passport

  final int topMargin = (targetPortraitH * 0.12).round();
  final int cropY = (p10Y - topMargin).clamp(0, oriented.height - targetPortraitH);
  final int cropX = (faceCenterX - targetPortraitW ~/ 2).clamp(0, oriented.width - targetPortraitW);

  print('Portrait Pre-Crop: x=$cropX, y=$cropY, w=$targetPortraitW, h=$targetPortraitH');

  final portraitCropped = img.copyCrop(
    oriented,
    x: cropX,
    y: cropY,
    width: targetPortraitW,
    height: targetPortraitH,
  );

  final outPort = File('C:\\Users\\ayush\\specpass\\test_face_extracted_portrait.jpg');
  await outPort.writeAsBytes(img.encodeJpg(img.copyResize(portraitCropped, width: 600, height: 600), quality: 95));
  print('Saved test_face_extracted_portrait.jpg successfully!');
}
