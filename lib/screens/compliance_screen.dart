import 'dart:math' as math;
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
  int _viewMode = 0; // 0 = Split Slider, 1 = Biometric Only, 2 = Original Only
  double _splitRatio = 0.50; // Draggable slider position (0.0 to 1.0)
  double _sensitivity = 1.0;
  double _brightness = 0.0;
  double _contrast = 1.0;
  String _formalAttire = 'none';
  bool _isBabyMode = false;

  final List<Map<String, String>> _bgOptions = [
    {'name': 'Pure White', 'hex': '#FFFFFF', 'subtitle': 'US, Schengen, India'},
    {'name': 'Original Wall', 'hex': 'original', 'subtitle': 'Preserve Real Wall'},
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
    _brightness = widget.package.brightness;
    _contrast = widget.package.contrast;
    _formalAttire = widget.package.formalAttire;
    _isBabyMode = widget.package.isBabyMode;
  }

  Future<void> _reprocessPhoto({
    String? hex,
    double? sensitivity,
    double? brightness,
    double? contrast,
    String? formalAttire,
    bool? isBabyMode,
  }) async {
    final targetHex = hex ?? _activeBgHex;
    final targetSens = sensitivity ?? _sensitivity;
    final targetBright = brightness ?? _brightness;
    final targetContrast = contrast ?? _contrast;
    final targetAttire = formalAttire ?? _formalAttire;
    final targetBaby = isBabyMode ?? _isBabyMode;

    HapticFeedback.selectionClick();

    setState(() {
      _isRecomputing = true;
      _activeBgHex = targetHex;
      _sensitivity = targetSens;
      _brightness = targetBright;
      _contrast = targetContrast;
      _formalAttire = targetAttire;
      _isBabyMode = targetBaby;
    });

    try {
      final updated = await PhotoComposerService.processPhotoBytes(
        rawBytes: widget.rawBytes,
        spec: widget.spec,
        overrideBgHex: targetHex,
        sensitivity: targetSens,
        brightness: targetBright,
        contrast: targetContrast,
        formalAttire: targetAttire,
        isBabyMode: targetBaby,
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
          SnackBar(content: Text('Error updating photo: $e')),
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
            // 3-Mode View Toggle: Split Slider, Biometric Result, Raw Original
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
                  _buildModeToggleButton(
                    modeIndex: 0,
                    icon: Icons.compare,
                    label: 'Split Wipe',
                  ),
                  _buildModeToggleButton(
                    modeIndex: 1,
                    icon: Icons.auto_fix_high,
                    label: 'Biometric',
                  ),
                  _buildModeToggleButton(
                    modeIndex: 2,
                    icon: Icons.photo,
                    label: 'Original',
                  ),
                ],
              ),
            ),

            // Draggable Before/After Split Slider or Dedicated View
            Center(
              child: Container(
                width: 240,
                height: 240 / widget.spec.aspectRatio,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _viewMode == 0 ? AppTheme.secondary.withValues(alpha: 0.6) : AppTheme.outlineVariant,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _viewMode == 0
                          ? AppTheme.secondary.withValues(alpha: 0.15)
                          : Colors.black.withValues(alpha: 0.5),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_viewMode == 0) ...[
                        // Split Wipe Mode:
                        // Bottom Layer: Biometric Compliant Output
                        Image.memory(
                          _currentPackage.singlePhotoBytes,
                          fit: BoxFit.cover,
                        ),
                        if (_showBiometricOverlay) _buildBiometricOverlay(),

                        // Top Layer: Raw Capture clipped to left side by _splitRatio
                        ClipRect(
                          clipper: _SplitRectClipper(splitRatio: _splitRatio),
                          child: Image.memory(
                            widget.rawBytes,
                            fit: BoxFit.cover,
                          ),
                        ),

                        // Glowing Neon Divider Line
                        Positioned(
                          left: (240 * _splitRatio) - 1.5,
                          top: 0,
                          bottom: 0,
                          child: Container(
                            width: 3,
                            decoration: BoxDecoration(
                              color: AppTheme.secondary,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.secondary.withValues(alpha: 0.8),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Interactive Slider Touch Knob
                        Positioned(
                          left: (240 * _splitRatio) - 16,
                          top: ((240 / widget.spec.aspectRatio) / 2) - 16,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceContainerHighest,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppTheme.secondary, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.compare_arrows,
                                size: 18,
                                color: AppTheme.secondary,
                              ),
                            ),
                          ),
                        ),

                        // Interactive Drag & Tap Detector
                        GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onHorizontalDragUpdate: (details) {
                            setState(() {
                              _splitRatio = (details.localPosition.dx / 240).clamp(0.04, 0.96);
                            });
                          },
                          onTapDown: (details) {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _splitRatio = (details.localPosition.dx / 240).clamp(0.04, 0.96);
                            });
                          },
                        ),

                        // Top Labels: Raw vs Biometric
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'RAW',
                              style: TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'BIOMETRIC',
                              style: TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.secondary,
                              ),
                            ),
                          ),
                        ),

                        // Bottom Guidance Pill
                        Positioned(
                          bottom: 8,
                          left: 8,
                          right: 8,
                          child: IgnorePointer(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                '↔ DRAG SLIDER TO INSPECT RETOUCHING',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'JetBrains Mono',
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.secondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ] else if (_viewMode == 1) ...[
                        // Biometric Output Only
                        Image.memory(
                          _currentPackage.singlePhotoBytes,
                          fit: BoxFit.cover,
                        ),
                        if (_showBiometricOverlay) _buildBiometricOverlay(),
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
                            child: const Text(
                              'SOLID WHITE BG REPLACED • ICAO 9303',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.tertiary,
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        // Original Raw Capture Only
                        Image.memory(
                          widget.rawBytes,
                          fit: BoxFit.cover,
                        ),
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
                            child: const Text(
                              'RAW CAPTURE (UNEDITED)',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber,
                              ),
                            ),
                          ),
                        ),
                      ],

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
                        _activeBgHex == 'original'
                            ? 'ORIGINAL WALL (NATURAL)'
                            : 'Active: ${_activeBgHex.toUpperCase()}',
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
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _bgOptions.map((opt) {
                        final isSelected = opt['hex'] == _activeBgHex;
                        final bool isOriginal = opt['hex'] == 'original';
                        final Color displayColor = isOriginal
                            ? const Color(0xFF64748B)
                            : _hexToColor(opt['hex']!);

                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
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
                                  if (isOriginal)
                                    const Icon(Icons.wallpaper, size: 14, color: Color(0xFF94A3B8))
                                  else
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
                          ),
                        );
                      }).toList(),
                    ),
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
                            onTap: () => _reprocessPhoto(sensitivity: 0.7),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _sensitivity == 0.7 ? AppTheme.surfaceContainerHigh : AppTheme.surfaceContainerLowest,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _sensitivity == 0.7 ? AppTheme.secondary : AppTheme.outlineVariant,
                                ),
                              ),
                              child: Text(
                                'Subtle / Safe',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: _sensitivity == 0.7 ? FontWeight.bold : FontWeight.normal,
                                  color: _sensitivity == 0.7 ? AppTheme.secondary : AppTheme.outline,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
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
                          const SizedBox(width: 5),
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
                                'Deep Cleanse',
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
            const SizedBox(height: 12),

            // Studio Lighting & Exposure Controls (Auto-Enhance, Brightness, Contrast)
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
                      const Row(
                        children: [
                          Icon(Icons.tune, size: 16, color: AppTheme.secondary),
                          SizedBox(width: 6),
                          Text(
                            'Studio Lighting & Enhancements',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.onSurface),
                          ),
                        ],
                      ),
                      // 1-Tap Auto-Enhance Button
                      GestureDetector(
                        onTap: () {
                          _reprocessPhoto(brightness: 0.08, contrast: 1.15);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppTheme.primary, AppTheme.secondary],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.auto_awesome, size: 12, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                'Auto-Enhance',
                                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Brightness Slider
                  Row(
                    children: [
                      const Icon(Icons.brightness_6, size: 14, color: AppTheme.outline),
                      const SizedBox(width: 8),
                      const Text('Brightness', style: TextStyle(fontSize: 11, color: AppTheme.onSurfaceVariant)),
                      Expanded(
                        child: Slider(
                          value: _brightness,
                          min: -0.30,
                          max: 0.30,
                          divisions: 12,
                          activeColor: AppTheme.primary,
                          inactiveColor: AppTheme.surfaceContainerHighest,
                          onChanged: (val) {
                            setState(() => _brightness = val);
                          },
                          onChangeEnd: (val) {
                            _reprocessPhoto(brightness: val);
                          },
                        ),
                      ),
                      Text(
                        '${(_brightness * 100).toInt()}%',
                        style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 10, color: AppTheme.outline),
                      ),
                    ],
                  ),

                  // Contrast Slider
                  Row(
                    children: [
                      const Icon(Icons.contrast, size: 14, color: AppTheme.outline),
                      const SizedBox(width: 8),
                      const Text('Contrast', style: TextStyle(fontSize: 11, color: AppTheme.onSurfaceVariant)),
                      Expanded(
                        child: Slider(
                          value: _contrast,
                          min: 0.70,
                          max: 1.30,
                          divisions: 12,
                          activeColor: AppTheme.secondary,
                          inactiveColor: AppTheme.surfaceContainerHighest,
                          onChanged: (val) {
                            setState(() => _contrast = val);
                          },
                          onChangeEnd: (val) {
                            _reprocessPhoto(contrast: val);
                          },
                        ),
                      ),
                      Text(
                        '${((_contrast - 1.0) * 100).toInt()}%',
                        style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 10, color: AppTheme.outline),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Virtual Formal Attire & Baby Mode Row
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
                  // Formal Attire Selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Virtual Formal Attire',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.onSurface),
                      ),
                      Row(
                        children: [
                          _buildAttireChip('None', 'none'),
                          const SizedBox(width: 6),
                          _buildAttireChip('👔 Navy Blazer', 'navy_suit'),
                          const SizedBox(width: 6),
                          _buildAttireChip('🤵 Charcoal Suit', 'charcoal_suit'),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: AppTheme.outlineVariant, height: 1),
                  const SizedBox(height: 10),

                  // Baby & Infant Mode Switch
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('👶 ', style: TextStyle(fontSize: 14)),
                              Text(
                                'Infant & Toddler Mode',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.onSurface),
                              ),
                            ],
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Applies relaxed ICAO 9303 child exemptions (infants < 1 yr)',
                            style: TextStyle(fontSize: 10, color: AppTheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                      Switch(
                        value: _isBabyMode,
                        activeThumbColor: AppTheme.tertiary,
                        onChanged: (val) {
                          _reprocessPhoto(isBabyMode: val);
                        },
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
                  // Holographic Radial Sweep Gauge
                  SizedBox(
                    width: 58,
                    height: 58,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: const Size(58, 58),
                          painter: _RadialComplianceGaugePainter(
                            scorePercent: widget.auditResult.scorePercent.toDouble(),
                          ),
                        ),
                        Text(
                          '${widget.auditResult.scorePercent}%',
                          style: const TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.tertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Consular Certified',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.onSurface,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.tertiary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'ICAO 9303',
                                style: TextStyle(
                                  fontFamily: 'JetBrains Mono',
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.tertiary,
                                ),
                              ),
                            ),
                          ],
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
                      color: AppTheme.tertiary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.tertiary.withValues(alpha: 0.4)),
                    ),
                    child: const Text(
                      'PASS',
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
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

  Widget _buildModeToggleButton({
    required int modeIndex,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _viewMode == modeIndex;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _viewMode = modeIndex);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? Colors.white : AppTheme.outline,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : AppTheme.outline,
              ),
            ),
          ],
        ),
      ),
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

  Widget _buildAttireChip(String label, String style) {
    final isSelected = _formalAttire == style;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _reprocessPhoto(formalAttire: style);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryContainer : AppTheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.outlineVariant,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : AppTheme.onSurfaceVariant,
          ),
        ),
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

class _SplitRectClipper extends CustomClipper<Rect> {
  final double splitRatio;

  _SplitRectClipper({required this.splitRatio});

  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(0, 0, size.width * splitRatio, size.height);
  }

  @override
  bool shouldReclip(covariant _SplitRectClipper oldClipper) => oldClipper.splitRatio != splitRatio;
}

class _RadialComplianceGaugePainter extends CustomPainter {
  final double scorePercent;

  _RadialComplianceGaugePainter({required this.scorePercent});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    // Track ring
    final trackPaint = Paint()
      ..color = AppTheme.surfaceContainerHighest
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0;
    canvas.drawCircle(center, radius, trackPaint);

    // Active arc
    final sweepAngle = (scorePercent / 100.0) * 2 * math.pi;
    final arcPaint = Paint()
      ..shader = const SweepGradient(
        colors: [AppTheme.secondary, AppTheme.tertiary, AppTheme.secondary],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 6.0;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RadialComplianceGaugePainter oldDelegate) =>
      oldDelegate.scorePercent != scorePercent;
}
