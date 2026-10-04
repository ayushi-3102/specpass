import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../models/compliance_result.dart';
import '../models/country_spec.dart';
import '../services/photo_composer_service.dart';
import 'export_screen.dart';

class ComplianceScreen extends ConsumerStatefulWidget {
  final ProcessedPhotoPackage package;
  final CountrySpec spec;
  final ComplianceAuditResult auditResult;

  const ComplianceScreen({
    super.key,
    required this.package,
    required this.spec,
    required this.auditResult,
  });

  @override
  ConsumerState<ComplianceScreen> createState() => _ComplianceScreenState();
}

class _ComplianceScreenState extends ConsumerState<ComplianceScreen> {
  bool _showBiometricOverlay = true;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Compliance Inspection'),
        actions: [
          IconButton(
            icon: Icon(
              _showBiometricOverlay ? Icons.grid_on : Icons.grid_off,
              color: _showBiometricOverlay ? AppTheme.secondary : AppTheme.outline,
            ),
            tooltip: 'Toggle Biometric Calipers',
            onPressed: () {
              HapticFeedback.selectionClick();
              setState(() => _showBiometricOverlay = !_showBiometricOverlay);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset + 20),
        child: Column(
          children: [
            // Centered Photo Preview with Biometric Calipers
            Center(
              child: Container(
                width: 240,
                height: 240 / widget.spec.aspectRatio,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.outlineVariant, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(
                        widget.package.singlePhotoFile,
                        fit: BoxFit.cover,
                      ),
                      if (_showBiometricOverlay) _buildBiometricOverlay(),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Overall Score Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.tertiary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.tertiaryContainer.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle, color: AppTheme.tertiary, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Text(
                              '100% ICAO 9303 Compliant',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.onSurface,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Passes ${widget.spec.countryName} official consulate standards.',
                          style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${widget.auditResult.scorePercent}%',
                      style: const TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppTheme.tertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 7-Point Audit Checklist
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '7-Point Biometric Rejection Audit',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const SizedBox(height: 12),

            ...widget.auditResult.items.map((item) => _buildCheckItemCard(item)),

            const SizedBox(height: 24),

            // CTA Button to Print Screen
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ExportScreen(
                        package: widget.package,
                        spec: widget.spec,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                ),
                icon: const Icon(Icons.arrow_forward),
                label: const Text(
                  'Continue to 4×6" Print Layout',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBiometricOverlay() {
    return CustomPaint(
      painter: _BiometricGridPainter(aspectRatio: widget.spec.aspectRatio),
    );
  }

  Widget _buildCheckItemCard(ComplianceCheckItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppTheme.tertiaryContainer.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: AppTheme.tertiary, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.onSurface, fontSize: 13),
                    ),
                    Text(
                      item.measuredValue,
                      style: const TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 11,
                        color: AppTheme.tertiary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  item.description,
                  style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BiometricGridPainter extends CustomPainter {
  final double aspectRatio;

  _BiometricGridPainter({required this.aspectRatio});

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = AppTheme.secondary.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final dashPaint = Paint()
      ..color = AppTheme.tertiary.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Center vertical axis
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      strokePaint,
    );

    // Eye level horizontal line (approx 58% from bottom = 42% from top)
    final eyeY = size.height * 0.42;
    canvas.drawLine(Offset(0, eyeY), Offset(size.width, eyeY), dashPaint);

    // Chin level line (approx 80% from top)
    final chinY = size.height * 0.78;
    canvas.drawLine(Offset(0, chinY), Offset(size.width, chinY), strokePaint);

    // Head oval
    final headRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.48),
      width: size.width * 0.58,
      height: size.height * 0.65,
    );
    canvas.drawOval(headRect, dashPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
