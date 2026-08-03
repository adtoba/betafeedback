import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Runtime config for the mobile app.
///
/// Values come from `.env` (see `.env.example`). Call [load] once from `main`
/// before reading any getters.
///
/// Optional `--dart-define=KEY=value` still wins when set (useful for CI).
class ApiConfig {
  ApiConfig._();

  static const _defaultBaseUrl = 'http://localhost:8080';
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
  }

  static Future<bool> _tryLoad(String fileName) async {
    try {
      await dotenv.load(fileName: fileName);
      return dotenv.isInitialized;
    } catch (_) {
      return false;
    }
  }

  static String get baseUrl => _value(
    'API_BASE_URL',
    fromEnvironment: const String.fromEnvironment('API_BASE_URL'),
    fallback: _defaultBaseUrl,
  );

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
