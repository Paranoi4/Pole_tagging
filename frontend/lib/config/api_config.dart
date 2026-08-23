/// Where the Poletagging API lives.
///
/// `localhost` means "this device", so the default only works when the app and
/// the backend run on the same machine - Chrome or a desktop build on your PC.
/// On a real phone or emulator it points at the phone itself and every request
/// fails, so override it at launch instead of editing this file:
///
/// ```
/// flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000
/// ```
///
/// Common values:
///   * Chrome / Windows desktop -> http://localhost:8000
///   * Android emulator         -> http://10.0.2.2:8000
///   * Real device on your wifi -> http://<your-pc-lan-ip>:8000
class ApiConfig {
  const ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );
}
