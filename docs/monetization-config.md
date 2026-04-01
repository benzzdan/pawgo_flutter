# Monetization Configuration Guide

Production configuration for RevenueCat (in-app purchases) and AdMob (ads) in Pawgo.

---

## RevenueCat

### Overview

RevenueCat handles the payment flow for dog walk bookings. The `PaymentScreen` uses `purchases_flutter` to present offerings, process purchases, and confirm payments via the `confirm-payment` Edge Function.

### API Key Location

**Flutter:** `lib/config/env.dart`

The `Env` class needs a `revenueCatApiKey` field per environment:

```dart
class Env {
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String revenueCatApiKey; // Add this

  static const local = Env._(
    supabaseUrl: 'http://localhost:8000',
    supabaseAnonKey: '...',
    revenueCatApiKey: '', // Empty = sandbox/mock mode
  );

  static const production = Env._(
    supabaseUrl: 'https://your-project.supabase.co',
    supabaseAnonKey: 'your-production-anon-key',
    revenueCatApiKey: 'your-revenuecat-public-api-key', // From RevenueCat dashboard
  );
}
```

Alternatively, use `--dart-define` at build time (see Environment Separation below).

### Entitlement Configuration

1. **RevenueCat Dashboard:** Create a project and add your app (iOS + Android)
2. **Entitlement:** Create `premium` entitlement — this is checked by `AdService` to gate ads
3. **Offering:** Create a default offering with products for walk booking payments
4. **Products:** Map to App Store Connect / Google Play Console products

`AdService.refreshPremiumStatus()` checks `customerInfo.entitlements.all['premium']?.isActive`.

### Sandbox Purchase Testing

1. **iOS:** Add sandbox testers in App Store Connect → Users and Access → Sandbox
2. **Android:** Add license testers in Google Play Console → Setup → License testing
3. RevenueCat dashboard → set Sandbox mode for testing
4. In `PaymentScreen`, purchases automatically use sandbox when the app is built in debug/TestFlight

### Webhook URL Registration

Register the `confirm-payment` Edge Function as a RevenueCat webhook:

1. **RevenueCat Dashboard** → Project → Integrations → Webhooks
2. **Webhook URL:** `https://your-project.supabase.co/functions/v1/confirm-payment`
3. **Shared Secret:** Set `REVENUECAT_WEBHOOK_SECRET` in your Supabase project environment variables
4. **Events:** Enable `INITIAL_PURCHASE`, `RENEWAL`, `CANCELLATION`

The `confirm-payment` function validates the webhook signature via `X-RevenueCat-Signature` header.

---

## AdMob

### Overview

`AdService` (singleton at `lib/services/ad_service.dart`) manages banner and interstitial ads for free-tier users. Premium users (active RevenueCat entitlement) see no ads. Ads are never shown on GPS tracking or chat screens (safety-critical).

### App ID Locations

**iOS:** `ios/Runner/Info.plist`

Add the `GADApplicationIdentifier` key:

```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY</string>
```

**Android:** `android/app/src/main/AndroidManifest.xml`

Add inside `<application>`:

```xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY"/>
```

### Ad Unit IDs to Replace

In `lib/services/ad_service.dart`, replace test IDs with production IDs:

| Constant | Current (Test) | Replace With |
|----------|---------------|-------------|
| `_testBannerAdUnitId` | `ca-app-pub-3940256099942544/6300978111` | Your production banner ad unit ID |
| `_testInterstitialAdUnitId` | `ca-app-pub-3940256099942544/1033173712` | Your production interstitial ad unit ID |

Create ad units in the [AdMob Console](https://admob.google.com/):
- **Banner:** Standard banner for non-critical screens
- **Interstitial:** For natural transition points (e.g., after booking confirmation)

### Test Device Setup

During development, register test devices to avoid invalid traffic:

```dart
// In AdService.initialize() or app startup:
MobileAds.instance.updateRequestConfiguration(
  RequestConfiguration(testDeviceIds: ['YOUR-TEST-DEVICE-ID']),
);
```

Get the test device ID from the AdMob console logs or device debug output.

---

## Environment Separation

### Option 1: Env class (current pattern)

Switch between `Env.local` and `Env.production` in `lib/config/env.dart`:

```dart
static const current = local;      // Development
static const current = production;  // Production build
```

### Option 2: `--dart-define` (recommended for CI/CD)

Pass keys at build time without committing them:

```bash
# Development build
flutter run \
  --dart-define=REVENUECAT_API_KEY="" \
  --dart-define=ADMOB_BANNER_ID="ca-app-pub-3940256099942544/6300978111"

# Production build
flutter build ios \
  --dart-define=REVENUECAT_API_KEY="your-real-key" \
  --dart-define=ADMOB_BANNER_ID="your-real-banner-id" \
  --dart-define=ADMOB_INTERSTITIAL_ID="your-real-interstitial-id"
```

Read in Dart:

```dart
const revenueCatKey = String.fromEnvironment('REVENUECAT_API_KEY');
const bannerAdId = String.fromEnvironment('ADMOB_BANNER_ID',
    defaultValue: 'ca-app-pub-3940256099942544/6300978111');
```

### Option 3: `.env` file (with `flutter_dotenv`)

Add `flutter_dotenv` package, create `.env` and `.env.production` files (gitignored), and load at runtime. This approach works well for local development but requires `--dart-define` or equivalent for CI.

---

## Production Checklist

- [ ] RevenueCat API key set in production environment
- [ ] RevenueCat webhook URL registered and tested
- [ ] `REVENUECAT_WEBHOOK_SECRET` set in Supabase environment
- [ ] AdMob App IDs added to iOS `Info.plist` and Android `AndroidManifest.xml`
- [ ] Test ad unit IDs replaced with production IDs in `AdService`
- [ ] Test devices registered for development
- [ ] `premium` entitlement created in RevenueCat dashboard
- [ ] No production keys committed to the repository
- [ ] Ads confirmed NOT showing on GPS tracking or chat screens
