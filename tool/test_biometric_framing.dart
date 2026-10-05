import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;

void main() async {
  final photoPath = 'C:\\Users\\ayush\\Downloads\\WhatsApp Image 2026-10-04 at 11.47.04 PM.jpeg';
  final file = File(photoPath);
  if (!file.existsSync()) {
    print('Photo not found at $photoPath');
    return;
  }

  final bytes = await file.readAsBytes();
  final rawDecoded = img.decodeImage(bytes);
  if (rawDecoded == null) {
    print('Failed to decode image');
    return;
  }

  final oriented = img.bakeOrientation(rawDecoded);
  print('Oriented Image Dimensions: ${oriented.width} x ${oriented.height}');

  // Inspect center crop vs face-aware crop
  final int targetDpi = 300;
  final double widthMm = 51.0; // 2x2"
  final double heightMm = 51.0;
  final int targetW = ((widthMm / 25.4) * targetDpi).round();
  final int targetH = ((heightMm / 25.4) * targetDpi).round();

  print('Target dimensions for 2x2" @ 300 DPI: $targetW x $targetH');

  // Naive center crop (what was currently running):
  final double targetAspect = widthMm / heightMm;
  int naiveCropW = oriented.width;
  int naiveCropH = oriented.height;
  final double currentAspect = naiveCropW / naiveCropH;
  if (currentAspect > targetAspect) {
    naiveCropW = (naiveCropH * targetAspect).round();
  } else {
    naiveCropH = (naiveCropW / targetAspect).round();
  }
  final int naiveCropX = (oriented.width - naiveCropW) ~/ 2;
  final int naiveCropY = (oriented.height - naiveCropH) ~/ 2;

  print('NAIVE CENTER CROP: x=$naiveCropX, y=$naiveCropY, w=$naiveCropW, h=$naiveCropH');
  print('Notice: oriented.height is ${oriented.height}, naiveCropY starts at $naiveCropY and ends at ${naiveCropY + naiveCropH}!');
  print('If the face is in the top 30% of the phone photo, naive center crop cuts off the head or centers on the chest!');
}
