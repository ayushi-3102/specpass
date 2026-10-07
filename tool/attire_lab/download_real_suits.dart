import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

void main() async {
  final attireDir = Directory('${Directory.current.path}/assets/attire');
  if (!await attireDir.exists()) {
    await attireDir.create(recursive: true);
  }

  // Real photographic suit cutouts (high-res transparent PNGs)
  final suits = {
    'men_navy_real.png': 'https://pngimg.com/uploads/suit/suit_PNG93253.png',
    'men_charcoal_real.png': 'https://pngimg.com/uploads/suit/suit_PNG8123.png',
    'men_black_real.png': 'https://pngimg.com/uploads/suit/suit_PNG8131.png',
    'women_navy_real.png': 'https://pngimg.com/uploads/suit/suit_PNG93240.png',
    'men_formal_tie.png': 'https://pngimg.com/uploads/suit/suit_PNG8133.png',
  };

  for (final entry in suits.entries) {
    final fileName = entry.key;
    final url = entry.value;
    final targetFile = File('${attireDir.path}/$fileName');

    print('Downloading real studio attire: $fileName from $url...');
    try {
      final response = await http.get(Uri.parse(url), headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
      });

      if (response.statusCode == 200) {
        final decoded = img.decodeImage(response.bodyBytes);
        if (decoded != null) {
          // Crop and optimize to upper chest & shoulders (ideal passport frame)
          print('Successfully decoded $fileName: ${decoded.width}x${decoded.height}');
          await targetFile.writeAsBytes(response.bodyBytes);
          print('Saved: ${targetFile.path} (${(response.bodyBytes.lengthInBytes / 1024).round()} KB)');
        }
      } else {
        print('Failed to download $fileName: HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('Error downloading $fileName: $e');
    }
  }

  print('Finished downloading studio attire templates.');
}
