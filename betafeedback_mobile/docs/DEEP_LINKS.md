# Deep linking (Universal Links / App Links)

Email CTAs use HTTPS URLs that open the BetaFeedback app when installed:

```
https://betafeedback.com/open/projects/{projectId}
```

Fallback custom scheme (used by the web bridge page):

```
betafeedback://projects/{projectId}
```

## What’s wired in the app

- Package: `app_links`
- iOS: Associated Domains `applinks:betafeedback.com` (+ `www`) in
  `ios/Runner/Runner.entitlements`, custom scheme `betafeedback` in `Info.plist`
- Android: `intent-filter` for `betafeedback://` and verified HTTPS `/open` + `/join`
- Navigation: [`lib/services/deep_link_service.dart`](../lib/services/deep_link_service.dart)
  opens `ProjectDetailScreen` after the user is signed in (pending links queue until then)

## Website association files

Hosted by the marketing site (`betafeedback_web`):

- `https://betafeedback.com/.well-known/apple-app-site-association`
- `https://betafeedback.com/.well-known/assetlinks.json`

`assetlinks.json` currently includes the **debug** keystore SHA-256. Before Play
production App Links work, add your **Play App Signing** certificate fingerprint:

```bash
# Local debug keystore (already in assetlinks.json)
keytool -list -v -keystore ~/.android/debug.keystore \
  -alias androiddebugkey -storepass android -keypass android

# Or from Play Console → App integrity → App signing key certificate → SHA-256
```

## Verify

**iOS (device, not Simulator for best results):**

1. Install a build signed with team `S2BAR9U8D8`
2. Confirm AASA is reachable (JSON, HTTPS, no redirects):
   `curl -I https://betafeedback.com/.well-known/apple-app-site-association`
3. Tap an email “Open project” link — should open the app, not Safari

**Android:**

1. `adb shell pm get-app-links com.betafeedback.app`
2. Domain should show `verified` for `betafeedback.com` after install + association fetch

Until association is verified, the open-in-app web page’s **Open in BetaFeedback**
button (custom scheme) still works when the app is installed.
