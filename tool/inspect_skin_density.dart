import 'dart:io';
import 'package:image/image.dart' as img;

void main() async {
  final photoPath = 'C:\\Users\\ayush\\Downloads\\WhatsApp Image 2026-10-04 at 11.47.04 PM.jpeg';
  final bytes = await File(photoPath).readAsBytes();
  final rawDecoded = img.decodeImage(bytes)!;
  final oriented = img.bakeOrientation(rawDecoded);

  final origW = oriented.width;
  final origH = oriented.height;

  // Let's compute skin density per horizontal row (y from 0 to origH)
  List<int> skinPerRow = List.filled(origH, 0);

  for (int y = 0; y < origH; y++) {
    for (int x = 0; x < origW; x++) {
      final p = oriented.getPixel(x, y);
      final r = p.r;
      final g = p.g;
      final b = p.b;

      if (r > 60 && g > 40 && b > 25 && r > g && g >= b) {
        final double cb = 128 - 0.168736 * r - 0.331264 * g + 0.5 * b;
        final double cr = 128 + 0.5 * r - 0.418688 * g - 0.081312 * b;
        if (cb >= 85 && cb <= 135 && cr >= 140 && cr <= 175) {
          skinPerRow[y]++;
        }
      }
    }
  }

  print('Row-by-Row Skin Density (samples every 40px):');
  for (int y = 0; y < origH; y += 40) {
    print('y=$y: ${skinPerRow[y]} skin pixels');
  }
}
