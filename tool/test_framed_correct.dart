import 'dart:io';
import 'package:image/image.dart' as img;

void main() async {
  final photoPath = 'C:\\Users\\ayush\\Downloads\\WhatsApp Image 2026-10-04 at 11.47.04 PM.jpeg';
  final bytes = await File(photoPath).readAsBytes();
  final rawDecoded = img.decodeImage(bytes)!;
  final oriented = img.bakeOrientation(rawDecoded);

  // Biometric crop:
  // x=0, y=94, w=576, h=576
  final cropped = img.copyCrop(oriented, x: 0, y: 94, width: 576, height: 576);
  final resized = img.copyResize(cropped, width: 600, height: 600);
  await File('C:\\Users\\ayush\\specpass\\test_correct_biometric_framed.jpg').writeAsBytes(img.encodeJpg(resized, quality: 98));
  print('Generated test_correct_biometric_framed.jpg successfully!');
}
