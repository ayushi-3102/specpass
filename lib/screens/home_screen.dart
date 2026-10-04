import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../models/country_spec.dart';
import '../providers/app_providers.dart';
import 'camera_studio_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentTabIndex = 0;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _launchCamera(CountrySpec spec) {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CameraStudioScreen(spec: spec),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.shield, color: AppTheme.secondary, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('SpecPass', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'ICAO 9303',
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.secondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const Text(
                  'Biometric Studio',
                  style: TextStyle(fontSize: 11, color: AppTheme.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerHigh.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Icon(Icons.lock, size: 12, color: AppTheme.tertiary),
                SizedBox(width: 4),
                Text(
                  '100% On-Device',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.onSurface),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppTheme.onSurface),
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: IndexedStack(
        index: _currentTabIndex,
        children: [
          _buildStudioTab(bottomInset),
          _buildStandardsTab(bottomInset),
          _buildSavedTab(bottomInset),
          _buildGuaranteeTab(bottomInset),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceDim.withValues(alpha: 0.95),
          border: const Border(
            top: BorderSide(color: AppTheme.outlineVariant, width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.photo_camera, 'Studio'),
                _buildNavItem(1, Icons.public, 'Standards'),
                _buildNavItem(2, Icons.photo_library, 'Saved'),
                _buildNavItem(3, Icons.verified_user, 'Guarantee'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentTabIndex == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _currentTabIndex = index);
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? AppTheme.primary : AppTheme.onSurfaceVariant,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppTheme.primary : AppTheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 1: STUDIO (Home Workspace)
  // ---------------------------------------------------------------------------
  Widget _buildStudioTab(double bottomInset) {
    final selectedSpec = ref.watch(selectedCountrySpecProvider);
    final filteredSpecs = ref.watch(filteredCountrySpecsProvider);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset + 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Trust & Security Pills
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.outlineVariant),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock, size: 12, color: AppTheme.tertiary),
                    SizedBox(width: 6),
                    Text(
                      'Zero Cloud Uploads',
                      style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 10, color: AppTheme.onSurface),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.outlineVariant),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.print, size: 12, color: AppTheme.secondary),
                    SizedBox(width: 6),
                    Text(
                      '35¢ Pharmacy Print',
                      style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 10, color: AppTheme.secondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Active Standard Showcase
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Active Document Standard',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.onSurface),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  selectedSpec.standardTag,
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
          const SizedBox(height: 12),

          // Hero Selected Document Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainer,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(selectedSpec.flagEmoji, style: const TextStyle(fontSize: 28)),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selectedSpec.countryName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.onSurface),
                            ),
                            Text(
                              selectedSpec.documentTitle,
                              style: const TextStyle(fontSize: 13, color: AppTheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'READY',
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Spec Parameters Grid
                Row(
                  children: [
                    Expanded(
                      child: _buildSpecGridItem('DIMENSIONS', selectedSpec.formattedDimensions),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildSpecGridItem('DIGITAL RES', '${selectedSpec.widthPixels}×${selectedSpec.heightPixels} px'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildSpecGridItem('BACKGROUND', selectedSpec.backgroundName),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildSpecGridItem(
                        'HEAD RATIO',
                        '${(selectedSpec.headRatioMin * 100).toInt()}%–${(selectedSpec.headRatioMax * 100).toInt()}% Frame',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Big CTA inside active card
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () => _launchCamera(selectedSpec),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                    ),
                    icon: const Icon(Icons.camera_alt),
                    label: Text(
                      'Take ${selectedSpec.countryName} Photo',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Horizontal Carousel of Popular Standards
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Quick Switch Standards',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.onSurface),
              ),
              GestureDetector(
                onTap: () => setState(() => _currentTabIndex = 1),
                child: const Text(
                  'Browse All 140+ →',
                  style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 11, color: AppTheme.secondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          SizedBox(
            height: 130,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: filteredSpecs.length,
              itemBuilder: (context, index) {
                final spec = filteredSpecs[index];
                final isSelected = spec.id == selectedSpec.id;

                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(selectedCountrySpecProvider.notifier).select(spec);
                  },
                  child: Container(
                    width: 165,
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.surfaceContainerHigh : AppTheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isSelected ? AppTheme.secondary : AppTheme.outlineVariant,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(spec.flagEmoji, style: const TextStyle(fontSize: 22)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                spec.standardTag,
                                textAlign: TextAlign.end,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'JetBrains Mono',
                                  fontSize: 8,
                                  color: AppTheme.outline,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              spec.countryName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.onSurface),
                            ),
                            Text(
                              spec.formattedDimensions,
                              style: const TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 11,
                                color: AppTheme.secondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 2: STANDARDS DIRECTORY
  // ---------------------------------------------------------------------------
  Widget _buildStandardsTab(double bottomInset) {
    final filteredSpecs = ref.watch(filteredCountrySpecsProvider);
    final selectedSpec = ref.watch(selectedCountrySpecProvider);

    return Column(
      children: [
        // Search Input Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.outlineVariant),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                const Icon(Icons.travel_explore, color: AppTheme.outline, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: AppTheme.onSurface, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Search 140+ countries & visa types...',
                      hintStyle: TextStyle(color: AppTheme.outline, fontSize: 14),
                      border: InputBorder.none,
                    ),
                    onChanged: (val) {
                      ref.read(countrySearchQueryProvider.notifier).updateQuery(val);
                    },
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.close, size: 16, color: AppTheme.outline),
                    onPressed: () {
                      _searchController.clear();
                      ref.read(countrySearchQueryProvider.notifier).updateQuery('');
                    },
                  ),
              ],
            ),
          ),
        ),

        // Standards List
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.fromLTRB(20, 0, 20, bottomInset + 16),
            itemCount: filteredSpecs.length,
            itemBuilder: (context, index) {
              final spec = filteredSpecs[index];
              final isSelected = spec.id == selectedSpec.id;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.surfaceContainerHigh : AppTheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isSelected ? AppTheme.primary : AppTheme.outlineVariant,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Text(spec.flagEmoji, style: const TextStyle(fontSize: 28)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                spec.countryName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.onSurface),
                              ),
                              Text(
                                spec.formattedDimensions,
                                style: const TextStyle(
                                  fontFamily: 'JetBrains Mono',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.secondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            spec.documentTitle,
                            style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Background: ${spec.backgroundName}',
                            style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 10, color: AppTheme.outline),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      icon: Icon(
                        isSelected ? Icons.check_circle : Icons.camera_alt_outlined,
                        color: isSelected ? AppTheme.tertiary : AppTheme.primary,
                      ),
                      onPressed: () {
                        ref.read(selectedCountrySpecProvider.notifier).select(spec);
                        _launchCamera(spec);
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 3: SAVED PHOTOS & PRINT SHEETS
  // ---------------------------------------------------------------------------
  Widget _buildSavedTab(double bottomInset) {
    return ListView(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.folder_shared, color: AppTheme.secondary),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sovereign Local Archive',
                      style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.onSurface, fontSize: 15),
                    ),
                    Text(
                      'Photos are saved only to your local gallery and device files.',
                      style: TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        const Text(
          'Sample Studio Session',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.onSurface),
        ),
        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.outlineVariant),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/images/sample_portrait.png',
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 60,
                    height: 60,
                    color: AppTheme.surfaceContainerHigh,
                    child: const Icon(Icons.person, color: AppTheme.outline),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'United States 2.0" × 2.0"',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.onSurface),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Verified 100% ICAO • 300 DPI RAW',
                      style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 11, color: AppTheme.tertiary),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '6-Photo 4×6" Print Sheet Ready',
                      style: TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.print, color: AppTheme.secondary),
                onPressed: () {
                  final spec = ref.read(selectedCountrySpecProvider);
                  _launchCamera(spec);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 4: 14-POINT ZERO-REJECTION GUARANTEE
  // ---------------------------------------------------------------------------
  Widget _buildGuaranteeTab(double bottomInset) {
    final auditPoints = [
      {'title': 'Uniform Pure Background', 'desc': 'Converts wall colors to compliant white/off-white with 0 shadows.'},
      {'title': 'Eye Horizon < 0.5° Tilt', 'desc': 'Measures exact Euler roll & pitch to prevent consular rejection.'},
      {'title': 'Chin-to-Crown Ratio (50–69%)', 'desc': 'Strict biometric facial proportions relative to frame height.'},
      {'title': 'Glare & Eyeglasses Scanner', 'desc': 'Alerts if glare or prohibited eyeglass frames are detected.'},
      {'title': '300 DPI Lab Print Resolution', 'desc': 'Rasterized at true 300 dots-per-inch for pharmacy photo paper.'},
      {'title': 'Neutral Facial Expression', 'desc': 'Checks that mouth is closed and eyes are directly locked on sensor.'},
      {'title': 'Standard 4×6" Print Geometry', 'desc': 'Exact millimeter alignment with border cutting guides for scissors.'},
    ];

    return ListView(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 16),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.tertiaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppTheme.tertiary.withValues(alpha: 0.4)),
          ),
          child: const Row(
            children: [
              Icon(Icons.verified_user, color: AppTheme.tertiary, size: 36),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Zero-Rejection Guarantee',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppTheme.onSurface),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Every photo conforms to ICAO Doc 9303 and U.S. State Dept guidelines.',
                      style: TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        const Text(
          'Automated Biometric Checks',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.onSurface),
        ),
        const SizedBox(height: 12),

        ...auditPoints.map((pt) {
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
                    color: AppTheme.tertiaryContainer.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: AppTheme.tertiary, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pt['title']!,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.onSurface),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        pt['desc']!,
                        style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSpecGridItem(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 9,
              color: AppTheme.outline,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
