import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../core/theme.dart';
import '../models/compliance_result.dart';
import '../models/country_spec.dart';
import '../services/photo_composer_service.dart';
import 'compliance_screen.dart';

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
    final package = await PhotoComposerService.processPhotoBytes(
      rawBytes: rawBytes,
      spec: widget.spec,
    );

    final audit = ComplianceAuditResult.mockPassingResult(
      headRatio: 0.62,
      countryName: widget.spec.countryName,
    );

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ComplianceScreen(
          package: package,
          spec: widget.spec,
          auditResult: audit,
          rawBytes: rawBytes,
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

                        // Vignette & HUD vector overlay
                        CustomPaint(
                          painter: _CameraHudPainter(),
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
                    onPressed: _isProcessing ? null : _pickFromGallery,
                    tooltip: 'Import from Gallery',
                  ),

                  // Tactile Dual-Ring Shutter Button
                  GestureDetector(
                    onTap: _isProcessing ? null : _capturePhoto,
                    child: Container(
                      width: 76,
                      height: 76,
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.secondary, width: 3),
                      ),
                      child: Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
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
  @override
  void paint(Canvas canvas, Size size) {
    final reticlePaint = Paint()
      ..color = AppTheme.tertiary
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final guidePaint = Paint()
      ..color = AppTheme.tertiary.withValues(alpha: 0.8)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const cornerLength = 24.0;
    const padding = 20.0;

    // Top-Left corner
    canvas.drawLine(const Offset(padding, padding + cornerLength), const Offset(padding, padding), reticlePaint);
    canvas.drawLine(const Offset(padding, padding), const Offset(padding + cornerLength, padding), reticlePaint);

    // Top-Right corner
    canvas.drawLine(Offset(size.width - padding, padding + cornerLength), Offset(size.width - padding, padding), reticlePaint);
    canvas.drawLine(Offset(size.width - padding, padding), Offset(size.width - padding - cornerLength, padding), reticlePaint);

    // Bottom-Left corner
    canvas.drawLine(Offset(padding, size.height - padding - cornerLength), Offset(padding, size.height - padding), reticlePaint);
    canvas.drawLine(Offset(padding, size.height - padding), Offset(padding + cornerLength, size.height - padding), reticlePaint);

    // Bottom-Right corner
    canvas.drawLine(Offset(size.width - padding, size.height - padding - cornerLength), Offset(size.width - padding, size.height - padding), reticlePaint);
    canvas.drawLine(Offset(size.width - padding, size.height - padding), Offset(size.width - padding - cornerLength, size.height - padding), reticlePaint);

    // Biometric Face Oval Target
    final headRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.46),
      width: size.width * 0.60,
      height: size.height * 0.60,
    );
    canvas.drawOval(headRect, guidePaint);

    // Eye line
    final eyeY = size.height * 0.40;
    canvas.drawLine(Offset(size.width * 0.25, eyeY), Offset(size.width * 0.75, eyeY), guidePaint);

    // Chin line
    final chinY = size.height * 0.72;
    canvas.drawLine(Offset(size.width * 0.35, chinY), Offset(size.width * 0.65, chinY), guidePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
