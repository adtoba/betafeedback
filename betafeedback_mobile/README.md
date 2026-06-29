# betafeedback_mobile

The Flutter client for BetaFeedback. It talks to the Go API in
`../betafeedback_backend` for all data — auth, projects, feedback, bugs, the
test plan, releases, activity, notifications, and subscriptions.

## Running against the backend

1. Start the backend (see `../betafeedback_backend/README.md`):

   ```bash
   cd ../betafeedback_backend && make run   # serves on :8080
   ```

2. Run the app, pointing it at the backend. The base URL defaults to
   `http://localhost:8080` (works from the **iOS Simulator**). Override per
   platform with `--dart-define`:

   ```bash
   # iOS Simulator (default)
   flutter run

   # Android emulator (host is reachable at 10.0.2.2)
   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080

   # Physical device on your LAN
   flutter run --dart-define=API_BASE_URL=http://<your-mac-ip>:8080
   ```

## Sign-in

Email one-time code. Enter an email, then the 6-digit code. In development the
backend runs with `OTP_DEBUG=true`, so the code is shown on the verification
screen ("Dev code: …") instead of being emailed. Social sign-in (Google/Apple)
is stubbed until the backend supports it.

## Architecture

- `lib/services/` — `ApiClient` (bearer-token JSON HTTP) and `ApiConfig`.
- `lib/data/app_state.dart` — `ChangeNotifier` that calls the API and caches
  results; the UI reads cached data synchronously and rebuilds on change.
- `lib/models/` — domain types with `fromJson` parsing.
- `lib/screens/`, `lib/widgets/` — UI.

Tests (`test/widget_test.dart`) use `package:http`'s `MockClient` to drive the
app without a live server.
