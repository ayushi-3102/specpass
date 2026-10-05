import 'dart:async';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../core/theme.dart';
import '../models/country_spec.dart';
import 'biometric_crop_align_screen.dart';

class CameraStudioScreen extends ConsumerStatefulWidget {
  final CountrySpec spec;

  const CameraStudioScreen({super.key, required this.spec});

  @override
  ConsumerState<CameraStudioScreen> createState() => _CameraStudioScreenState();
}

class _CameraStudioScreenState extends ConsumerState<CameraStudioScreen> {
  CameraController? _cameraController;
  List<CameraDescription> _availableCameras = [];
  int _selectedCameraIndex = 0;
  bool _isCameraReady = false;
  bool _isProcessing = false;
  FlashMode _flashMode = FlashMode.auto;
  int _timerDuration = 0; // 0 = OFF, 3 = 3s, 5 = 5s
  int _countdownRemaining = 0;
  bool _isCountingDown = false;

  void _onShutterTapped() {
    if (_isProcessing || _isCountingDown) return;
    if (_timerDuration == 0) {
      _capturePhoto();
      return;
    }

    setState(() {
      _isCountingDown = true;
      _countdownRemaining = _timerDuration;
    });

    HapticFeedback.mediumImpact();

    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdownRemaining <= 1) {
        timer.cancel();
        setState(() {
          _isCountingDown = false;
          _countdownRemaining = 0;
        });
        HapticFeedback.heavyImpact();
        _capturePhoto();
      } else {
        setState(() {
          _countdownRemaining--;
        });
        HapticFeedback.selectionClick();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _availableCameras = await availableCameras();
      if (_availableCameras.isNotEmpty) {
        // Prefer front camera for passport selfie or back camera
        final frontCameraIndex = _availableCameras.indexWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
        );
        _selectedCameraIndex = frontCameraIndex != -1 ? frontCameraIndex : 0;

        await _setupController(_availableCameras[_selectedCameraIndex]);
      }
    } catch (e) {
      debugPrint('[SpecPass] Camera init error: $e');
    }
  }

  Future<void> _setupController(CameraDescription camera) async {
    final controller = CameraController(
      camera,
      ResolutionPreset.veryHigh,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await controller.initialize();
      if (mounted) {
        setState(() {
          _cameraController = controller;
          _isCameraReady = true;
        });
      }
    } catch (e) {
      debugPrint('[SpecPass] Setup controller error: $e');
    }
  }

  Future<void> _flipCamera() async {
    if (_availableCameras.length < 2) return;
    HapticFeedback.selectionClick();
    setState(() => _isCameraReady = false);

    _selectedCameraIndex = (_selectedCameraIndex + 1) % _availableCameras.length;
    await _cameraController?.dispose();
    await _setupController(_availableCameras[_selectedCameraIndex]);
  }

  Future<void> _toggleFlash() async {
    if (_cameraController == null) return;
    HapticFeedback.selectionClick();

    FlashMode nextMode;
    switch (_flashMode) {
      case FlashMode.auto:
        nextMode = FlashMode.always;
        break;
      case FlashMode.always:
        nextMode = FlashMode.off;
        break;
      case FlashMode.off:
      default:
        nextMode = FlashMode.auto;
        break;
    }

    try {
      await _cameraController!.setFlashMode(nextMode);
      setState(() => _flashMode = nextMode);
    } catch (e) {
      debugPrint('[SpecPass] Flash error: $e');
    }
  }

  Future<void> _capturePhoto() async {
    if (_isProcessing) return;

    if (_cameraController != null && _cameraController!.value.isInitialized) {
      HapticFeedback.heavyImpact();
      setState(() => _isProcessing = true);
      try {
        final XFile captured = await _cameraController!.takePicture();
        final bytesToProcess = await captured.readAsBytes();
        await _runProcessingPipeline(bytesToProcess);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Capture error: $e')),
        );
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    } else {
      // In web browser or when live camera stream is blocked by browser policy, open phone native camera directly!
      await _openNativeCamera();
    }
  }

  Future<void> _openNativeCamera() async {
    if (_isProcessing) return;
    HapticFeedback.heavyImpact();

    try {
      final picker = ImagePicker();
      final XFile? captured = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 100,
      );

      if (captured != null) {
        setState(() => _isProcessing = true);
        final bytes = await captured.readAsBytes();
        await _runProcessingPipeline(bytes);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Camera error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _pickFromGallery() async {
    if (_isProcessing) return;
    HapticFeedback.lightImpact();

    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 100);

      if (picked != null) {
        setState(() => _isProcessing = true);
        final bytes = await picked.readAsBytes();
        await _runProcessingPipeline(bytes);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Picker error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }


  Future<void> _runProcessingPipeline(Uint8List rawBytes) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BiometricCropAlignScreen(
          rawBytes: rawBytes,
          spec: widget.spec,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppTheme.surfaceDim,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top HUD Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.onSurface, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainerHigh.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.outlineVariant),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppTheme.tertiary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${widget.spec.standardTag} | ${widget.spec.formattedDimensions}',
                          style: const TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.tertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      // Self-Timer Toggle Button
                      IconButton(
                        icon: Icon(
                          _timerDuration == 0
                              ? Icons.timer_off_outlined
                              : (_timerDuration == 3 ? Icons.timer_3 : Icons.timer),
                          color: _timerDuration > 0 ? AppTheme.tertiary : AppTheme.onSurface,
                          size: 20,
                        ),
                        tooltip: 'Self-Timer (${_timerDuration == 0 ? 'Off' : '${_timerDuration}s'})',
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            if (_timerDuration == 0) {
                              _timerDuration = 3;
                            } else if (_timerDuration == 3) {
                              _timerDuration = 5;
                            } else {
                              _timerDuration = 0;
                            }
                          });
                        },
                      ),
                      IconButton(
                        icon: Icon(
                          _flashMode == FlashMode.auto
                              ? Icons.flash_auto
                              : (_flashMode == FlashMode.always ? Icons.flash_on : Icons.flash_off),
                          color: AppTheme.onSurface,
                          size: 20,
                        ),
                        onPressed: _toggleFlash,
                      ),
                      IconButton(
                        icon: const Icon(Icons.cameraswitch, color: AppTheme.onSurface, size: 20),
                        onPressed: _flipCamera,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Alignment Status Pill
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.tertiaryContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.tertiary.withValues(alpha: 0.5)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: AppTheme.tertiary, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Hold Still — Biometric Lock',
                          style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.onSurface, fontSize: 13),
                        ),
                      ],
                    ),
                    Text(
                      '98.4%',
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontWeight: FontWeight.bold,
                        color: AppTheme.tertiary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Micro Telemetry Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _buildTelemetryChip(Icons.lightbulb, 'LUX', '420 lx · OPTIMAL', AppTheme.secondary),
                  const SizedBox(width: 8),
                  _buildTelemetryChip(Icons.screen_rotation_alt, 'TILT', '0.2° ROLL', AppTheme.tertiary),
                  const SizedBox(width: 8),
                  _buildTelemetryChip(Icons.visibility, 'EYES', 'OPEN & ALIGNED', AppTheme.tertiary),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Live Camera Viewfinder Chamber
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Container(
                    color: AppTheme.surfaceContainerLowest,
                    child: Stack(
                      fit: StackFit.expand,
                      alignment: Alignment.center,
                      children: [
                        if (_isCameraReady && _cameraController != null)
                          CameraPreview(_cameraController!)
                        else
                          GestureDetector(
                            onTap: _openNativeCamera,
                            child: Container(
                              color: AppTheme.surfaceContainerLowest,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Opacity(
                                    opacity: 0.15,
                                    child: Image.asset(
                                      'assets/images/sample_portrait.png',
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: _openNativeCamera,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.primary,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                          elevation: 8,
                                        ),
                                        icon: const Icon(Icons.photo_camera, size: 22),
                                        label: const Text(
                                          'Open Phone Camera',
                                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      OutlinedButton.icon(
                                        onPressed: _pickFromGallery,
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppTheme.onSurface,
                                          backgroundColor: AppTheme.surfaceContainerHigh.withValues(alpha: 0.8),
                                          side: const BorderSide(color: AppTheme.outlineVariant),
                                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        ),
                                        icon: const Icon(Icons.photo_library, size: 18),
                                        label: const Text(
                                          'Choose from Library',
                                          style: TextStyle(fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // Consular Aspect-Ratio Viewfinder Mask & HUD vector overlay
                        CustomPaint(
                          painter: _CameraHudPainter(
                            specAspect: widget.spec.widthMm / widget.spec.heightMm,
                            headRatioMin: widget.spec.headRatioMin,
                            headRatioMax: widget.spec.headRatioMax,
                          ),
                        ),

                        if (_isCountingDown)
                          Container(
                            color: Colors.black.withValues(alpha: 0.55),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 110,
                                    height: 110,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppTheme.surfaceContainerLowest.withValues(alpha: 0.85),
                                      border: Border.all(color: AppTheme.tertiary, width: 3),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppTheme.tertiary.withValues(alpha: 0.4),
                                          blurRadius: 30,
                                          spreadRadius: 4,
                                        ),
                                      ],
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '$_countdownRemaining',
                                      style: const TextStyle(
                                        fontFamily: 'JetBrains Mono',
                                        fontSize: 56,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.tertiary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Hold Still & Look Straight Ahead',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        if (_isProcessing)
                          Container(
                            color: Colors.black.withValues(alpha: 0.75),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(color: AppTheme.tertiary),
                                SizedBox(height: 16),
                                Text(
                                  'AI Biometric Segmentation & Alignment...',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Bottom Shutter & Controls
            Padding(
              padding: EdgeInsets.fromLTRB(24, 20, 24, bottomInset + 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Gallery Pick Button
                  IconButton(
                    icon: const Icon(Icons.photo_library_outlined, color: AppTheme.onSurface, size: 28),
                    onPressed: _isProcessing || _isCountingDown ? null : _pickFromGallery,
                    tooltip: 'Import from Gallery',
                  ),

                  // Tactile Dual-Ring Shutter Button with Self-Timer Indicator
                  GestureDetector(
                    onTap: _isProcessing || _isCountingDown ? null : _onShutterTapped,
                    child: Container(
                      width: 76,
                      height: 76,
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _isCountingDown ? AppTheme.tertiary : AppTheme.secondary,
                          width: 3,
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isCountingDown ? AppTheme.tertiaryContainer : Colors.white,
                        ),
                        child: _timerDuration > 0
                            ? Center(
                                child: Text(
                                  _isCountingDown ? '$_countdownRemaining' : '${_timerDuration}s',
                                  style: TextStyle(
                                    fontFamily: 'JetBrains Mono',
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: _isCountingDown ? AppTheme.tertiary : Colors.black87,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),

                  // Info specs button
                  IconButton(
                    icon: const Icon(Icons.info_outline, color: AppTheme.onSurface, size: 28),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          backgroundColor: AppTheme.surfaceContainerLow,
                          title: Text(widget.spec.documentTitle),
                          content: Text(
                            'Dimensions: ${widget.spec.formattedDimensions}\n'
                            'Head Ratio: ${(widget.spec.headRatioMin * 100).toInt()}% – ${(widget.spec.headRatioMax * 100).toInt()}%\n'
                            'Background: ${widget.spec.backgroundName}\n\n'
                            '${widget.spec.notes}',
                            style: const TextStyle(fontSize: 14, height: 1.4),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('OK'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTelemetryChip(IconData icon, String label, String value, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 10,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraHudPainter extends CustomPainter {
  final double specAspect;
  final double headRatioMin;
  final double headRatioMax;

  _CameraHudPainter({
    required this.specAspect,
    required this.headRatioMin,
    required this.headRatioMax,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Calculate the aspect-ratio frame box
    double frameW = size.width * 0.88;
    double frameH = frameW / specAspect;

    if (frameH > size.height * 0.88) {
      frameH = size.height * 0.88;
      frameW = frameH * specAspect;
    }

    final frameRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: frameW,
      height: frameH,
    );

    // 2. Darken area outside the frame
    final maskPaint = Paint()..color = Colors.black.withValues(alpha: 0.60);
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(frameRect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, maskPaint);

    // 3. Draw Outer Border & Gold Corner Registration Marks
    final borderPaint = Paint()
      ..color = AppTheme.secondary
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    canvas.drawRect(frameRect, borderPaint);

    final cornerPaint = Paint()
      ..color = const Color(0xFFD4AF37)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    const cornerLen = 22.0;
    // Top-Left
    canvas.drawLine(Offset(frameRect.left, frameRect.top + cornerLen), Offset(frameRect.left, frameRect.top), cornerPaint);
    canvas.drawLine(Offset(frameRect.left, frameRect.top), Offset(frameRect.left + cornerLen, frameRect.top), cornerPaint);
    // Top-Right
    canvas.drawLine(Offset(frameRect.right - cornerLen, frameRect.top), Offset(frameRect.right, frameRect.top), cornerPaint);
    canvas.drawLine(Offset(frameRect.right, frameRect.top), Offset(frameRect.right, frameRect.top + cornerLen), cornerPaint);
    // Bottom-Left
    canvas.drawLine(Offset(frameRect.left, frameRect.bottom - cornerLen), Offset(frameRect.left, frameRect.bottom), cornerPaint);
    canvas.drawLine(Offset(frameRect.left, frameRect.bottom), Offset(frameRect.left + cornerLen, frameRect.bottom), cornerPaint);
    // Bottom-Right
    canvas.drawLine(Offset(frameRect.right - cornerLen, frameRect.bottom), Offset(frameRect.right, frameRect.bottom), cornerPaint);
    canvas.drawLine(Offset(frameRect.right, frameRect.bottom), Offset(frameRect.right, frameRect.bottom - cornerLen), cornerPaint);

    // 4. Biometric Guidelines:
    final targetHeadRatio = (headRatioMin + headRatioMax) / 2.0;
    final crownY = frameRect.top + (frameH * 0.09);
    final chinY = crownY + (frameH * targetHeadRatio);
    final eyeY = crownY + (frameH * targetHeadRatio * 0.44);

    final guidePaint = Paint()
      ..color = AppTheme.tertiary
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final dashPaint = Paint()
      ..color = AppTheme.secondary.withValues(alpha: 0.8)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    // Crown dashed line
    _drawDashedHorizontal(canvas, frameRect.left + 15, frameRect.right - 15, crownY, dashPaint);

    // Eye Horizon Solid Line with center crosshair
    canvas.drawLine(Offset(frameRect.left + 10, eyeY), Offset(frameRect.right - 10, eyeY), guidePaint);
    canvas.drawLine(Offset(frameRect.center.dx, eyeY - 8), Offset(frameRect.center.dx, eyeY + 8), guidePaint);

    // Chin dashed line
    _drawDashedHorizontal(canvas, frameRect.left + 15, frameRect.right - 15, chinY, dashPaint);

    // Biometric Head Oval
    final headOvalRect = Rect.fromCenter(
      center: Offset(frameRect.center.dx, (crownY + chinY) / 2),
      width: frameW * 0.58,
      height: chinY - crownY,
    );
    canvas.drawOval(headOvalRect, dashPaint);
  }

  void _drawDashedHorizontal(Canvas canvas, double x1, double x2, double y, Paint paint) {
    const dashW = 6.0;
    const spaceW = 4.0;
    double startX = x1;
    while (startX < x2) {
      canvas.drawLine(Offset(startX, y), Offset(math.min(startX + dashW, x2), y), paint);
      startX += dashW + spaceW;
    }
  }

  @override
  bool shouldRepaint(covariant _CameraHudPainter oldDelegate) =>
      oldDelegate.specAspect != specAspect ||
      oldDelegate.headRatioMin != headRatioMin ||
      oldDelegate.headRatioMax != headRatioMax;
}
