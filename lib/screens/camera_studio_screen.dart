import 'dart:async';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';
import '../core/theme.dart';
import '../models/country_spec.dart';
import 'biometric_crop_align_screen.dart';

enum BiometricGuidanceState {
  searching(
    title: 'Align in Silhouette',
    instruction: 'Fit your head and shoulders inside the outline',
    color: Color(0xFF94A3B8), // Slate gray
    icon: Icons.face_retouching_natural,
    isReady: false,
  ),
  tooFar(
    title: 'Move Closer',
    instruction: 'Step closer to the camera to fill the frame',
    color: Color(0xFFF59E0B), // Amber
    icon: Icons.zoom_in,
    isReady: false,
  ),
  tooClose(
    title: 'Move Further Back',
    instruction: 'Step back slightly so your head and collar fit',
    color: Color(0xFFF59E0B), // Amber
    icon: Icons.zoom_out,
    isReady: false,
  ),
  offCenter(
    title: 'Center Your Head',
    instruction: 'Align your face in the center of the outline',
    color: Color(0xFFF59E0B), // Amber
    icon: Icons.center_focus_strong,
    isReady: false,
  ),
  tilted(
    title: 'Straighten Your Head',
    instruction: 'Keep your eyes level and look directly at sensor',
    color: Color(0xFFF59E0B), // Amber
    icon: Icons.screen_rotation,
    isReady: false,
  ),
  perfect(
    title: 'PERFECT! HOLD STILL',
    instruction: 'Biometric lock engaged • Tap shutter to capture',
    color: Color(0xFF10B981), // Emerald Green
    icon: Icons.check_circle_rounded,
    isReady: true,
  );

  final String title;
  final String instruction;
  final Color color;
  final IconData icon;
  final bool isReady;

  const BiometricGuidanceState({
    required this.title,
    required this.instruction,
    required this.color,
    required this.icon,
    required this.isReady,
  });
}

class CameraStudioScreen extends ConsumerStatefulWidget {
  final CountrySpec spec;

  const CameraStudioScreen({super.key, required this.spec});

  @override
  ConsumerState<CameraStudioScreen> createState() => _CameraStudioScreenState();
}

class _CameraStudioScreenState extends ConsumerState<CameraStudioScreen> with SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  List<CameraDescription> _availableCameras = [];
  int _selectedCameraIndex = 0;
  bool _isCameraReady = false;
  bool _isProcessing = false;
  FlashMode _flashMode = FlashMode.auto;
  int _timerDuration = 0; // 0 = OFF, 3 = 3s, 5 = 5s
  int _countdownRemaining = 0;
  bool _isCountingDown = false;

  // Real-Time Biometric Face Guidance
  FaceDetector? _faceDetector;
  BiometricGuidanceState _guidanceState = BiometricGuidanceState.searching;
  bool _isDetecting = false;
  DateTime _lastDetectTime = DateTime.now();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initFaceDetector();
    _initCamera();
  }

  void _initFaceDetector() {
    try {
      _faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          performanceMode: FaceDetectorMode.fast,
          minFaceSize: 0.15,
          enableClassification: false,
          enableLandmarks: false,
          enableContours: false,
        ),
      );
    } catch (e) {
      debugPrint('[SpecPass] Face detector init: $e');
    }
  }

  Future<void> _initCamera() async {
    try {
      _availableCameras = await availableCameras();
      if (_availableCameras.isNotEmpty) {
        final frontIndex = _availableCameras.indexWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
        );
        _selectedCameraIndex = frontIndex != -1 ? frontIndex : 0;
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

        // Start live camera stream analysis on supported mobile platforms
        if (!kIsWeb) {
          _startLiveDetectionStream();
        }
      }
    } catch (e) {
      debugPrint('[SpecPass] Setup controller error: $e');
    }
  }

  void _startLiveDetectionStream() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    try {
      _cameraController!.startImageStream((CameraImage image) {
        final now = DateTime.now();
        // Analyze frame every 280ms (~3.5 fps) to keep preview completely silky smooth
        if (_isDetecting || now.difference(_lastDetectTime).inMilliseconds < 280) {
          return;
        }
        _isDetecting = true;
        _lastDetectTime = now;

        _processFrameForBiometricGuidance(image).whenComplete(() {
          _isDetecting = false;
        });
      });
    } catch (e) {
      debugPrint('[SpecPass] Live stream detection notice: $e');
    }
  }

  Future<void> _processFrameForBiometricGuidance(CameraImage image) async {
    if (_faceDetector == null) return;

    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());
      final camera = _availableCameras[_selectedCameraIndex];
      final imageRotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation) ??
          InputImageRotation.rotation0deg;
      final inputImageFormat = InputImageFormatValue.fromRawValue(image.format.raw) ??
          InputImageFormat.nv21;

      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: imageSize,
          rotation: imageRotation,
          format: inputImageFormat,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );

      final List<Face> faces = await _faceDetector!.processImage(inputImage);

      if (!mounted) return;

      if (faces.isEmpty) {
        _updateGuidance(BiometricGuidanceState.searching);
        return;
      }

      final Face face = faces.first;
      final double faceH = face.boundingBox.height;
      final double faceCenterX = face.boundingBox.center.dx;

      // Compute ratio relative to the shorter camera sensor dimension
      final double minDim = math.min(imageSize.width, imageSize.height);
      final double ratio = faceH / minDim;

      // Check head roll tilt
      final double roll = face.headEulerAngleZ ?? 0.0;

      if (roll.abs() > 5.5) {
        _updateGuidance(BiometricGuidanceState.tilted);
      } else if (ratio < 0.38) {
        _updateGuidance(BiometricGuidanceState.tooFar);
      } else if (ratio > 0.76) {
        _updateGuidance(BiometricGuidanceState.tooClose);
      } else if ((faceCenterX - imageSize.width / 2).abs() > (imageSize.width * 0.18)) {
        _updateGuidance(BiometricGuidanceState.offCenter);
      } else {
        _updateGuidance(BiometricGuidanceState.perfect);
      }
    } catch (_) {
      // Gracefully silent on frame conversion edge cases
    }
  }

  void _updateGuidance(BiometricGuidanceState newState) {
    if (_guidanceState != newState) {
      setState(() => _guidanceState = newState);
      if (newState == BiometricGuidanceState.perfect) {
        HapticFeedback.mediumImpact();
      }
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
    _pulseController.dispose();
    _cameraController?.dispose();
    _faceDetector?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final double specAspect = widget.spec.widthMm / widget.spec.heightMm;

    return Scaffold(
      backgroundColor: AppTheme.surfaceDim,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top HUD Bar: Back, Country Tag, Timer, Flash, Flip
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                        Text(
                          widget.spec.flagEmoji,
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${widget.spec.countryName} • ${widget.spec.formattedDimensions}',
                          style: const TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
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

            // Live Biometric Guidance Pill (Direct Instructions: "Move Closer", "Perfect!")
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: _guidanceState.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _guidanceState.color.withValues(alpha: 0.65),
                    width: _guidanceState.isReady ? 2.0 : 1.2,
                  ),
                  boxShadow: _guidanceState.isReady
                      ? [
                          BoxShadow(
                            color: _guidanceState.color.withValues(alpha: 0.25),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _guidanceState.color.withValues(alpha: 0.25),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _guidanceState.icon,
                        color: _guidanceState.color,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _guidanceState.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _guidanceState.color,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _guidanceState.instruction,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_guidanceState.isReady)
                      ScaleTransition(
                        scale: _pulseAnimation,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.tertiary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'READY',
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Live Camera Viewfinder Chamber with Head & Shoulders Silhouette
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
                              child: Center(
                                child: Column(
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
                                        'Open Camera Viewfinder',
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
                                      label: const Text('Choose from Gallery', style: TextStyle(fontSize: 13)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                        // Clean, Non-Confusing Head & Shoulders Silhouette Overlay
                        CustomPaint(
                          painter: _HeadAndShouldersViewfinderPainter(
                            specAspect: specAspect,
                            guidanceState: _guidanceState,
                          ),
                        ),

                        if (_isCountingDown)
                          Container(
                            color: Colors.black.withValues(alpha: 0.6),
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
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        if (_isProcessing)
                          Container(
                            color: Colors.black.withValues(alpha: 0.75),
                            child: const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(color: AppTheme.tertiary),
                                  SizedBox(height: 16),
                                  Text(
                                    'Capturing & Preparing Alignment...',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ],
                              ),
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
              padding: EdgeInsets.fromLTRB(24, 16, 24, bottomInset + 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(Icons.photo_library_outlined, color: AppTheme.onSurface, size: 28),
                    onPressed: _isProcessing || _isCountingDown ? null : _pickFromGallery,
                    tooltip: 'Import from Gallery',
                  ),

                  // Tactile Glowing Shutter Button (Pulses Green when Perfect!)
                  GestureDetector(
                    onTap: _isProcessing || _isCountingDown ? null : _onShutterTapped,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 80,
                      height: 80,
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _guidanceState.isReady ? AppTheme.tertiary : Colors.white70,
                          width: _guidanceState.isReady ? 4 : 3,
                        ),
                        boxShadow: _guidanceState.isReady
                            ? [
                                BoxShadow(
                                  color: AppTheme.tertiary.withValues(alpha: 0.5),
                                  blurRadius: 24,
                                  spreadRadius: 4,
                                ),
                              ]
                            : null,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _guidanceState.isReady ? AppTheme.tertiary : Colors.white,
                        ),
                        child: Center(
                          child: Icon(
                            _guidanceState.isReady ? Icons.camera_alt : Icons.circle,
                            color: _guidanceState.isReady ? Colors.black : Colors.black87,
                            size: _guidanceState.isReady ? 32 : 24,
                          ),
                        ),
                      ),
                    ),
                  ),

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
                            TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
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
}

/// Clean, Human-Friendly Head & Shoulders Silhouette Viewfinder Painter.
/// Replaces the confusing nested circles with an unmistakable passport booth silhouette.
class _HeadAndShouldersViewfinderPainter extends CustomPainter {
  final double specAspect;
  final BiometricGuidanceState guidanceState;

  _HeadAndShouldersViewfinderPainter({
    required this.specAspect,
    required this.guidanceState,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Calculate the aspect-ratio frame box
    double frameW = size.width * 0.86;
    double frameH = frameW / specAspect;

    if (frameH > size.height * 0.86) {
      frameH = size.height * 0.86;
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

    // 3. Draw Outer Border & Corner Registration Marks
    final borderPaint = Paint()
      ..color = guidanceState.color.withValues(alpha: guidanceState.isReady ? 0.9 : 0.4)
      ..strokeWidth = guidanceState.isReady ? 2.5 : 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawRect(frameRect, borderPaint);

    // Corner brackets
    final cornerPaint = Paint()
      ..color = guidanceState.isReady ? AppTheme.tertiary : const Color(0xFFD4AF37)
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

    // 4. Draw Natural Head & Shoulders Silhouette Contour
    final silhouettePaint = Paint()
      ..color = guidanceState.color
      ..strokeWidth = guidanceState.isReady ? 3.0 : 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final double cx = frameRect.center.dx;
    final double headCenterY = frameRect.top + (frameH * 0.42);
    final double headRadiusX = frameW * 0.27;
    final double headRadiusY = frameH * 0.29;

    // Head Oval
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, headCenterY),
        width: headRadiusX * 2,
        height: headRadiusY * 2,
      ),
      silhouettePaint,
    );

    // Shoulders & Collar Contour Path
    final shoulderPath = Path();
    final double chinY = headCenterY + headRadiusY;
    final double neckTopY = chinY + (frameH * 0.02);
    final double neckBottomY = chinY + (frameH * 0.08);
    final double neckHalfW = frameW * 0.11;

    // Left Neck to Shoulder
    shoulderPath.moveTo(cx - neckHalfW, neckTopY);
    shoulderPath.lineTo(cx - neckHalfW, neckBottomY);
    shoulderPath.quadraticBezierTo(
      cx - frameW * 0.25,
      neckBottomY + (frameH * 0.02),
      frameRect.left + (frameW * 0.05),
      frameRect.bottom - 4,
    );

    // Right Neck to Shoulder
    shoulderPath.moveTo(cx + neckHalfW, neckTopY);
    shoulderPath.lineTo(cx + neckHalfW, neckBottomY);
    shoulderPath.quadraticBezierTo(
      cx + frameW * 0.25,
      neckBottomY + (frameH * 0.02),
      frameRect.right - (frameW * 0.05),
      frameRect.bottom - 4,
    );

    canvas.drawPath(shoulderPath, silhouettePaint);

    // Subtle Eye Horizon Reference Line (single thin line with center crosshair)
    final eyePaint = Paint()
      ..color = guidanceState.color.withValues(alpha: 0.5)
      ..strokeWidth = 1.0;
    final double eyeY = headCenterY - (headRadiusY * 0.12);
    canvas.drawLine(Offset(cx - headRadiusX * 0.7, eyeY), Offset(cx + headRadiusX * 0.7, eyeY), eyePaint);
    canvas.drawLine(Offset(cx, eyeY - 6), Offset(cx, eyeY + 6), eyePaint);
  }

  @override
  bool shouldRepaint(covariant _HeadAndShouldersViewfinderPainter oldDelegate) =>
      oldDelegate.guidanceState != guidanceState || oldDelegate.specAspect != specAspect;
}
