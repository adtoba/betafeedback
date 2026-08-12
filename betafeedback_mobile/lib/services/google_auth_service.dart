import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'api_client.dart';
import 'api_config.dart';

/// Thrown when the user dismisses the Google account picker.
class GoogleSignInCancelledException implements Exception {}

/// Loads OAuth client IDs from the backend (or `.env` / dart-defines) and runs the
/// native Google Sign-In flow to obtain an ID token for `/v1/auth/google`.
class GoogleAuthService {
  GoogleAuthService({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;
  GoogleSignIn? _googleSignIn;

  Future<String> signInAndGetIdToken() async {
    final googleSignIn = await _client();
    final account = await googleSignIn.signIn();
    if (account == null) {
      throw GoogleSignInCancelledException();
    }

    final auth = await account.authentication;
    final idToken = auth.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError(
        'Google did not return an ID token. '
        'On Android, ensure GOOGLE_CLIENT_ID is set on the backend. '
        'On iOS, configure GOOGLE_IOS_CLIENT_ID and Info.plist URL schemes.',
      );
    }
    return idToken;
  }

  /// Clears the Google session so the next sign-in shows the account picker.
  ///
  /// On Android, [GoogleSignIn.signOut] keeps credentials valid and the SDK may
  /// silently re-use the last account. [disconnect] revokes access instead.
  Future<void> signOut() async {
    GoogleSignIn? client = _googleSignIn;
    try {
      client ??= await _client();
    } catch (_) {
      _googleSignIn = null;
      return;
    }

    try {
      await client.disconnect();
    } catch (e) {
      debugPrint('Google disconnect failed: $e');
      try {
        await client.signOut();
      } catch (e) {
        debugPrint('Google signOut failed: $e');
      }
    }
    _googleSignIn = null;
  }

  Future<GoogleSignIn> _client() async {
    if (_googleSignIn != null) {
      return _googleSignIn!;
    }

    final (webClientId, iosClientId) = await _loadClientIds();
    if (webClientId.isEmpty) {
      throw StateError('Google sign-in is not configured on the server');
    }

    _googleSignIn = GoogleSignIn(
      scopes: const ['email', 'profile'],
      serverClientId: webClientId,
      // clientId: !kIsWeb && Platform.isIOS && iosClientId.isNotEmpty
      //     ? iosClientId
      //     : null,
    );
    return _googleSignIn!;
  }

  Future<(String webClientId, String iosClientId)> _loadClientIds() async {
    var webClientId = ApiConfig.googleWebClientId;
    var iosClientId = ApiConfig.googleIosClientId;

    if (webClientId.isNotEmpty && iosClientId.isNotEmpty) {
      return (webClientId, iosClientId);
    }

    final res = await _api.get('/v1/auth/config');
    if (res is! Map<String, dynamic>) {
      return (webClientId, iosClientId);
    }

    if (webClientId.isEmpty) {
      webClientId = (res['google_client_id'] as String?)?.trim() ?? '';
    }
    if (iosClientId.isEmpty) {
      iosClientId = (res['google_ios_client_id'] as String?)?.trim() ?? '';
    }
    return (webClientId, iosClientId);
  }
}
