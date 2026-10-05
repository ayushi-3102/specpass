import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../core/localization.dart';
import '../core/theme.dart';
import '../models/country_spec.dart';
import '../providers/app_providers.dart';
import '../services/photo_composer_service.dart';
import 'paywall_modal.dart';

class ExportScreen extends ConsumerStatefulWidget {
  final ProcessedPhotoPackage package;
  final CountrySpec spec;

  const ExportScreen({
    super.key,
    required this.package,
    required this.spec,
  });

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  bool _isSaving = false;

  Future<void> _handleSavePrintSheet() async {
    final isPro = ref.read(proStatusProvider);
    if (!isPro) {
      final unlocked = await PaywallModal.show(context);
      if (unlocked != true) return;
    }

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      // Share 4x6 sheet
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              widget.package.printSheetBytes,
              mimeType: 'image/jpeg',
              name: 'specpass_4x6_print_sheet.jpg',
            ),
          ],
          text: 'SpecPass 4x6" Print Sheet (${widget.spec.countryName} - ${widget.spec.formattedDimensions})',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving sheet: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleSaveSinglePhoto() async {
    final isPro = ref.read(proStatusProvider);
    if (!isPro) {
      final unlocked = await PaywallModal.show(context);
      if (unlocked != true) return;
    }

    setState(() => _isSaving = true);
    HapticFeedback.lightImpact();

    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              widget.package.singlePhotoBytes,
              mimeType: 'image/jpeg',
              name: 'specpass_passport_photo.jpg',
            ),
          ],
          text: 'SpecPass Digital Photo (${widget.spec.countryName} - ${widget.spec.formattedDimensions})',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing photo: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleSaveDigitalPortalPhoto() async {
    final isPro = ref.read(proStatusProvider);
    if (!isPro) {
      final unlocked = await PaywallModal.show(context);
      if (unlocked != true) return;
    }

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              widget.package.digitalPortalBytes,
              mimeType: 'image/jpeg',
              name: 'specpass_online_visa_ds160.jpg',
            ),
          ],
          text: 'SpecPass Online Visa Digital Photo (DS-160 / E-Visa Portal Compliant)',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving digital portal photo: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleSavePdf() async {
    final isPro = ref.read(proStatusProvider);
    if (!isPro) {
      final unlocked = await PaywallModal.show(context);
      if (unlocked != true) return;
    }

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      final pdfBytes = await PhotoComposerService.generatePrintablePdf(
        printSheetBytes: widget.package.printSheetBytes,
        spec: widget.spec,
      );

      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              pdfBytes,
              mimeType: 'application/pdf',
              name: 'specpass_${widget.spec.countryCode.toLowerCase()}_biometric.pdf',
            ),
          ],
          text: 'SpecPass Biometric Printable PDF (A4 & 10×15 cm / 4×6" Sheet)',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating PDF: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final isPro = ref.watch(proStatusProvider);
    final lang = ref.watch(appLanguageProvider);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Export & Print Layout'),
        actions: [
          if (isPro)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.tertiaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.tertiary.withValues(alpha: 0.5)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified, size: 14, color: AppTheme.tertiary),
                  SizedBox(width: 4),
                  Text(
                    'PRO UNLOCKED',
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.tertiary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 16, 20, math.max(bottomInset, 16) + 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Top Status Chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.outlineVariant),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.spec.flagEmoji, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.spec.countryName} • ${widget.spec.formattedDimensions}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppTheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceBright,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '300 DPI',
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.secondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Photorealistic 4x6" Sheet Card Preview
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.7),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AspectRatio(
                  aspectRatio: 1200 / 1800, // 4:6 aspect ratio
                  child: Image.memory(
                    widget.package.printSheetBytes,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Localized dm / Rossmann / Pharmacy Print Instructions
            _buildKioskGuide(context, lang),
            const SizedBox(height: 24),

            // Action Buttons
            // 1. Export Printable PDF (A4 & 10×15 cm)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _handleSavePdf,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.tertiary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
                icon: const Icon(Icons.picture_as_pdf),
                label: Text(
                  AppStrings.get('export_pdf', lang),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 2. Export 4x6" / 10x15 cm Print Sheet
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _handleSavePrintSheet,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
                icon: const Icon(Icons.print),
                label: Text(
                  '${AppStrings.get('export_sheet', lang)} (${widget.package.photosOnSheet} Photos)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 3. Export for Online Visa (DS-160 / E-Visa Portal)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _handleSaveDigitalPortalPhoto,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.surfaceContainerHigh,
                  foregroundColor: AppTheme.onSurface,
                  side: const BorderSide(color: AppTheme.secondary, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.cloud_upload_outlined, color: AppTheme.secondary),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Online Visa (DS-160 / E-Visa)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${widget.package.digitalPortalKb} KB • 600px',
                        style: const TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.secondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 4. Export High-Res Single Photo
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _isSaving ? null : _handleSaveSinglePhoto,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.onSurface,
                  side: const BorderSide(color: AppTheme.outlineVariant),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.download, size: 18),
                label: Text(
                  AppStrings.get('export_single', lang),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKioskGuide(BuildContext context, String lang) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.tertiary.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.tertiaryContainer.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.savings, color: AppTheme.tertiary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Pharmacy Kiosk Printing Secret',
                          style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.onSurface, fontSize: 13),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.tertiaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Save ~95%',
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              color: AppTheme.tertiary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Pay ~25¢ instead of \$16.99 (US) or 0,27€ instead of 7,95€ (Germany)',
                      style: TextStyle(fontSize: 11, color: AppTheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: AppTheme.outlineVariant, height: 1),
          const SizedBox(height: 10),
          _buildGuideStep('1', 'At the photo kiosk (dm, Rossmann, Walgreens, CVS), select "Standard 4×6" (10×15 cm) Photo Print".'),
          const SizedBox(height: 6),
          _buildGuideStep('2', 'IMPORTANT: Do NOT select "Passport Photo"! Standard prints cost only ~25¢; passport option costs \$15+.', isWarning: true),
          const SizedBox(height: 6),
          _buildGuideStep('3', 'Select "Actual Size (100% scale)" / "Ohne Rand". Do not fit or stretch.'),
          const SizedBox(height: 6),
          _buildGuideStep('4', 'Use scissors to cut along the dashed guidelines and corner crosshairs.'),
        ],
      ),
    );
  }

  Widget _buildGuideStep(String number, String text, {bool isWarning = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 18,
          height: 18,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isWarning ? AppTheme.warningContainer : AppTheme.surfaceContainerHigh,
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isWarning ? AppTheme.warning : AppTheme.onSurface,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isWarning ? FontWeight.w600 : FontWeight.normal,
              color: isWarning ? AppTheme.warning : AppTheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
