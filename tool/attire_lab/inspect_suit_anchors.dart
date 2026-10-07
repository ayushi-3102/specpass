import 'dart:io';
import 'package:image/image.dart' as img;

void main() async {
  final attireDir = Directory('${Directory.current.path}/assets/attire');
  final pngFiles = attireDir.listSync().whereType<File>().where((f) => f.path.endsWith('.png') && !f.path.contains('_raw')).toList();

  print('Analyzing Suit Collar Anchors:');

  for (final file in pngFiles) {
    final bytes = await file.readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) continue;

    int minX = image.width, maxX = 0;
    int minY = image.height, maxY = 0;
    int collarApexY = -1;
    int collarApexX = image.width ~/ 2;

    // Find bounding box and first visible opaque collar pixel
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final p = image.getPixel(x, y);
        if (p.a > 30) {
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;

          if (collarApexY == -1 && (x - image.width / 2).abs() < image.width * 0.15) {
            collarApexY = y;
            collarApexX = x;
          }
        }
      }
    }

    final int visibleW = maxX - minX;
    final int visibleH = maxY - minY;
    final double collarRelY = (collarApexY - minY) / visibleH;

    print('-----------------------------------------');
    print('File: ${file.path.split(Platform.pathSeparator).last}');
    print('Image Dimensions: ${image.width} x ${image.height}');
    print('Visible Bounds: ($minX, $minY) to ($maxX, $maxY) [${visibleW}x${visibleH}]');
    print('Collar Apex: ($collarApexX, $collarApexY)');
    print('Collar Relative Y (from top of visible suit): ${(collarRelY * 100).toStringAsFixed(1)}% (minY=$minY px)');
  }
}
