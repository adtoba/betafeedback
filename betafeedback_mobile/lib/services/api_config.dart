import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Runtime config for the mobile app.
///
/// Values come from `.env` (see `.env.example`). Call [load] once from `main`
/// before reading any getters.
///
/// Optional `--dart-define=KEY=value` still wins when set (useful for CI).
///
/// [baseUrl] is chosen automatically: local backend in debug builds,
/// production API in release builds.
class ApiConfig {
  ApiConfig._();

  static const _productionBaseUrl = 'https://api.betafeedback.com';
  static const _defaultGoogleWebClientId =
      '629984102803-1c856435gm27kroo0ag37uqjdrde14h5.apps.googleusercontent.com';
  static const _defaultGoogleIosClientId =
      '629984102803-1oh04iq2pl15ialne81gos0m8vh4uavj.apps.googleusercontent.com';

  /// Loads `.env`, falling back to `.env.example` if needed.
  static Future<void> load() async {
    final loaded = await _tryLoad('.env');
    if (!loaded) {
      await _tryLoad('.env.example');
    }
    if (kDebugMode) {
      debugPrint('ApiConfig: debug build → $baseUrl');
    }
  }

  static Future<bool> _tryLoad(String fileName) async {
    try {
      await dotenv.load(fileName: fileName);
      return dotenv.isInitialized;
    } catch (_) {
      return false;
    }
  }

  /// Debug → local backend. Release → production API.
  ///
  /// Override with `--dart-define=API_BASE_URL=…` or, in debug only,
  /// `API_BASE_URL_DEBUG` in `.env` (for physical devices on your LAN).
  static String get baseUrl {
    final fromDefine = const String.fromEnvironment('API_BASE_URL');
    if (fromDefine.isNotEmpty) return fromDefine;

    if (kDebugMode) {
      if (dotenv.isInitialized) {
        final debugOverride = dotenv.maybeGet('API_BASE_URL_DEBUG')?.trim();
        if (debugOverride != null && debugOverride.isNotEmpty) {
          return debugOverride;
        }
      }
      return _localDebugBaseUrl;
    }

    return _productionBaseUrl;
  }

  static String get _localDebugBaseUrl {
    if (kIsWeb) return 'http://localhost:8080';
    if (Platform.isAndroid) return 'http://10.0.2.2:8080';
    return 'http://localhost:8080';
  }

  static String get googleWebClientId => _value(
    'GOOGLE_WEB_CLIENT_ID',
    fromEnvironment: const String.fromEnvironment('GOOGLE_WEB_CLIENT_ID'),
    fallback: _defaultGoogleWebClientId,
  );

  static String get googleIosClientId => _value(
    'GOOGLE_IOS_CLIENT_ID',
    fromEnvironment: const String.fromEnvironment('GOOGLE_IOS_CLIENT_ID'),
    fallback: _defaultGoogleIosClientId,
  );

  static String get revenueCatIosApiKey => _value(
    'REVENUECAT_IOS_API_KEY',
    fromEnvironment: const String.fromEnvironment('REVENUECAT_IOS_API_KEY'),
  );

  static String get revenueCatAndroidApiKey => _value(
    'REVENUECAT_ANDROID_API_KEY',
    fromEnvironment: const String.fromEnvironment('REVENUECAT_ANDROID_API_KEY'),
  );

  static String get revenueCatEntitlementId => _value(
    'REVENUECAT_ENTITLEMENT_ID',
    fromEnvironment: const String.fromEnvironment('REVENUECAT_ENTITLEMENT_ID'),
    fallback: 'pro',
  );

  /// Skips client paywalls / Pro gates. True in debug builds, or when
  /// `BYPASS_PAYWALL=true` in `.env` (needed for release/profile installs).
  static bool get bypassSubscriptionGates {
    if (kDebugMode) return true;
    final fromEnv = const String.fromEnvironment('BYPASS_PAYWALL');
    if (fromEnv.isNotEmpty) return _truthy(fromEnv);
    if (dotenv.isInitialized) {
      final raw = dotenv.maybeGet('BYPASS_PAYWALL')?.trim();
      if (raw != null && raw.isNotEmpty) return _truthy(raw);
    }
    return false;
  }

  static bool _truthy(String value) {
    switch (value.toLowerCase()) {
      case '1':
      case 'true':
      case 'yes':
        return true;
      default:
        return false;
    }
  }

  static String _value(
    String key, {
    required String fromEnvironment,
    String fallback = '',
  }) {
    if (fromEnvironment.isNotEmpty) return fromEnvironment;
    if (dotenv.isInitialized) {
      final fromEnv = dotenv.maybeGet(key)?.trim();
      if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
    }
    return fallback;
  }
}
