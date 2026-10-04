import 'dart:io';
import 'package:image/image.dart' as img;

void main() async {
  final sourcePath = r'C:\Users\ayush\.gemini\antigravity-cli\brain\b0f815fc-de42-4036-9750-2b4157b57998\specpass_app_icon_1024_1791128190323.jpg';
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

  // Ensure 1024x1024
  final master1024 = (decoded.width == 1024 && decoded.height == 1024)
      ? decoded
      : img.copyResize(decoded, width: 1024, height: 1024, interpolation: img.Interpolation.linear);

  // 1. Master PNG
  final masterPngBytes = img.encodePng(master1024);
  final masterFile = File(r'C:\Users\ayush\specpass\assets\images\app_icon_1024.png');
  await masterFile.writeAsBytes(masterPngBytes);
  print('Saved master 1024x1024 icon to ${masterFile.path}');

  // 2. Adaptive Foreground (with 25% padding inside 1024 canvas for safe zone)
  // Since the generated icon is already centered with safe margins, we can create the adaptive foreground
  final adaptiveForeground = img.copyResize(master1024, width: 1024, height: 1024);
  final adaptiveFile = File(r'C:\Users\ayush\specpass\assets\images\app_icon_adaptive_foreground.png');
  await adaptiveFile.writeAsBytes(img.encodePng(adaptiveForeground));
  print('Saved adaptive foreground to ${adaptiveFile.path}');

  // 3. In-App Logo (256x256)
  final logo256 = img.copyResize(master1024, width: 256, height: 256, interpolation: img.Interpolation.average);
  final logoFile = File(r'C:\Users\ayush\specpass\assets\images\logo.png');
  await logoFile.writeAsBytes(img.encodePng(logo256));
  print('Updated in-app logo at ${logoFile.path}');
}
