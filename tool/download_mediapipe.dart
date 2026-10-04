import 'dart:io';

void main() async {
  final dir = Directory('web/mediapipe');
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }

  final files = [
    'selfie_segmentation.js',
    'selfie_segmentation_solution_wasm_bin.js',
    'selfie_segmentation_solution_wasm_bin.wasm',
    'selfie_segmentation_solution_simd_wasm_bin.js',
    'selfie_segmentation_solution_simd_wasm_bin.wasm',
    'selfie_segmentation.binarypb',
    'selfie_segmentation.tflite',
  ];

  final client = HttpClient();

  for (final file in files) {
    final url = Uri.parse('https://cdn.jsdelivr.net/npm/@mediapipe/selfie_segmentation/$file');
    print('Downloading $file from $url...');
    try {
      final req = await client.getUrl(url);
      final resp = await req.close();
      if (resp.statusCode == 200) {
        final target = File('web/mediapipe/$file');
        final sink = target.openWrite();
        await resp.pipe(sink);
        print('Saved $file (${target.lengthSync()} bytes)');
      } else {
        print('HTTP Error ${resp.statusCode} for $file');
      }
    } catch (e) {
      print('Failed to download $file: $e');
    }
  }

  client.close();
  print('All MediaPipe assets downloaded for 100% offline bundling!');
}
