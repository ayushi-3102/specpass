import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../providers/app_providers.dart';
import 'legal_screen.dart';

class PaywallModal extends ConsumerStatefulWidget {
  const PaywallModal({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const PaywallModal(),
    );
  }

  @override
  ConsumerState<PaywallModal> createState() => _PaywallModalState();
}

class _PaywallModalState extends ConsumerState<PaywallModal> {
  bool _isLoading = false;

  Future<void> _handlePurchase() async {
    setState(() => _isLoading = true);
    HapticFeedback.heavyImpact();

    try {
      final success = await ref.read(proStatusProvider.notifier).purchaseLifetime();
      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.tertiary,
            content: Text('🎉 SpecPass Pro Lifetime Unlocked!'),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.error,
          content: Text('Purchase could not be completed: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRestore() async {
    setState(() => _isLoading = true);
    HapticFeedback.lightImpact();

    try {
      final success = await ref.read(proStatusProvider.notifier).restore();
      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.tertiary,
            content: Text('Purchases restored successfully!'),
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No previous active purchases found on this account.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final colors = AppTheme.colors(context);

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: colors.outlineVariant, width: 1),
        ),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, math.max(bottomInset, 16) + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Pull handle & close button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 32),
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.surfaceBright,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: colors.onSurfaceVariant),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Identity Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colors.outlineVariant),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_open, size: 14, color: colors.secondary),
                  const SizedBox(width: 6),
                  Text(
                    'SPECPASS PRO • LIFETIME',
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: colors.primary,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Editorial Headline
            Text(
              'Skip the Pharmacy & Photo Booth Trip',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Official government-accepted photos generated in seconds right from your home.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),

            // Bento Box Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surfaceContainer,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colors.outlineVariant),
              ),
              child: Column(
                children: [
                  // 4x6 Pharmacy Callout
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 34,
                          decoration: BoxDecoration(
                            color: colors.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: colors.outlineVariant),
                          ),
                          child: Icon(Icons.print, color: colors.secondary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Print-Ready 4×6" (10×15 cm) Template',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: colors.onSurface,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                'DM • ROSSMANN • CVS • WALGREENS • ONLY ~25¢',
                                style: TextStyle(
                                  fontFamily: 'JetBrains Mono',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: colors.secondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: colors.tertiaryContainer.withValues(alpha: colors.isDark ? 0.4 : 0.8),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'SAVES ~\$15+',
                            style: TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: colors.tertiary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildFeatureRow(
                    colors: colors,
                    icon: Icons.verified,
                    title: 'Unlimited 300 DPI Exports',
                    subtitle: 'Lossless, uncompressed biometrics for direct consular upload.',
                  ),
                  const SizedBox(height: 12),
                  _buildFeatureRow(
                    colors: colors,
                    icon: Icons.public,
                    title: 'All 140+ Country Standards',
                    subtitle: 'Full access to US, EU Schengen, UK, Canada, India, and more.',
                  ),
                  const SizedBox(height: 12),
                  _buildFeatureRow(
                    colors: colors,
                    icon: Icons.shield,
                    title: '100% On-Device & Private',
                    subtitle: 'Your facial biometrics never leave your physical device.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Price Box (€6.99 / $6.99)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.primary.withValues(alpha: 0.5), width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '6,99 € / \$6.99 Lifetime Access',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Pay once. Own forever for whole family. No subscriptions.',
                        style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                  Icon(Icons.check_circle, color: colors.tertiary, size: 24),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Primary Unlock Button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handlePurchase,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Text(
                        'Unlock Lifetime Access — 6,99 € / \$6.99',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const SizedBox(height: 14),

            // Restore & Legal Links
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: _isLoading ? null : _handleRestore,
                  child: Text('Restore Purchases', style: TextStyle(color: colors.secondary, fontSize: 13)),
                ),
                Text('•', style: TextStyle(color: colors.outline)),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LegalScreen(initialDoc: LegalDocType.terms),
                      ),
                    );
                  },
                  child: Text('Terms of Use', style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13)),
                ),
                Text('•', style: TextStyle(color: colors.outline)),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LegalScreen(initialDoc: LegalDocType.privacy),
                      ),
                    );
                  },
                  child: Text('Privacy Policy', style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow({
    required AppPalette colors,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: colors.primaryContainer.withValues(alpha: colors.isDark ? 0.5 : 0.8),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: colors.secondary, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
