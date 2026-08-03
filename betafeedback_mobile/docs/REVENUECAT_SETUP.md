# RevenueCat setup (Pro subscriptions)

BetaFeedback uses **RevenueCat** for App Store / Play Billing. The mobile SDK
handles purchases; the Go API receives webhooks and updates `subscriptions`.

Entitlement id: **`pro`** (must match backend `REVENUECAT_ENTITLEMENT_ID`).

## 1. Create products in the stores

### App Store Connect
1. Create an auto-renewable subscription (e.g. monthly **$12**).
2. Product id suggestion: `pro_monthly`.
3. Complete paid apps agreement + tax/banking.

### Google Play Console
1. Create a subscription with a base plan (monthly).
2. Product id suggestion: `pro_monthly` (can match iOS).
3. Activate the subscription.

## 2. Configure RevenueCat

1. Create a project at [app.revenuecat.com](https://app.revenuecat.com).
2. Add **iOS** and **Android** apps (`com.betafeedback.app`).
3. Paste App Store / Play credentials (shared secret / service account).
4. **Products** → import / add `pro_monthly` (and annual if you add one).
5. **Entitlements** → create `pro` → attach the product(s).
6. **Offerings** → create an offering (e.g. `default`), add a **Monthly**
   package linked to `pro_monthly`, set the offering as **Current**.
7. **API keys** → copy the public **Apple** and **Google** keys (`appl_…`, `goog_…`).

## 3. Mobile app

Add the public SDK keys to `.env` (see `.env.example`):

```bash
API_BASE_URL=https://api.betafeedback.com
REVENUECAT_IOS_API_KEY=appl_xxx
REVENUECAT_ANDROID_API_KEY=goog_xxx
```

Then `flutter run`. Without keys, the app falls back to the **dev-only** plan
stub (`PUT /v1/me/subscription`), which only works when the API
`ENV=development`.

Also enable **In-App Purchase** capability on the iOS Runner target in Xcode.

## 4. Backend webhook

1. Expose `POST https://<your-api>/v1/webhooks/revenuecat` (HTTPS required).
2. RevenueCat → **Integrations** → **Webhooks** → add URL.
3. Set an **Authorization** header value (long random secret).
4. In `betafeedback_backend/.env`:

```bash
REVENUECAT_WEBHOOK_AUTH=Bearer your-long-random-secret
REVENUECAT_ENTITLEMENT_ID=pro
```

Use the exact same Authorization string RevenueCat sends.

5. Restart the API and send a **Test** event from the dashboard.

Users are identified by BetaFeedback user UUID (`Purchases.logIn(userId)` after
sign-in). Webhooks update plan / status / renews_on.

## 5. “No App Store products registered” / empty offerings

If Xcode / Flutter logs say:

> You have configured the SDK with an App Store API key, but there are no App
> Store products registered in the RevenueCat dashboard for your offerings.

the **SDK key is fine**. The Current offering has no **App Store** product on
its packages. Fix in the dashboard (not in app code):

1. **App Store Connect** → Subscriptions → create `pro_monthly` (or your id),
   fill localization + price + review screenshot until status is at least
   **Ready to Submit**. Sign Paid Apps Agreement + tax/banking.
2. **RevenueCat → Apps** → iOS app bundle `com.betafeedback.app` → connect
   App Store Connect API / In-App Purchase key.
3. **Product catalog** → add/import that same product id as an **App Store**
   product (not Play-only).
4. **Entitlements** → `pro` → attach that product.
5. **Offerings** → `default` (or similar) → **Add package** → type **Monthly**
   → select the App Store product → **Make current**.

Verify: Offerings → Current → package row must show an **App Store** product
id. If that column is blank, the SDK warning will keep appearing.

On a debug run, `BillingService` prints an offerings dump at startup
(`RevenueCat offerings:`). You want `current:` set and `packages: ≥ 1`.

## 6. Local testing tips

| Scenario | How |
|----------|-----|
| No RC keys | Dev stub `changePlan` / upgrade sheet still works against local API |
| iOS sandbox | Physical device + Sandbox Apple ID (Settings → App Store → Sandbox) |
| Android | License testers in Play Console + real `goog_…` key (not a placeholder) |
| Webhook locally | [ngrok](https://ngrok.com) → `https://xxx.ngrok.io/v1/webhooks/revenuecat` |

## Event → plan mapping

| RevenueCat event | Backend effect |
|------------------|----------------|
| `INITIAL_PURCHASE` / `RENEWAL` / … | `plan=pro`, `status=active` (or `trialing`) |
| `BILLING_ISSUE` | `plan=pro`, `status=past_due` |
| `CANCELLATION` | Keep Pro until expiration |
| `EXPIRATION` | `plan=free` |
