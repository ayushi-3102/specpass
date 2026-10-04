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
  final Uint8List rawBytes;

  const ComplianceScreen({
    super.key,
    required this.package,
    required this.spec,
    required this.auditResult,
    required this.rawBytes,
  });

  @override
  ConsumerState<ComplianceScreen> createState() => _ComplianceScreenState();
}

class _ComplianceScreenState extends ConsumerState<ComplianceScreen> {
  bool _showBiometricOverlay = true;
  late ProcessedPhotoPackage _currentPackage;
  late String _activeBgHex;
  bool _isRecomputing = false;
  bool _showOriginal = false;
  double _sensitivity = 1.0;

  final List<Map<String, String>> _bgOptions = [
    {'name': 'Pure White', 'hex': '#FFFFFF', 'subtitle': 'US, Schengen, India'},
    {'name': 'Light Gray', 'hex': '#F0F0F0', 'subtitle': 'UK, Germany'},
    {'name': 'Off-White', 'hex': '#F8F9FA', 'subtitle': 'Universal ICAO'},
    {'name': 'Sky Blue', 'hex': '#7BD0FF', 'subtitle': 'China, Malaysia'},
  ];

  @override
  void initState() {
    super.initState();
    _currentPackage = widget.package;
    _activeBgHex = widget.package.activeBgHex;
    _sensitivity = widget.package.sensitivity;
  }

  Future<void> _reprocessPhoto({String? hex, double? sensitivity}) async {
    final targetHex = hex ?? _activeBgHex;
    final targetSens = sensitivity ?? _sensitivity;

    if (targetHex == _activeBgHex && targetSens == _sensitivity && !_isRecomputing) return;
    HapticFeedback.selectionClick();

    setState(() {
      _isRecomputing = true;
      _activeBgHex = targetHex;
      _sensitivity = targetSens;
      _showOriginal = false;
    });

    try {
      final updated = await PhotoComposerService.processPhotoBytes(
        rawBytes: widget.rawBytes,
        spec: widget.spec,
        overrideBgHex: targetHex,
        sensitivity: targetSens,
      );

      if (mounted) {
        setState(() {
          _currentPackage = updated;
          _isRecomputing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRecomputing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating background: $e')),
        );
      }
    }
  }

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
            // Before / After View Toggle
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.outlineVariant),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () {
                      if (_showOriginal) {
                        HapticFeedback.selectionClick();
                        setState(() => _showOriginal = false);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: !_showOriginal ? AppTheme.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.auto_fix_high, size: 14, color: !_showOriginal ? Colors.white : AppTheme.outline),
                          const SizedBox(width: 6),
                          Text(
                            'Biometric Compliant',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: !_showOriginal ? Colors.white : AppTheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      if (!_showOriginal) {
                        HapticFeedback.selectionClick();
                        setState(() => _showOriginal = true);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: _showOriginal ? AppTheme.surfaceContainerHigh : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.photo, size: 14, color: _showOriginal ? AppTheme.onSurface : AppTheme.outline),
                          const SizedBox(width: 6),
                          Text(
                            'Original Shot',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _showOriginal ? AppTheme.onSurface : AppTheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

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
                      Image.memory(
                        _showOriginal ? widget.rawBytes : _currentPackage.singlePhotoBytes,
                        fit: BoxFit.cover,
                      ),
                      if (_showBiometricOverlay && !_showOriginal) _buildBiometricOverlay(),
                      
                      // Bottom status pill
                      Positioned(
                        bottom: 8,
                        left: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _showOriginal
                                ? 'RAW CAPTURE (UNEDITED)'
                                : 'SOLID WHITE BG REPLACED • ICAO 9303',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: _showOriginal ? Colors.amber : AppTheme.tertiary,
                            ),
                          ),
                        ),
                      ),

                      if (_isRecomputing)
                        Container(
                          color: Colors.black.withValues(alpha: 0.6),
                          child: const Center(
                            child: CircularProgressIndicator(color: AppTheme.tertiary),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Live Background Color Presets & Cleanse Strength
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Background Color Presets',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: AppTheme.onSurface,
                        ),
                      ),
                      Text(
                        'Active: ${_activeBgHex.toUpperCase()}',
                        style: const TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 10,
                          color: AppTheme.secondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: _bgOptions.map((opt) {
                      final isSelected = opt['hex'] == _activeBgHex;
                      final Color displayColor = _hexToColor(opt['hex']!);

                      return GestureDetector(
                        onTap: () => _reprocessPhoto(hex: opt['hex']!),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.surfaceContainerHigh : AppTheme.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? AppTheme.primary : AppTheme.outlineVariant,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: displayColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.grey, width: 0.5),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                opt['name']!,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected ? AppTheme.onSurface : AppTheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: AppTheme.outlineVariant, height: 1),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Matting Cleanse Level',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.onSurfaceVariant,
                        ),
                      ),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => _reprocessPhoto(sensitivity: 1.0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _sensitivity == 1.0 ? AppTheme.surfaceContainerHigh : AppTheme.surfaceContainerLowest,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _sensitivity == 1.0 ? AppTheme.secondary : AppTheme.outlineVariant,
                                ),
                              ),
                              child: Text(
                                'Balanced',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: _sensitivity == 1.0 ? FontWeight.bold : FontWeight.normal,
                                  color: _sensitivity == 1.0 ? AppTheme.secondary : AppTheme.outline,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => _reprocessPhoto(sensitivity: 1.4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _sensitivity == 1.4 ? AppTheme.surfaceContainerHigh : AppTheme.surfaceContainerLowest,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _sensitivity == 1.4 ? AppTheme.tertiary : AppTheme.outlineVariant,
                                ),
                              ),
                              child: Text(
                                'Deep Cleanse (Wall Shadows)',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: _sensitivity == 1.4 ? FontWeight.bold : FontWeight.normal,
                                  color: _sensitivity == 1.4 ? AppTheme.tertiary : AppTheme.outline,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
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
                        const Text(
                          '100% ICAO 9303 Compliant',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.onSurface,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Background neutralized & proportions verified for ${widget.spec.countryName}.',
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
                        package: _currentPackage,
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

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) {
      return Color(int.parse('FF$hex', radix: 16));
    }
    return Color(int.parse(hex, radix: 16));
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

    // Eye level horizontal line
    final eyeY = size.height * 0.42;
    canvas.drawLine(Offset(0, eyeY), Offset(size.width, eyeY), dashPaint);

    // Chin level line
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
