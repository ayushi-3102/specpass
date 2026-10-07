import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;

void main() async {
  final attireDir = Directory('${Directory.current.path}/assets/attire');
  final brainDir = Directory('C:\\Users\\ayush\\.gemini\\antigravity-cli\\brain\\b0f815fc-de42-4036-9750-2b4157b57998');

  // Copy any newly generated raw files from brainDir
  for (final file in brainDir.listSync().whereType<File>()) {
    if (file.path.contains('suit_') && file.path.endsWith('.jpg')) {
      final base = file.path.split(Platform.pathSeparator).last;
      final target = File('${attireDir.path}/$base');
      await file.copy(target.path);
      print('Copied raw artifact: $base');
    }
  }

  print('Cropping and extracting transparency with sub-pixel precision...');

  for (final file in attireDir.listSync().whereType<File>()) {
    if (!file.path.endsWith('.png') && !file.path.endsWith('.jpg')) continue;
    if (file.path.contains('_trimmed.')) continue;

    try {
      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) continue;

      img.Image processed;
      if (file.path.contains('_raw')) {
        processed = _extractChromaKeySuit(decoded);
      } else {
        processed = decoded;
      }

      // Trim empty transparent padding
      final trimmed = _trimToContent(processed);

      final cleanName = file.path
          .replaceAll('_raw', '')
          .replaceAll(RegExp(r'_\d+\.jpg'), '.png')
          .replaceAll('.jpg', '.png');

      final outPng = img.encodePng(trimmed);
      await File(cleanName).writeAsBytes(outPng);
      print('Optimized: $cleanName (${trimmed.width}x${trimmed.height})');
    } catch (e) {
      print('Error on ${file.path}: $e');
    }
  }

  print('Attire processing completed successfully.');
}

img.Image _trimToContent(img.Image src) {
  int minX = src.width, maxX = 0;
  int minY = src.height, maxY = 0;

  for (int y = 0; y < src.height; y++) {
    for (int x = 0; x < src.width; x++) {
      final p = src.getPixel(x, y);
      if (p.a > 30) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }

  if (minX >= maxX || minY >= maxY) return src;

  final w = maxX - minX + 1;
  final h = maxY - minY + 1;

  return img.copyCrop(src, x: minX, y: minY, width: w, height: h);
}

img.Image _extractChromaKeySuit(img.Image src) {
  final out = img.Image(width: src.width, height: src.height, numChannels: 4);

  for (int y = 0; y < src.height; y++) {
    for (int x = 0; x < src.width; x++) {
      final p = src.getPixel(x, y);
      final r = p.r.toDouble();
      final g = p.g.toDouble();
      final b = p.b.toDouble();

      final isGreenScreen = (g > 80 && g > r * 1.30 && g > b * 1.30);

      if (isGreenScreen) {
        out.setPixelRgba(x, y, 0, 0, 0, 0);
      } else {
        double cleanR = r;
        double cleanG = g;
        double cleanB = b;
        if (cleanG > math.max(cleanR, cleanB)) {
          cleanG = (cleanR + cleanB) / 2.0;
        }

        double alpha = 255.0;
        final greenDominance = g - math.max(r, b);
        if (greenDominance > 10) {
          alpha = (1.0 - (greenDominance - 10) / 40.0).clamp(0.0, 1.0) * 255.0;
        }

        out.setPixelRgba(x, y, cleanR.round(), cleanG.round(), cleanB.round(), alpha.round());
      }
    }
  }

  return out;
}
