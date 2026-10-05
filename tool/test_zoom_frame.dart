import 'dart:io';
import 'package:image/image.dart' as img;

void main() async {
  final photoPath = 'C:\\Users\\ayush\\Downloads\\My photo.jpg';
  final raw = img.decodeImage(await File(photoPath).readAsBytes())!;
  final oriented = img.bakeOrientation(raw);

  // Exact face in 3024x4032 image:
  // Head crown is around y=1380, chin is around y=1900.
  // Center is around x=1650.
  final int headHeight = 1900 - 1380; // 520 px
  final int targetH = (headHeight / 0.70).round(); // 742 px
  final int targetW = targetH; // 742 px

  final int cropY = (1380 - (targetH * 0.08).round()).clamp(0, oriented.height - targetH);
  final int cropX = (1650 - targetW ~/ 2).clamp(0, oriented.width - targetW);

  final cropped = img.copyCrop(oriented, x: cropX, y: cropY, width: targetW, height: targetH);
  final resized = img.copyResize(cropped, width: 600, height: 600);

  await File('C:\\Users\\ayush\\specpass\\test_zoomed_passport_portrait.jpg').writeAsBytes(img.encodeJpg(resized, quality: 95));
  print('Saved test_zoomed_passport_portrait.jpg successfully!');
}
