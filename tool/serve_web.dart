import 'dart:io';

void main() async {
  final buildDir = Directory('build/web');
  if (!buildDir.existsSync()) {
    print('Error: build/web directory does not exist.');
    return;
  }

  final server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
  print('==================================================');
  print('SpecPass Live Server Running!');
  print('On phone (same Wi-Fi): http://192.168.100.106:8080');
  print('On PC:                http://localhost:8080');
  print('==================================================');

  await for (HttpRequest request in server) {
    var path = request.uri.path;
    if (path == '/' || path.isEmpty) {
      path = '/index.html';
    }

    final file = File('build/web$path');
    final targetFile = await file.exists() ? file : File('build/web/index.html');
    if (await targetFile.exists()) {
      request.response.headers.contentType = _getContentType(targetFile.path);
      request.response.headers.contentLength = await targetFile.length();
      request.response.headers.add('Access-Control-Allow-Origin', '*');
      request.response.headers.add('Cache-Control', 'no-cache');
      if (request.method.toUpperCase() == 'HEAD') {
        await request.response.close();
      } else {
        await targetFile.openRead().pipe(request.response);
      }
    } else {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    }
  }
}

ContentType _getContentType(String path) {
  if (path.endsWith('.html')) return ContentType.html;
  if (path.endsWith('.js') || path.endsWith('.mjs')) return ContentType('application', 'javascript');
  if (path.endsWith('.wasm')) return ContentType('application', 'wasm');
  if (path.endsWith('.css')) return ContentType('text', 'css');
  if (path.endsWith('.json')) return ContentType.json;
  if (path.endsWith('.png')) return ContentType('image', 'png');
  if (path.endsWith('.jpg') || path.endsWith('.jpeg')) return ContentType('image', 'jpeg');
  if (path.endsWith('.svg')) return ContentType('image', 'svg+xml');
  if (path.endsWith('.ttf') || path.endsWith('.otf')) return ContentType('font', 'ttf');
  if (path.endsWith('.apk')) return ContentType('application', 'vnd.android.package-archive');
  return ContentType.binary;
}
