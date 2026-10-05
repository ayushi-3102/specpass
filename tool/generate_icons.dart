import 'dart:io';
import 'package:image/image.dart' as img;

void main() async {
  final sourcePath = r'C:\Users\ayush\.gemini\antigravity-cli\brain\b0f815fc-de42-4036-9750-2b4157b57998\specpass_app_icon_1024_1791232948624.jpg';
  final sourceFile = File(sourcePath);
  if (!sourceFile.existsSync()) {
    print('Source file not found at $sourcePath');
    return;
  }

  final bytes = await sourceFile.readAsBytes();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    print('Failed to decode source image');
    return;
  }

  // Ensure 1024x1024 master
  final master1024 = (decoded.width == 1024 && decoded.height == 1024)
      ? decoded
      : img.copyResize(decoded, width: 1024, height: 1024, interpolation: img.Interpolation.linear);

  // 1. Master 1024x1024 PNG
  final masterPngBytes = img.encodePng(master1024);
  final masterFile = File(r'C:\Users\ayush\specpass\assets\images\app_icon_1024.png');
  await masterFile.writeAsBytes(masterPngBytes);
  print('Saved master 1024x1024 icon to ${masterFile.path}');

  // 2. Adaptive Foreground (1024x1024)
  final adaptiveForeground = img.copyResize(master1024, width: 1024, height: 1024);
  final adaptiveFile = File(r'C:\Users\ayush\specpass\assets\images\app_icon_adaptive_foreground.png');
  await adaptiveFile.writeAsBytes(img.encodePng(adaptiveForeground));
  print('Saved adaptive foreground to ${adaptiveFile.path}');

  // 3. In-App Logo (256x256)
  final logo256 = img.copyResize(master1024, width: 256, height: 256, interpolation: img.Interpolation.average);
  final logoFile = File(r'C:\Users\ayush\specpass\assets\images\logo.png');
  await logoFile.writeAsBytes(img.encodePng(logo256));
  print('Updated in-app logo at ${logoFile.path}');

  // 4. Web Favicon (64x64)
  final fav64 = img.copyResize(master1024, width: 64, height: 64, interpolation: img.Interpolation.average);
  await File(r'C:\Users\ayush\specpass\web\favicon.png').writeAsBytes(img.encodePng(fav64));
  if (Directory(r'C:\Users\ayush\specpass\build\web').existsSync()) {
    await File(r'C:\Users\ayush\specpass\build\web\favicon.png').writeAsBytes(img.encodePng(fav64));
  }
  print('Updated web favicon');

  // 5. Web PWA Icons (192x192, 512x512)
  final icon192 = img.copyResize(master1024, width: 192, height: 192, interpolation: img.Interpolation.average);
  final icon512 = img.copyResize(master1024, width: 512, height: 512, interpolation: img.Interpolation.average);
  final png192 = img.encodePng(icon192);
  final png512 = img.encodePng(icon512);

  for (final dir in [r'C:\Users\ayush\specpass\web\icons', r'C:\Users\ayush\specpass\build\web\icons']) {
    final d = Directory(dir);
    if (!d.existsSync()) d.createSync(recursive: true);
    await File('$dir/Icon-192.png').writeAsBytes(png192);
    await File('$dir/Icon-512.png').writeAsBytes(png512);
    await File('$dir/Icon-maskable-192.png').writeAsBytes(png192);
    await File('$dir/Icon-maskable-512.png').writeAsBytes(png512);
  }
  print('Updated web PWA icons');
}
