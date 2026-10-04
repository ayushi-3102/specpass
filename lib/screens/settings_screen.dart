import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../providers/app_providers.dart';
import 'legal_screen.dart';
import 'paywall_modal.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _easterEggCount = 0;

  Future<void> _handleEasterEggTap() async {
    _easterEggCount++;
    HapticFeedback.lightImpact();

    if (_easterEggCount >= 7) {
      _easterEggCount = 0;
      HapticFeedback.heavyImpact();
      final toggled = await ref.read(proStatusProvider.notifier).triggerEasterEggTap();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.primary,
          content: Text(
            toggled ? '🛠️ Developer Override: Pro Mode Toggled!' : 'Developer Mode Reset.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPro = ref.watch(proStatusProvider);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Settings & Standards'),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 24),
        children: [
          // Pro Status Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isPro
                  ? AppTheme.tertiaryContainer.withValues(alpha: 0.3)
                  : AppTheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isPro ? AppTheme.tertiary.withValues(alpha: 0.4) : AppTheme.outlineVariant,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isPro ? AppTheme.tertiaryContainer : AppTheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPro ? Icons.verified : Icons.lock_open,
                    color: isPro ? AppTheme.tertiary : AppTheme.secondary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPro ? 'SpecPass Pro Active' : 'Free Standard Tier',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.onSurface),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isPro
                            ? 'Lifetime access unlocked across all platforms.'
                            : 'Upgrade to export unwatermarked 300 DPI files.',
                        style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (!isPro)
                  ElevatedButton(
                    onPressed: () => PaywallModal.show(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    child: const Text('Upgrade', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Purchases Section
          _buildSectionHeader('PURCHASES & ENTITLEMENTS'),
          _buildSettingsTile(
            icon: Icons.restore,
            title: 'Restore Purchases',
            subtitle: 'Restore previous in-app purchases on this Apple or Google account',
            onTap: () async {
              final restored = await ref.read(proStatusProvider.notifier).restore();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    restored ? 'Purchases restored successfully!' : 'No previous purchases found.',
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),

          // Security & Privacy
          _buildSectionHeader('SOVEREIGN DATA & PRIVACY'),
          _buildSettingsTile(
            icon: Icons.shield,
            title: '100% On-Device Processing',
            subtitle: 'Zero cloud servers. Your facial photos never leave your device.',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LegalScreen(initialDoc: LegalDocType.privacy),
                ),
              );
            },
          ),
          const SizedBox(height: 20),

          // Legal Compliance
          _buildSectionHeader('LEGAL & GOVERNMENT STANDARDS'),
          _buildSettingsTile(
            icon: Icons.description_outlined,
            title: 'Terms of Service & EULA',
            subtitle: 'Official government compliance disclaimer and licensing terms',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LegalScreen(initialDoc: LegalDocType.terms),
                ),
              );
            },
          ),
          _buildSettingsTile(
            icon: Icons.policy_outlined,
            title: 'Privacy Policy',
            subtitle: 'Read our zero-data collection guarantee',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LegalScreen(initialDoc: LegalDocType.privacy),
                ),
              );
            },
          ),
          const SizedBox(height: 32),

          // App Version with Secret 7-Tap Easter Egg
          Center(
            child: GestureDetector(
              onTap: _handleEasterEggTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.transparent,
                child: const Column(
                  children: [
                    Text(
                      'SpecPass v1.0.0 (Build 2026.10)',
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 12,
                        color: AppTheme.outline,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Conforms to ICAO Doc 9303 Biometric Specs',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontFamily: 'JetBrains Mono',
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: AppTheme.outline,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppTheme.secondary, size: 22),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant)),
        trailing: const Icon(Icons.chevron_right, color: AppTheme.outline, size: 20),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
