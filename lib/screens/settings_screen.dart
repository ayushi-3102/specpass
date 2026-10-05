import 'dart:math' as math;
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

      final colors = AppTheme.colors(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: colors.primary,
          content: Text(
            toggled ? '🛠️ Developer Override: Pro Mode Toggled!' : 'Developer Mode Reset.',
          ),
        ),
      );
    }
  }

  void _showThemeDialog() {
    final current = ref.read(themeModeProvider);
    final colors = AppTheme.colors(context);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: colors.surfaceContainer,
          title: Text(
            'Select App Theme',
            style: TextStyle(fontWeight: FontWeight.bold, color: colors.onSurface),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  current == ThemeMode.dark ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: current == ThemeMode.dark ? colors.primary : colors.outline,
                ),
                title: Text('Dark Obsidian (Default)', style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.w600)),
                subtitle: Text('Deep obsidian with sapphire biometric calipers', style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11)),
                onTap: () {
                  ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark);
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: Icon(
                  current == ThemeMode.light ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: current == ThemeMode.light ? colors.primary : colors.outline,
                ),
                title: Text('Consular Prestige Light (White)', style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.w600)),
                subtitle: Text('Pristine white canvas with consular navy & gold seal', style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11)),
                onTap: () {
                  ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light);
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: Icon(
                  current == ThemeMode.system ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: current == ThemeMode.system ? colors.primary : colors.outline,
                ),
                title: Text('System Automatic', style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.w600)),
                subtitle: Text('Follows system light/dark display mode', style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11)),
                onTap: () {
                  ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.system);
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: colors.secondary)),
            ),
          ],
        );
      },
    );
  }

  void _showLanguageDialog() {
    final current = ref.read(appLanguageProvider);
    final colors = AppTheme.colors(context);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: colors.surfaceContainer,
          title: Text(
            'Select Language',
            style: TextStyle(fontWeight: FontWeight.bold, color: colors.onSurface),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  current == 'en' ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: current == 'en' ? colors.primary : colors.outline,
                ),
                title: Text('English (Global ICAO)', style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.w600)),
                subtitle: Text('Default international consular standard', style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11)),
                onTap: () {
                  ref.read(appLanguageProvider.notifier).setLanguage('en');
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: Icon(
                  current == 'de' ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: current == 'de' ? colors.primary : colors.outline,
                ),
                title: Text('Deutsch (Konsularisch)', style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.w600)),
                subtitle: Text('Biometrisches Passbild & Kiosk-Druckanleitung', style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11)),
                onTap: () {
                  ref.read(appLanguageProvider.notifier).setLanguage('de');
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: colors.secondary)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPro = ref.watch(proStatusProvider);
    final themeMode = ref.watch(themeModeProvider);
    final currentLang = ref.watch(appLanguageProvider);
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final colors = AppTheme.colors(context);

    String themeLabel;
    if (themeMode == ThemeMode.light) {
      themeLabel = 'Consular Prestige Light (White)';
    } else if (themeMode == ThemeMode.dark) {
      themeLabel = 'Dark Obsidian (Biometric)';
    } else {
      themeLabel = 'System Automatic';
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Settings & Standards',
          style: TextStyle(fontWeight: FontWeight.bold, color: colors.onSurface),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, 16, 20, math.max(bottomInset, 16) + 32),
        children: [
          // Pro Status Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isPro
                  ? colors.tertiaryContainer.withValues(alpha: colors.isDark ? 0.3 : 0.7)
                  : colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isPro ? colors.tertiary.withValues(alpha: 0.4) : colors.outlineVariant,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isPro ? colors.tertiaryContainer : colors.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPro ? Icons.verified : Icons.lock_open,
                    color: isPro ? colors.tertiary : colors.secondary,
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
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: colors.onSurface),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isPro
                            ? 'Lifetime access unlocked across all platforms.'
                            : 'Upgrade for 6,99 € / \$6.99 (Lifetime for whole family).',
                        style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (!isPro)
                  ElevatedButton(
                    onPressed: () => PaywallModal.show(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
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

          // Appearance & Theme Section
          _buildSectionHeader('APPEARANCE & THEME', colors),
          _buildSettingsTile(
            colors: colors,
            icon: themeMode == ThemeMode.light ? Icons.light_mode : Icons.dark_mode,
            title: 'Theme & Styling',
            subtitle: themeLabel,
            onTap: _showThemeDialog,
          ),
          _buildSettingsTile(
            colors: colors,
            icon: Icons.language,
            title: 'Language / Sprache',
            subtitle: currentLang == 'de' ? 'Deutsch (Konsularisch)' : 'English (Global ICAO)',
            onTap: _showLanguageDialog,
          ),
          const SizedBox(height: 20),

          // Purchases Section
          _buildSectionHeader('PURCHASES & ENTITLEMENTS', colors),
          _buildSettingsTile(
            colors: colors,
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
          _buildSectionHeader('SOVEREIGN DATA & PRIVACY', colors),
          _buildSettingsTile(
            colors: colors,
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
          _buildSectionHeader('LEGAL & GOVERNMENT STANDARDS', colors),
          _buildSettingsTile(
            colors: colors,
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
            colors: colors,
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
                child: Column(
                  children: [
                    Text(
                      'SpecPass v1.0.0 (Build 2026.10)',
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 12,
                        color: colors.outline,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Conforms to ICAO Doc 9303 Biometric Specs',
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.onSurfaceVariant,
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

  Widget _buildSectionHeader(String title, AppPalette colors) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: 'JetBrains Mono',
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: colors.outline,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required AppPalette colors,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: ListTile(
        leading: Icon(icon, color: colors.secondary, size: 22),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: colors.onSurface)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
        trailing: Icon(Icons.chevron_right, color: colors.outline, size: 20),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
