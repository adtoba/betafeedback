/// Backend base URL. Defaults to localhost (works from the iOS Simulator on the
/// same machine). Override at build/run time, e.g.:
///
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080   # Android emulator
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8080 # physical device
class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );
}
