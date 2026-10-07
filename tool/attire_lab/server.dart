import 'dart:io';

void main() async {
  final port = 8085;
  final serverDir = Directory('${Directory.current.path}/tool/attire_lab');
  final assetsDir = Directory('${Directory.current.path}/assets');

  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  print('==================================================');
  print('SpecPass Attire Lab Server Running!');
  print('Open on PC:                 http://localhost:$port');
  print('Open on Phone (same Wi-Fi): http://192.168.100.106:$port');
  print('==================================================');

  await for (HttpRequest request in server) {
    try {
      String path = request.uri.path;
      if (path == '/' || path.isEmpty) {
        path = '/index.html';
      }

      File? file;
      if (path.startsWith('/assets/')) {
        final rel = path.substring('/assets/'.length);
        file = File('${assetsDir.path}/$rel');
      } else {
        file = File('${serverDir.path}$path');
      }

      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        final ext = file.path.split('.').last.toLowerCase();
        String contentType = 'text/plain';

        switch (ext) {
          case 'html':
            contentType = 'text/html; charset=utf-8';
            break;
          case 'js':
            contentType = 'application/javascript; charset=utf-8';
            break;
          case 'css':
            contentType = 'text/css; charset=utf-8';
            break;
          case 'png':
            contentType = 'image/png';
            break;
          case 'jpg':
          case 'jpeg':
            contentType = 'image/jpeg';
            break;
          case 'svg':
            contentType = 'image/svg+xml';
            break;
          case 'json':
            contentType = 'application/json';
            break;
        }

        request.response.headers.set('Content-Type', contentType);
        request.response.headers.set('Access-Control-Allow-Origin', '*');
        request.response.headers.set('Cache-Control', 'no-cache, no-store, must-revalidate');
        request.response.add(bytes);
        await request.response.close();
      } else {
        request.response.statusCode = HttpStatus.notFound;
        request.response.write('404 Not Found: $path');
        await request.response.close();
      }
    } catch (e) {
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write('Server Error: $e');
      await request.response.close();
    }
  }
}
