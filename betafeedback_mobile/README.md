# betafeedback_mobile

The Flutter client for BetaFeedback. It talks to the Go API in
`../betafeedback_backend` for all data — auth, projects, feedback, bugs, the
test plan, releases, activity, notifications, and subscriptions.

## Running against the backend

1. Start the backend (see `../betafeedback_backend/README.md`):

   ```bash
   cd ../betafeedback_backend && make run   # serves on :8080
   ```

2. Copy env config and run:

   ```bash
   cp .env.example .env   # once
   # edit .env — e.g. API_BASE_URL=http://10.0.2.2:8080 for Android emulator
   flutter run
   ```

   | Device              | `API_BASE_URL`                         |
   |---------------------|----------------------------------------|
   | iOS Simulator       | `http://localhost:8080` (default)      |
   | Android emulator    | `http://10.0.2.2:8080`                 |
   | Physical device     | `http://<your-mac-ip>:8080`            |

   `.env` is bundled into the app — only put **client** config there (API URL,
   public RevenueCat keys). Never put server secrets (JWT, Firebase private key).

## Sign-in

**Email** — one-time code. In development (`OTP_DEBUG=true`) the code appears on the verification screen.

**Google** — uses the same `/v1/auth/google` endpoint as the web dashboard.

1. In Google Cloud, create OAuth clients for **Web**, **iOS** (`com.betafeedback.app`), and **Android** (`com.betafeedback.app` + SHA-1).
2. In `betafeedback_backend/.env`:

   ```bash
   GOOGLE_CLIENT_ID=your-web-client-id.apps.googleusercontent.com
   GOOGLE_IOS_CLIENT_ID=your-ios-client-id.apps.googleusercontent.com
   ```

3. **iOS:** follow [ios/GoogleSignIn.md](ios/GoogleSignIn.md) to update `Info.plist`.
4. **Android:** no extra Dart config — the app uses the web client ID as `serverClientId`. Register your debug SHA-1 on the Android OAuth client:

   ```bash
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
   ```

Optional Google client ID overrides can go in `.env` as `GOOGLE_WEB_CLIENT_ID` /
`GOOGLE_IOS_CLIENT_ID` (otherwise the app uses `GET /v1/auth/config`).

Apple sign-in is still coming soon.

## Push notifications (FCM)

See [docs/FIREBASE_SETUP.md](docs/FIREBASE_SETUP.md) for Firebase project setup, `flutterfire configure`, and backend service account configuration.

Push alerts fire for new releases, feedback, and AI-suggested bugs. Toggle them in **Profile → Push notifications**.

## Subscriptions (RevenueCat)

Pro upgrades go through RevenueCat / App Store / Play Billing. See
[docs/REVENUECAT_SETUP.md](docs/REVENUECAT_SETUP.md).

Put the public SDK keys in `.env`:

```bash
REVENUECAT_IOS_API_KEY=appl_xxx
REVENUECAT_ANDROID_API_KEY=goog_xxx
```

Without those keys (local dev), the upgrade sheet uses the backend stub plan
toggle (`ENV=development` only).

## Architecture

- `lib/services/` — `ApiClient`, `BillingService` (RevenueCat), `ApiConfig`.
- `lib/data/app_state.dart` — `ChangeNotifier` that calls the API and caches
  results; the UI reads cached data synchronously and rebuilds on change.
- `lib/models/` — domain types with `fromJson` parsing.
- `lib/screens/`, `lib/widgets/` — UI.

Tests (`test/widget_test.dart`) use `package:http`'s `MockClient` to drive the
app without a live server.
