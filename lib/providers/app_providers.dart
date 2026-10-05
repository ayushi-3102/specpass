import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/country_specs_data.dart';
import '../models/compliance_result.dart';
import '../models/country_spec.dart';
import '../services/photo_composer_service.dart';
import '../services/purchase_service.dart';

/// Provider for the currently active country specification
class SelectedCountrySpecNotifier extends Notifier<CountrySpec> {
  @override
  CountrySpec build() => CountrySpecsData.defaultSpec;

  void select(CountrySpec spec) => state = spec;
}

final selectedCountrySpecProvider = NotifierProvider<SelectedCountrySpecNotifier, CountrySpec>(
  SelectedCountrySpecNotifier.new,
);

/// Search query notifier
class CountrySearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void updateQuery(String query) => state = query;
}

final countrySearchQueryProvider = NotifierProvider<CountrySearchQueryNotifier, String>(
  CountrySearchQueryNotifier.new,
);

/// Provider for filtering country specs by document purpose (Passport, Visa, Driving License, Student ID, etc.)
class SelectedDocumentPurposeNotifier extends Notifier<DocumentPurpose> {
  @override
  DocumentPurpose build() => DocumentPurpose.all;

  void select(DocumentPurpose purpose) => state = purpose;
}

final selectedDocumentPurposeProvider = NotifierProvider<SelectedDocumentPurposeNotifier, DocumentPurpose>(
  SelectedDocumentPurposeNotifier.new,
);

/// Filtered list of country specs based on search query and selected document purpose
final filteredCountrySpecsProvider = Provider<List<CountrySpec>>((ref) {
  final query = ref.watch(countrySearchQueryProvider).toLowerCase().trim();
  final purpose = ref.watch(selectedDocumentPurposeProvider);

  final List<CountrySpec> baseList = (purpose == DocumentPurpose.all)
      ? CountrySpecsData.allSpecs
      : CountrySpecsData.getByPurpose(purpose);

  if (query.isEmpty) {
    return baseList;
  }
  return baseList.where((spec) {
    return spec.countryName.toLowerCase().contains(query) ||
        spec.documentTitle.toLowerCase().contains(query) ||
        spec.formattedDimensions.toLowerCase().contains(query) ||
        spec.countryCode.toLowerCase().contains(query);
  }).toList();
});

/// Active photo package notifier
class ActivePhotoPackageNotifier extends Notifier<ProcessedPhotoPackage?> {
  @override
  ProcessedPhotoPackage? build() => null;

  void setPackage(ProcessedPhotoPackage? package) => state = package;
}

final activePhotoPackageProvider = NotifierProvider<ActivePhotoPackageNotifier, ProcessedPhotoPackage?>(
  ActivePhotoPackageNotifier.new,
);

/// Active compliance audit notifier
class ActiveComplianceAuditNotifier extends Notifier<ComplianceAuditResult?> {
  @override
  ComplianceAuditResult? build() => null;

  void setAudit(ComplianceAuditResult? audit) => state = audit;
}

final activeComplianceAuditProvider = NotifierProvider<ActiveComplianceAuditNotifier, ComplianceAuditResult?>(
  ActiveComplianceAuditNotifier.new,
);

/// State notifier managing Pro / Lifetime unlock status
class ProStatusNotifier extends Notifier<bool> {
  @override
  bool build() {
    _loadStatus();
    return false;
  }

  Future<void> _loadStatus() async {
    final isPro = await PurchaseService.isProUser();
    state = isPro;
  }

  Future<bool> purchaseLifetime() async {
    final success = await PurchaseService.purchaseLifetimePro();
    if (success) {
      state = true;
    }
    return success;
  }

  Future<bool> restore() async {
    final success = await PurchaseService.restorePurchases();
    if (success) {
      state = true;
    }
    return success;
  }

  Future<bool> triggerEasterEggTap() async {
    final toggled = await PurchaseService.registerEasterEggTap();
    if (toggled) {
      final isPro = await PurchaseService.isProUser();
      state = isPro;
    }
    return toggled;
  }
}

final proStatusProvider = NotifierProvider<ProStatusNotifier, bool>(
  ProStatusNotifier.new,
);

/// App Language Provider ('en' or 'de')
class AppLanguageNotifier extends Notifier<String> {
  @override
  String build() => 'en';

  void setLanguage(String lang) => state = lang;
  void toggle() => state = state == 'en' ? 'de' : 'en';
}

final appLanguageProvider = NotifierProvider<AppLanguageNotifier, String>(
  AppLanguageNotifier.new,
);

/// Global Infant / Baby Mode Notifier
class BabyModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
  void setBabyMode(bool enabled) => state = enabled;
}

final babyModeProvider = NotifierProvider<BabyModeNotifier, bool>(
  BabyModeNotifier.new,
);

