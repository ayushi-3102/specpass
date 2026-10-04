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

/// Filtered list of country specs based on search query
final filteredCountrySpecsProvider = Provider<List<CountrySpec>>((ref) {
  final query = ref.watch(countrySearchQueryProvider).toLowerCase().trim();
  if (query.isEmpty) {
    return CountrySpecsData.allSpecs;
  }
  return CountrySpecsData.allSpecs.where((spec) {
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
