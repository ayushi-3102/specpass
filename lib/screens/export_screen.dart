import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
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
          files: [XFile(widget.package.printSheetFile.path)],
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
          files: [XFile(widget.package.singlePhotoFile.path)],
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

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final isPro = ref.watch(proStatusProvider);

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
                  child: Image.file(
                    widget.package.printSheetFile,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Pharmacy Cost Savings Banner
            Container(
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
                          'Print this as a standard 4×6" photo at Walgreens, CVS, or Walmart for ~35¢. Select "Actual Size (100%)".',
                          style: TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
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
                  'Export 4×6" Print Sheet (${widget.package.photosOnSheet} Photos)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
            const SizedBox(height: 12),

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
                label: const Text(
                  'Export Single Digital Photo (For Online Portal)',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
