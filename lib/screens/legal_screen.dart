import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/theme.dart';

enum LegalDocType { terms, privacy }

class LegalScreen extends StatelessWidget {
  final LegalDocType initialDoc;

  const LegalScreen({super.key, this.initialDoc = LegalDocType.terms});

  @override
  Widget build(BuildContext context) {
    final bool isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return DefaultTabController(
      initialIndex: initialDoc == LegalDocType.terms ? 0 : 1,
      length: 2,
      child: Scaffold(
        backgroundColor: AppTheme.surface,
        appBar: AppBar(
          title: const Text('Legal & Compliance'),
          bottom: const TabBar(
            indicatorColor: AppTheme.primary,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.onSurfaceVariant,
            tabs: [
              Tab(text: 'Terms of Service'),
              Tab(text: 'Privacy Policy'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildTermsContent(context, isIOS, bottomPadding),
            _buildPrivacyContent(context, bottomPadding),
          ],
        ),
      ),
    );
  }

  Widget _buildTermsContent(BuildContext context, bool isIOS, double bottomPadding) {
    return ListView(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPadding + 24),
      children: [
        Text('Terms of Service', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text('Last updated: October 2026', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 16),
        _buildSectionHeader('1. Biometric & Document Disclaimer'),
        _buildSectionBody(
          'SpecPass is an image processing and biometric layout tool designed to conform to international ICAO Doc 9303, US Department of State, and regional consular passport and visa guidelines. While SpecPass verifies mathematical aspect ratios, head-to-canvas percentages, eye levels, and backdrop neutrality, final acceptance remains subject to the sovereign authority of the issuing government or consular body.',
        ),
        const SizedBox(height: 16),
        _buildSectionHeader('2. Purchases & Licensing (${isIOS ? "Apple App Store" : "Google Play"})'),
        if (isIOS)
          _buildSectionBody(
            'In-app purchases are processed through the Apple App Store using Apple StoreKit 2 and your Apple ID. All purchases are governed by Apple\'s Standard End User License Agreement (EULA) and App Store Terms of Service. For refund requests or billing inquiries, please visit reportaproblem.apple.com.',
          )
        else
          _buildSectionBody(
            'In-app purchases are processed via Google Play In-App Billing and your Google Account. Payments and licensing comply with Google Play Developer Policies and Terms of Service. Refunds are handled in accordance with the Google Play Refund Policy.',
          ),
        const SizedBox(height: 16),
        _buildSectionHeader('3. User Responsibility & Authenticity'),
        _buildSectionBody(
          'Users must ensure that uploaded and captured photos represent their true physical likeness without deceptive alterations, filters, or synthetic modifications prohibited by governmental authorities.',
        ),
      ],
    );
  }

  Widget _buildPrivacyContent(BuildContext context, double bottomPadding) {
    return ListView(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPadding + 24),
      children: [
        Text('Privacy Policy (100% On-Device)', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text('Zero Cloud Storage • Zero Data Collection', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 16),
        _buildSectionHeader('1. Complete Sovereign Offline Architecture'),
        _buildSectionBody(
          'SpecPass does not transmit, store, or process your facial portraits, biometric geometry, or personal photographs on external servers or cloud infrastructure. All background separation, facial feature measurements, and 4x6" canvas generation take place 100% locally on your device.',
        ),
        const SizedBox(height: 16),
        _buildSectionHeader('2. Camera & Photo Library Access'),
        _buildSectionBody(
          'Camera access is requested solely to present the live biometric viewfinder for capturing passport portraits. Photo Library access is used solely to select existing portraits and save exported 300 DPI photos and 4x6" print sheets directly to your device\'s local storage.',
        ),
        const SizedBox(height: 16),
        _buildSectionHeader('3. Third-Party Analytics & Advertising'),
        _buildSectionBody(
          'SpecPass contains zero third-party advertising SDKs and zero invasive user tracking. Anonymous purchase verification telemetry is handled securely by RevenueCat solely to restore your paid entitlements across your devices.',
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: const TextStyle(
          color: AppTheme.primary,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildSectionBody(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppTheme.onSurfaceVariant,
        fontSize: 14,
        height: 1.5,
      ),
    );
  }
}
