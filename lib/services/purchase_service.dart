import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PurchaseService {
  PurchaseService._();

  static const String _entitlementId = 'pro_access';
  static const String _prefDevProOverride = 'pref_dev_pro_override';
  static const String _prefEasterEggClicks = 'pref_easter_egg_clicks';

  // RevenueCat Production Keys (Replace with your keys from RevenueCat Dashboard)
  static const String _googleApiKey = 'goog_sample_specpass_placeholder';
  static const String _appleApiKey = 'appl_sample_specpass_placeholder';

  static bool _isInitialized = false;

  /// Initialize RevenueCat conditionally on mobile devices
  static Future<void> initialize() async {
    if (_isInitialized) return;

    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
      try {
        final apiKey = defaultTargetPlatform == TargetPlatform.android ? _googleApiKey : _appleApiKey;
        final configuration = PurchasesConfiguration(apiKey);
        await Purchases.configure(configuration);
        _isInitialized = true;
      } catch (e) {
        debugPrint('[SpecPass] RevenueCat initialization bypassed or offline: $e');
      }
    }
  }

  /// Check if the user has an active Pro entitlement
  static Future<bool> isProUser() async {
    final prefs = await SharedPreferences.getInstance();

    // Check Developer Easter Egg Override
    final bool devOverride = prefs.getBool(_prefDevProOverride) ?? false;
    if (devOverride) {
      return true;
    }

    if (!_isInitialized) {
      return false;
    }

    try {
      final CustomerInfo customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.active.containsKey(_entitlementId) ||
          customerInfo.entitlements.active.containsKey('lifetime_pro');
    } catch (e) {
      debugPrint('[SpecPass] Error fetching CustomerInfo: $e');
      return false;
    }
  }

  /// Purchase Lifetime Package
  static Future<bool> purchaseLifetimePro() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Check Developer Override
    if (prefs.getBool(_prefDevProOverride) == true) {
      return true;
    }

    if (!_isInitialized) {
      // Simulate purchase in dev/unconfigured environment
      await prefs.setBool(_prefDevProOverride, true);
      return true;
    }

    try {
      final offerings = await Purchases.getOfferings();
      final currentOffering = offerings.current;

      if (currentOffering != null && currentOffering.availablePackages.isNotEmpty) {
        final package = currentOffering.lifetime ?? currentOffering.availablePackages.first;
        final CustomerInfo customerInfo =
            (await Purchases.purchase(PurchaseParams.package(package))).customerInfo;

        return customerInfo.entitlements.active.containsKey(_entitlementId) ||
            customerInfo.entitlements.active.containsKey('lifetime_pro');
      } else {
        // Fallback simulation if no offerings configured yet
        await prefs.setBool(_prefDevProOverride, true);
        return true;
      }
    } on PurchasesErrorCode catch (code) {
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        debugPrint('[SpecPass] User cancelled the purchase.');
        return false;
      }
      rethrow;
    } catch (e) {
      debugPrint('[SpecPass] Purchase error: $e');
      return false;
    }
  }

  /// Restore previous purchases
  static Future<bool> restorePurchases() async {
    if (!_isInitialized) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_prefDevProOverride) ?? false;
    }

    try {
      final CustomerInfo restoredInfo = await Purchases.restorePurchases();
      return restoredInfo.entitlements.active.containsKey(_entitlementId) ||
          restoredInfo.entitlements.active.containsKey('lifetime_pro');
    } catch (e) {
      debugPrint('[SpecPass] Restore purchases error: $e');
      return false;
    }
  }

  /// 7-Tap Easter Egg: Toggle Developer Test Lab
  static Future<bool> registerEasterEggTap() async {
    final prefs = await SharedPreferences.getInstance();
    final int currentTaps = (prefs.getInt(_prefEasterEggClicks) ?? 0) + 1;
    await prefs.setInt(_prefEasterEggClicks, currentTaps);

    if (currentTaps >= 7) {
      final bool currentDev = prefs.getBool(_prefDevProOverride) ?? false;
      await prefs.setBool(_prefDevProOverride, !currentDev);
      await prefs.setInt(_prefEasterEggClicks, 0); // reset
      return true; // Toggled!
    }
    return false;
  }

  static Future<bool> isDevOverrideActive() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefDevProOverride) ?? false;
  }
}
