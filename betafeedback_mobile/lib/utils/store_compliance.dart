import 'dart:io' show Platform;

/// Whether the app may surface beta build distribution UI (TestFlight setup,
/// Play closed testing, install checklists). Disabled on iOS per App Store
/// Guideline 2.2.
bool get supportsBetaDistributionUi => !Platform.isIOS;

/// Whether Android-specific distribution UI may appear. Disabled on iOS per
/// App Store Guideline 2.3.10.
bool get supportsAndroidDistributionUi => !Platform.isIOS;

/// Placeholder for the getting-started notes field — omits Android / Play
/// references on iOS builds.
String get memberNotesExampleHint => supportsAndroidDistributionUi
    ? 'Example:\n'
          'iOS (TestFlight): https://testflight.apple.com/join/…\n'
          'Android: https://play.google.com/apps/testing/…\n'
          'Web staging: https://staging.example.com'
    : 'Example:\n'
          'App link: https://testflight.apple.com/join/…\n'
          'Web: https://staging.example.com\n'
          'Add any install steps your testers should follow.';
