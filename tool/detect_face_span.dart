import 'dart:io';
import 'package:image/image.dart' as img;

void main() async {
  final photoPath = 'C:\\Users\\ayush\\Downloads\\WhatsApp Image 2026-10-04 at 11.47.04 PM.jpeg';
  final bytes = await File(photoPath).readAsBytes();
  final rawDecoded = img.decodeImage(bytes)!;
  final oriented = img.bakeOrientation(rawDecoded);

  // Find skin pixels and head bounding box
  int minX = oriented.width, maxX = 0;
  int minY = oriented.height, maxY = 0;
  int skinCount = 0;

  for (int y = 0; y < oriented.height; y++) {
    for (int x = 0; x < oriented.width; x++) {
      final p = oriented.getPixel(x, y);
      final r = p.r;
      final g = p.g;
      final b = p.b;

      // Skin detection via ITU-R BT.601 YCbCr
      if (r > 45 && g > 30 && b > 20 && r > g && g >= (b - 6)) {
        final double cb = 128 - 0.168736 * r - 0.331264 * g + 0.5 * b;
        final double cr = 128 + 0.5 * r - 0.418688 * g - 0.081312 * b;
        if (cb >= 70 && cb <= 140 && cr >= 135 && cr <= 180) {
          skinCount++;
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }
  }

  print('Detected Skin Region:');
  print('minY: $minY, maxY: $maxY');
  print('minX: $minX, maxX: $maxX');
  print('Face vertical span: $minY to $maxY (Height: ${maxY - minY} px)');
  print('Total image height: ${oriented.height}');
  print('Notice: Face is located around y=$minY to $maxY!');
}
