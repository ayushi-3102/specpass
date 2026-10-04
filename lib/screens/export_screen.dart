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
        padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 24),
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

            // 3. Export Single Photo
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
    final isGermanyOrEu = widget.spec.countryCode == 'DE' || widget.spec.id == 'EU_SCHENGEN' || lang == 'de';
    if (isGermanyOrEu) {
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
                  child: const Icon(Icons.storefront, color: AppTheme.tertiary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'dm & Rossmann Fotostation',
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
                              '~0,27 €',
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
                        'Sparen Sie bis zu 95% gegenüber 7,95 € Passbild-Gebühr',
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
            _buildGuideStep('1', 'Am dm-Fototerminal: "Foto sofort drucken" ➔ 10×15 cm wählen.'),
            const SizedBox(height: 6),
            _buildGuideStep('2', 'WICHTIG: NICHT "Passfoto" (7,95 €) wählen! Standard-Foto kostet nur ca. 0,27 €.', isWarning: true),
            const SizedBox(height: 6),
            _buildGuideStep('3', 'Bildformat "10×15 cm" und Option "Ohne Rand (100% Originalgröße)" auswählen.'),
            const SizedBox(height: 6),
            _buildGuideStep('4', 'Am Schneidetisch des Marktes entlang der feinen Schnittmarken zuschneiden.'),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.tertiaryContainer.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.savings, color: AppTheme.tertiary, size: 22),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pharmacy Print Instructions',
                    style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.onSurface),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Print this as a standard 4×6" photo at Walgreens, CVS, or Walmart for ~35¢. Select "Actual Size (100%)". Do NOT select "Passport Photo" (\$16.99).',
                    style: TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
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
