import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../models/compliance_result.dart';
import '../models/country_spec.dart';
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

  @override
  void initState() {
    super.initState();
    _autoFitInitial();
  }

  void _autoFitInitial() {
    _transformController.value = Matrix4.identity();
    setState(() {
      _rotationDegrees = 0.0;
    });
  }

  Future<void> _processAndProceed() async {
    if (_isProcessing) return;
    HapticFeedback.heavyImpact();

    setState(() => _isProcessing = true);

    try {
      final package = await PhotoComposerService.processPhotoBytes(
        rawBytes: widget.rawBytes,
        spec: widget.spec,
        rotationDegrees: _rotationDegrees,
      );

      final audit = ComplianceAuditResult.mockPassingResult(
        headRatio: (widget.spec.headRatioMin + widget.spec.headRatioMax) / 2.0,
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
            rawBytes: widget.rawBytes,
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

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final double specAspect = widget.spec.widthMm / widget.spec.heightMm;

    return Scaffold(
      backgroundColor: AppTheme.surfaceDim,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceContainerLowest,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.onSurface, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            const Text(
              'Biometric Caliper Alignment',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              '${widget.spec.countryName} • ${widget.spec.formattedDimensions}',
              style: const TextStyle(fontSize: 11, color: AppTheme.secondary, fontFamily: 'JetBrains Mono'),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt, color: AppTheme.onSurface),
            tooltip: 'Reset Framing',
            onPressed: () {
              HapticFeedback.selectionClick();
              _autoFitInitial();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Status Instruction Banner
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerHigh.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.outlineVariant),
              ),
              child: Row(
                children: [
                  const Icon(Icons.touch_app, size: 18, color: AppTheme.tertiary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Pinch to zoom & drag your face between the Crown and Chin guidelines.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade300, height: 1.2),
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
                    color: Colors.black,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Interactive Image Canvas
                        InteractiveViewer(
                          transformationController: _transformController,
                          minScale: 0.5,
                          maxScale: 4.0,
                          boundaryMargin: const EdgeInsets.all(300),
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
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return CustomPaint(
                                size: Size(constraints.maxWidth, constraints.maxHeight),
                                painter: _BiometricCaliperPainter(
                                  specAspect: specAspect,
                                  headRatioMin: widget.spec.headRatioMin,
                                  headRatioMax: widget.spec.headRatioMax,
                                ),
                              );
                            },
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
                                    'Applying Studio Background & Consular Sizing...',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
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

            // Rotation / Tilt Slider Control
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.rotate_90_degrees_ccw, size: 18, color: AppTheme.outline),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: AppTheme.secondary,
                        inactiveTrackColor: AppTheme.surfaceContainerHighest,
                        thumbColor: AppTheme.secondary,
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
                      style: const TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.secondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Action Bar
            Container(
              padding: EdgeInsets.fromLTRB(20, 10, 20, bottomInset + 14),
              decoration: const BoxDecoration(
                color: AppTheme.surfaceContainerLowest,
                border: Border(top: BorderSide(color: AppTheme.outlineVariant, width: 1)),
              ),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      _autoFitInitial();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.onSurface,
                      side: const BorderSide(color: AppTheme.outlineVariant),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.center_focus_strong, size: 18),
                    label: const Text('Auto-Fit'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _processAndProceed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
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

  _BiometricCaliperPainter({
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
    final maskPaint = Paint()..color = Colors.black.withValues(alpha: 0.65);
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(frameRect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, maskPaint);

    // 3. Draw Outer Border & Corner Registration Marks
    final borderPaint = Paint()
      ..color = AppTheme.secondary
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    canvas.drawRect(frameRect, borderPaint);

    // Corner brackets
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
    _drawLabel(canvas, 'HAIR CROWN', Offset(frameRect.left + 20, crownY - 14), AppTheme.secondary);

    // Eye Horizon Solid Line with micro crosshair
    canvas.drawLine(Offset(frameRect.left + 10, eyeY), Offset(frameRect.right - 10, eyeY), guidePaint);
    canvas.drawLine(Offset(frameRect.center.dx, eyeY - 8), Offset(frameRect.center.dx, eyeY + 8), guidePaint);
    _drawLabel(canvas, 'EYE HORIZON', Offset(frameRect.left + 20, eyeY - 14), AppTheme.tertiary);

    // Chin dashed line
    _drawDashedHorizontal(canvas, frameRect.left + 15, frameRect.right - 15, chinY, dashPaint);
    _drawLabel(canvas, 'CHIN BASE', Offset(frameRect.left + 20, chinY + 4), AppTheme.secondary);

    // Biometric Head Oval
    final headOvalRect = Rect.fromCenter(
      center: Offset(frameRect.center.dx, (crownY + chinY) / 2),
      width: frameW * 0.58,
      height: chinY - crownY,
    );
    canvas.drawOval(headOvalRect, dashPaint);

    // Vertical Center Symmetry Line
    final centerDashPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
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

  void _drawLabel(Canvas canvas, String text, Offset offset, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'JetBrains Mono',
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 0.6,
          backgroundColor: Colors.black.withValues(alpha: 0.6),
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
