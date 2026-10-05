import 'dart:io';
import 'package:image/image.dart' as img;

void main() async {
  for (final path in [
    'C:\\Users\\ayush\\Downloads\\My photo.jpg',
    'C:\\Users\\ayush\\Desktop\\WhatsApp Image 2026-10-04 at 8.25.45 PM.jpeg',
    'C:\\Users\\ayush\\Downloads\\WhatsApp Image 2026-10-04 at 11.47.04 PM.jpeg',
  ]) {
    final file = File(path);
    if (!file.existsSync()) continue;
    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) continue;
    final oriented = img.bakeOrientation(decoded);
    print('$path: ${oriented.width} x ${oriented.height}, numChannels=${oriented.numChannels}');
  }
}
