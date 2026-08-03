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
    debugPrint('RevenueCat: configured for $_platformLabel');

    // Surface empty offerings early in debug logs (common setup miss).
    if (kDebugMode) {
      try {
        await diagnoseOfferings();
      } catch (e) {
        debugPrint('RevenueCat: offerings check failed: $e');
      }
    }
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

  /// Logs offering / package state. Call from debug builds or when diagnosing
  /// empty products. Returns a short human-readable summary.
  Future<String> diagnoseOfferings() async {
    if (!_configured) {
      return 'RevenueCat not configured (missing/placeholder API key in .env).';
    }

    final offerings = await Purchases.getOfferings();
    final current = offerings.current;
    final allIds = offerings.all.keys.toList()..sort();

    final buffer = StringBuffer()
      ..writeln('RevenueCat offerings:')
      ..writeln('  all: ${allIds.isEmpty ? '(none)' : allIds.join(', ')}')
      ..writeln('  current: ${current?.identifier ?? '(none)'}');

    if (current != null) {
      final packages = current.availablePackages;
      buffer.writeln('  packages: ${packages.length}');
      for (final p in packages) {
        buffer.writeln(
          '    - ${p.identifier} (${p.packageType.name}) '
          '→ ${p.storeProduct.identifier} '
          '${p.storeProduct.priceString}',
        );
      }
      if (packages.isEmpty) {
        buffer.writeln(
          '  ⚠ Current offering has no packages the store can resolve.\n'
          '    In RevenueCat → Offerings → Current → add a Monthly package\n'
          '    linked to an App Store product (e.g. pro_monthly), then\n'
          '    attach that product to entitlement `pro`.',
        );
      }
    } else if (allIds.isEmpty) {
      buffer.writeln(
        '  ⚠ No offerings at all. Create one in RevenueCat, add packages\n'
        '    with App Store products, and mark it Current.',
      );
    } else {
      buffer.writeln(
        '  ⚠ Offerings exist but none is Current. Mark one as Current.',
      );
    }

    final summary = buffer.toString().trimRight();
    debugPrint(summary);
    return summary;
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
      await diagnoseOfferings();
      throw StateError(
        'No current offering in RevenueCat. Create an offering, add a '
        'Monthly package with an App Store product, and mark it Current.',
      );
    }

    final package =
        offering.monthly ??
        offering.annual ??
        (offering.availablePackages.isNotEmpty
            ? offering.availablePackages.first
            : null);
    if (package == null) {
      await diagnoseOfferings();
      throw StateError(
        'Current offering "${offering.identifier}" has no store packages. '
        'In RevenueCat, attach an App Store product (e.g. pro_monthly) to a '
        'Monthly package on that offering. See docs/REVENUECAT_SETUP.md.',
      );
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

  String get _platformLabel {
    if (Platform.isIOS) return 'iOS';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isAndroid) return 'Android';
    return 'unknown';
  }

  String? get _platformApiKey {
    final raw = Platform.isIOS || Platform.isMacOS
        ? ApiConfig.revenueCatIosApiKey
        : Platform.isAndroid
        ? ApiConfig.revenueCatAndroidApiKey
        : null;
    return _usableApiKey(raw);
  }

  /// Treats placeholders like `goog_…` / `appl_xxx` as unset.
  static String? _usableApiKey(String? raw) {
    if (raw == null) return null;
    final key = raw.trim();
    if (key.isEmpty) return null;
    if (key.contains('…') || key.contains('...')) return null;
    if (key.endsWith('_xxx') || key.contains('your_') || key.contains('YOUR_')) {
      return null;
    }
    // Real RC public keys are appl_… / goog_… / amzn_… / strp_… with entropy.
    if (key.length < 20) return null;
    return key;
  }
}
