# Firebase & push notifications setup

BetaFeedback uses **FCM** (Firebase Cloud Messaging) for mobile push. The backend sends pushes when:

- A **release** is posted (all project members except the poster)
- **New feedback** arrives (developers & creators)
- An **AI-suggested bug** is ready for review (developers & creators)

## 1. Create a Firebase project

1. Open [Firebase Console](https://console.firebase.google.com/) → **Add project** (or use an existing one).
2. Add an **Android** app:
   - Package name: `com.betafeedback.app`
   - Download `google-services.json` → place in `android/app/`
3. Add an **iOS** app:
   - Bundle ID: `com.betafeedback.app`
   - Download `GoogleService-Info.plist` → add to `ios/Runner/` in Xcode (copy into the Runner target).

## 2. FlutterFire configuration

Install the CLI and generate `lib/firebase_options.dart`:

```bash
dart pub global activate flutterfire_cli
cd betafeedback_mobile
flutterfire configure
```

This replaces the placeholder `firebase_options.dart` in the repo.

## 3. iOS: APNs key

1. In [Apple Developer](https://developer.apple.com/) → Keys → create an **APNs** key.
2. In Firebase → Project settings → **Cloud Messaging** → upload the APNs key (.p8).

## 4. Backend service account

1. Firebase → Project settings → **Service accounts** → **Generate new private key**.
2. Save the JSON file outside the repo (e.g. `betafeedback_backend/firebase-service-account.json`).
3. Add to `betafeedback_backend/.env`:

```bash
FIREBASE_CREDENTIALS_PATH=./firebase-service-account.json
```

4. Restart the API. When unset, pushes are **logged** to stdout instead of sent (same as SMTP in dev).

## 5. Run migrations

```bash
cd betafeedback_backend
make migrate   # or your usual migration command
```

Migration `0009_push_notifications.sql` adds `device_tokens` and `users.push_notifications`.

## 6. Test

1. Start backend + run the app on a **physical device** (push is unreliable on simulators).
2. Sign in → Profile → ensure **Push notifications** is on.
3. From another account, post feedback or a release on a shared project.
4. Tap the notification → should open the project.

## API

| Method | Path | Body |
|--------|------|------|
| `POST` | `/v1/devices` | `{ "token": "…", "platform": "ios" \| "android" }` |
| `DELETE` | `/v1/devices` | `{ "token": "…" }` |
| `PUT` | `/v1/me/preferences` | `{ "push_notifications": true \| false }` |

Push payloads include `project_id` and `kind` (`release`, `feedback`, `bug`) for deep linking.
