import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api_config.dart';

/// RevenueCat wrapper for Pro subscriptions.
///
/// Configure offerings/entitlement `pro` in the RevenueCat dashboard.
/// Public SDK keys live in `.env` (`REVENUECAT_IOS_API_KEY` /
/// `REVENUECAT_ANDROID_API_KEY`).
class BillingService {
  bool _configured = false;

  bool get isConfigured => _configured;

  Future<void> init() async {
    if (_configured || kIsWeb) return;

    final apiKey = _platformApiKey;
    if (apiKey == null || apiKey.isEmpty) {
      debugPrint('RevenueCat: no API key for this platform; billing disabled');
      return;
    }

    await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.info);
    await Purchases.configure(PurchasesConfiguration(apiKey));
    _configured = true;
  }

  /// Links the store / RevenueCat customer to our backend user id.
  Future<void> identify(String userId) async {
    if (!_configured || userId.isEmpty) return;
    try {
      await Purchases.logIn(userId);
    } on PlatformException catch (e) {
      debugPrint('RevenueCat logIn failed: $e');
    }
  }

  Future<void> logOut() async {
    if (!_configured) return;
    try {
      final info = await Purchases.getCustomerInfo();
      if (info.originalAppUserId.startsWith(r'$RCAnonymousID:')) {
        return;
      }
      await Purchases.logOut();
    } on PlatformException catch (e) {
      debugPrint('RevenueCat logOut failed: $e');
    }
  }

  /// Purchases the Pro package from the current offering.
  /// Returns true when Pro entitlement is active after the purchase.
  Future<bool> purchasePro() async {
    if (!_configured) {
      throw StateError(
        'RevenueCat is not configured. Set REVENUECAT_IOS_API_KEY / '
        'REVENUECAT_ANDROID_API_KEY in .env.',
      );
    }

    final offerings = await Purchases.getOfferings();
    final offering = offerings.current;
    if (offering == null) {
      throw StateError(
        'No current offering in RevenueCat. Mark an offering as Current.',
      );
    }

    final package =
        offering.monthly ??
        offering.annual ??
        (offering.availablePackages.isNotEmpty
            ? offering.availablePackages.first
            : null);
    if (package == null) {
      throw StateError('No Pro packages available in the current offering.');
    }

    try {
      final result = await Purchases.purchase(PurchaseParams.package(package));
      return _hasPro(result.customerInfo);
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        return false;
      }
      rethrow;
    }
  }

  Future<bool> restorePurchases() async {
    if (!_configured) return false;
    final info = await Purchases.restorePurchases();
    return _hasPro(info);
  }

  Future<bool> hasProEntitlement() async {
    if (!_configured) return false;
    final info = await Purchases.getCustomerInfo();
    return _hasPro(info);
  }

  /// Opens the platform subscription management UI.
  Future<void> manageSubscription() async {
    final uri = Platform.isAndroid
        ? Uri.parse('https://play.google.com/store/account/subscriptions')
        : Uri.parse('https://apps.apple.com/account/subscriptions');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  bool _hasPro(CustomerInfo info) {
    final entitlementId = ApiConfig.revenueCatEntitlementId;
    final active = info.entitlements.active[entitlementId];
    return active != null;
  }

  String? get _platformApiKey {
    if (Platform.isIOS || Platform.isMacOS) {
      return ApiConfig.revenueCatIosApiKey;
    }
    if (Platform.isAndroid) {
      return ApiConfig.revenueCatAndroidApiKey;
    }
    return null;
  }
}
