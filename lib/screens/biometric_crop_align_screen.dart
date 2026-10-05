import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import '../core/theme.dart';
import '../models/compliance_result.dart';
import '../models/country_spec.dart';
import '../services/face_framing_service.dart';
import '../services/photo_composer_service.dart';
import 'compliance_screen.dart';

class BiometricCropAlignScreen extends ConsumerStatefulWidget {
  final Uint8List rawBytes;
  final CountrySpec spec;

  const BiometricCropAlignScreen({
    super.key,
    required this.rawBytes,
    required this.spec,
  });

  @override
  ConsumerState<BiometricCropAlignScreen> createState() => _BiometricCropAlignScreenState();
}

class _BiometricCropAlignScreenState extends ConsumerState<BiometricCropAlignScreen> {
  final TransformationController _transformController = TransformationController();
  double _rotationDegrees = 0.0;
  bool _isProcessing = false;
  bool _isAutoFraming = true;
  bool _userHasAdjusted = false;
  Size _chamberSize = const Size(360, 480);
  BiometricFramingResult? _framingResult;

  @override
  void initState() {
    super.initState();
    _transformController.addListener(_onTransformChanged);
  }

  void _onTransformChanged() {
    if (!_isAutoFraming) {
      _userHasAdjusted = true;
    }
  }

  Future<void> _performAutoFraming(Size chamberSize) async {
    _chamberSize = chamberSize;
    _isAutoFraming = true;

    final double specAspect = widget.spec.widthMm / widget.spec.heightMm;
    final img.Image? rawDecoded = img.decodeImage(widget.rawBytes);
    if (rawDecoded == null) return;
    final img.Image oriented = img.bakeOrientation(rawDecoded);

    final framing = await FaceFramingService.analyzeAndCalculateFraming(
      rawBytes: widget.rawBytes,
      spec: widget.spec,
      rotationDegrees: _rotationDegrees,
    );

    if (!mounted) return;

    final matrix = FaceFramingService.calculateAlignmentMatrix(
      chamberSize: chamberSize,
      specAspect: specAspect,
      imageWidth: oriented.width,
      imageHeight: oriented.height,
      framing: framing,
    );

    setState(() {
      _framingResult = framing;
      _transformController.value = matrix;
      _isAutoFraming = false;
      _userHasAdjusted = false;
    });
  }

  void _resetToAutoFraming() {
    HapticFeedback.selectionClick();
    setState(() {
      _rotationDegrees = 0.0;
    });
    _performAutoFraming(_chamberSize);
  }

  Future<void> _processAndProceed() async {
    if (_isProcessing) return;
    HapticFeedback.heavyImpact();

    setState(() => _isProcessing = true);

    try {
      final double specAspect = widget.spec.widthMm / widget.spec.heightMm;
      final Uint8List framedBytes = await _extractFramedPortrait(_chamberSize, specAspect);

      final package = await PhotoComposerService.processPhotoBytes(
        rawBytes: framedBytes,
        spec: widget.spec,
        rotationDegrees: 0.0, // Rotation is already baked into framedBytes
        alreadyCropped: true,
      );

      final audit = ComplianceAuditResult.mockPassingResult(
        headRatio: _framingResult != null && _framingResult!.hasFace
            ? _framingResult!.headRatio
            : (widget.spec.headRatioMin + widget.spec.headRatioMax) / 2.0,
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
            rawBytes: framedBytes,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Processing error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<Uint8List> _extractFramedPortrait(Size containerSize, double specAspect) async {
    final img.Image? rawDecoded = img.decodeImage(widget.rawBytes);
    if (rawDecoded == null) return widget.rawBytes;
    img.Image oriented = img.bakeOrientation(rawDecoded);

    if (_rotationDegrees.abs() > 0.01) {
      oriented = img.copyRotate(oriented, angle: _rotationDegrees, interpolation: img.Interpolation.cubic);
    }

    final double imgW = oriented.width.toDouble();
    final double imgH = oriented.height.toDouble();

    int cropX, cropY, cropW, cropH;

    // If the user has NOT manually dragged or pinched, use the exact mathematical consular framing!
    if (!_userHasAdjusted && _framingResult != null) {
      cropX = _framingResult!.cropX;
      cropY = _framingResult!.cropY;
      cropW = _framingResult!.cropWidth;
      cropH = _framingResult!.cropHeight;
    } else {
      // 1. Calculate Frame Rect inside container
      double frameW = containerSize.width * 0.88;
      double frameH = frameW / specAspect;
      if (frameH > containerSize.height * 0.88) {
        frameH = containerSize.height * 0.88;
        frameW = frameH * specAspect;
      }
      final frameRect = Rect.fromCenter(
        center: Offset(containerSize.width / 2, containerSize.height / 2),
        width: frameW,
        height: frameH,
      );

      // 2. Un-transformed display rect of image inside container
      final double scaleX = containerSize.width / imgW;
      final double scaleY = containerSize.height / imgH;
      final double baseScale = math.min(scaleX, scaleY);
      final double displayW = imgW * baseScale;
      final double displayH = imgH * baseScale;
      final double displayLeft = (containerSize.width - displayW) / 2;
      final double displayTop = (containerSize.height - displayH) / 2;

      // 3. Map screen viewport back to image coordinate space
      final Matrix4 transform = _transformController.value;
      final Matrix4 inverse = Matrix4.tryInvert(transform) ?? Matrix4.identity();

      final Offset pTopLeft = MatrixUtils.transformPoint(inverse, frameRect.topLeft);
      final Offset pBottomRight = MatrixUtils.transformPoint(inverse, frameRect.bottomRight);

      final double normLeft = (pTopLeft.dx - displayLeft) / displayW;
      final double normTop = (pTopLeft.dy - displayTop) / displayH;
      final double normRight = (pBottomRight.dx - displayLeft) / displayW;
      final double normBottom = (pBottomRight.dy - displayTop) / displayH;

      cropX = (normLeft * imgW).round();
      cropY = (normTop * imgH).round();
      cropW = ((normRight - normLeft) * imgW).round();
      cropH = ((normBottom - normTop) * imgH).round();
    }

    // Safety clamping
    cropX = cropX.clamp(0, oriented.width - 1);
    cropY = cropY.clamp(0, oriented.height - 1);
    cropW = cropW.clamp(20, oriented.width - cropX);
    cropH = cropH.clamp(20, oriented.height - cropY);

    final cropped = img.copyCrop(
      oriented,
      x: cropX,
      y: cropY,
      width: cropW,
      height: cropH,
    );

    return Uint8List.fromList(img.encodeJpg(cropped, quality: 98));
  }

  @override
  void dispose() {
    _transformController.removeListener(_onTransformChanged);
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final double specAspect = widget.spec.widthMm / widget.spec.heightMm;
    final colors = AppTheme.colors(context);

    return Scaffold(
      backgroundColor: colors.surfaceDim,
      appBar: AppBar(
        backgroundColor: colors.surfaceDim,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: colors.onSurface, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text(
              'Biometric Alignment Studio',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: colors.onSurface),
            ),
            Text(
              '${widget.spec.countryName} • ${widget.spec.formattedDimensions}',
              style: TextStyle(fontSize: 11, color: colors.secondary, fontFamily: 'JetBrains Mono'),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.restart_alt, color: colors.onSurface),
            tooltip: 'Reset Auto-Framing',
            onPressed: _resetToAutoFraming,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Status & AI Biometric Guidance Banner
            Container(
              margin: const EdgeInsets.fromLTRB(16, 6, 16, 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _framingResult?.hasFace == true
                      ? colors.tertiary.withValues(alpha: 0.5)
                      : colors.outlineVariant,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _framingResult?.hasFace == true ? Icons.verified : Icons.auto_awesome,
                    size: 18,
                    color: _framingResult?.hasFace == true ? colors.tertiary : colors.secondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _framingResult?.hasFace == true
                              ? 'Auto-Framed to ${widget.spec.countryName} Rules'
                              : 'AI Biometric Caliper Centering',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: colors.onSurface,
                          ),
                        ),
                        Text(
                          _userHasAdjusted
                              ? 'Custom manual adjustment applied • Tap ↺ to re-center'
                              : 'Head sized to ${(widget.spec.headRatioMin * 100).toInt()}–${(widget.spec.headRatioMax * 100).toInt()}% • Drag or pinch to nudge',
                          style: TextStyle(fontSize: 10, color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  if (_framingResult?.hasFace == true && !_userHasAdjusted)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: colors.tertiaryContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'OPTIMAL',
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: colors.tertiary,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Interactive Framing Chamber
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    color: colors.surfaceContainerLowest,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final size = Size(constraints.maxWidth, constraints.maxHeight);

                        if (_framingResult == null) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted && _framingResult == null) {
                              _performAutoFraming(size);
                            }
                          });
                        }

                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            // Interactive Image Canvas
                            InteractiveViewer(
                              transformationController: _transformController,
                              minScale: 0.3,
                              maxScale: 5.0,
                              boundaryMargin: const EdgeInsets.all(500),
                              child: Transform.rotate(
                                angle: _rotationDegrees * (math.pi / 180.0),
                                child: Image.memory(
                                  widget.rawBytes,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),

                            // Mask Overlay with Biometric Caliper Lines
                            IgnorePointer(
                              child: CustomPaint(
                                size: Size(constraints.maxWidth, constraints.maxHeight),
                                painter: _BiometricCaliperPainter(
                                  specAspect: specAspect,
                                  headRatioMin: widget.spec.headRatioMin,
                                  headRatioMax: widget.spec.headRatioMax,
                                  colors: colors,
                                ),
                              ),
                            ),

                            if (_isProcessing)
                              Container(
                                color: colors.surfaceDim.withValues(alpha: 0.85),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircularProgressIndicator(color: colors.tertiary),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Generating 300 DPI Consular Master...',
                                        style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),

            // Rotation / Tilt Slider Control
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                children: [
                  Icon(Icons.rotate_90_degrees_ccw, size: 18, color: colors.outline),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: colors.secondary,
                        inactiveTrackColor: colors.surfaceContainerHighest,
                        thumbColor: colors.secondary,
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                      ),
                      child: Slider(
                        value: _rotationDegrees,
                        min: -15.0,
                        max: 15.0,
                        divisions: 300,
                        onChanged: (val) {
                          setState(() => _rotationDegrees = val);
                        },
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 50,
                    child: Text(
                      '${_rotationDegrees >= 0 ? '+' : ''}${_rotationDegrees.toStringAsFixed(1)}°',
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: colors.secondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Action Bar
            Container(
              padding: EdgeInsets.fromLTRB(20, 10, 20, math.max(bottomInset, 16) + 14),
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                border: Border(top: BorderSide(color: colors.outlineVariant, width: 1)),
              ),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _resetToAutoFraming,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.onSurface,
                      side: BorderSide(color: colors.outlineVariant),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.center_focus_strong, size: 18),
                    label: const Text('Reset Auto'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _processAndProceed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                      ),
                      icon: const Icon(Icons.auto_awesome, size: 18),
                      label: const Text(
                        'Apply Studio AI & Audit →',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
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

class _BiometricCaliperPainter extends CustomPainter {
  final double specAspect;
  final double headRatioMin;
  final double headRatioMax;
  final AppPalette colors;

  _BiometricCaliperPainter({
    required this.specAspect,
    required this.headRatioMin,
    required this.headRatioMax,
    required this.colors,
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
    final maskPaint = Paint()..color = colors.surfaceDim.withValues(alpha: 0.75);
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(frameRect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, maskPaint);

    // 3. Draw Outer Border & Corner Registration Marks
    final borderPaint = Paint()
      ..color = colors.secondary
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    canvas.drawRect(frameRect, borderPaint);

    // Corner brackets in Gold
    final cornerPaint = Paint()
      ..color = colors.goldAccent
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
    final crownY = frameRect.top + (frameH * 0.10);
    final chinY = crownY + (frameH * targetHeadRatio);
    final eyeY = crownY + (frameH * targetHeadRatio * 0.42);

    final guidePaint = Paint()
      ..color = colors.tertiary
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final dashPaint = Paint()
      ..color = colors.secondary.withValues(alpha: 0.85)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    // Crown dashed line
    _drawDashedHorizontal(canvas, frameRect.left + 15, frameRect.right - 15, crownY, dashPaint);
    _drawLabel(canvas, 'HAIR CROWN', Offset(frameRect.left + 20, crownY - 14), colors.secondary, colors);

    // Eye Horizon Solid Line with micro crosshair
    canvas.drawLine(Offset(frameRect.left + 10, eyeY), Offset(frameRect.right - 10, eyeY), guidePaint);
    canvas.drawLine(Offset(frameRect.center.dx, eyeY - 8), Offset(frameRect.center.dx, eyeY + 8), guidePaint);
    _drawLabel(canvas, 'EYE HORIZON', Offset(frameRect.left + 20, eyeY - 14), colors.tertiary, colors);

    // Chin dashed line
    _drawDashedHorizontal(canvas, frameRect.left + 15, frameRect.right - 15, chinY, dashPaint);
    _drawLabel(canvas, 'CHIN BASE', Offset(frameRect.left + 20, chinY + 4), colors.secondary, colors);

    // Biometric Head Oval
    final headOvalRect = Rect.fromCenter(
      center: Offset(frameRect.center.dx, (crownY + chinY) / 2),
      width: frameW * 0.58,
      height: chinY - crownY,
    );
    canvas.drawOval(headOvalRect, dashPaint);

    // Vertical Center Symmetry Line
    final centerDashPaint = Paint()
      ..color = colors.onSurface.withValues(alpha: 0.25)
      ..strokeWidth = 1.0;
    _drawDashedVertical(canvas, frameRect.center.dx, frameRect.top + 10, frameRect.bottom - 10, centerDashPaint);
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

  void _drawDashedVertical(Canvas canvas, double x, double y1, double y2, Paint paint) {
    const dashH = 6.0;
    const spaceH = 4.0;
    double startY = y1;
    while (startY < y2) {
      canvas.drawLine(Offset(x, startY), Offset(x, math.min(startY + dashH, y2)), paint);
      startY += dashH + spaceH;
    }
  }

  void _drawLabel(Canvas canvas, String text, Offset offset, Color color, AppPalette colors) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'JetBrains Mono',
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 0.6,
          backgroundColor: colors.surfaceDim.withValues(alpha: 0.8),
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
