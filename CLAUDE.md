# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

pawgo_flutter is the Flutter mobile app for Pawgo, an on-demand dog-walking platform. It connects to a self-hosted Supabase backend (`Pawgo-api`) for auth, data, realtime, storage, and Edge Functions.

## Commands

```bash
# Run the app
flutter run

# Lint — must pass with zero errors (info-level warnings are acceptable)
flutter analyze

# Run all tests
flutter test

# Run a single test file
flutter test test/some_test.dart
```

## Architecture

Named-route navigation, singleton services, Supabase as sole backend.

### Environment Config

`lib/config/env.dart` has two profiles: `Env.local` (localhost:8000 with demo anon key) and `Env.production`. Supabase is initialized in `main.dart` before `runApp()` — use `Supabase.instance.client` throughout.

### Singleton Services (`lib/services/`)

| Service | Purpose |
|---|---|
| `GpsBroadcastService` | Sends walker GPS every 5s during active walks. Persists across screen navigation. Call `resumeIfActiveWalk()` on app start. |
| `ErrorHandler` + `AppError` | Centralized error parsing. `withRetry()` wraps async calls with 3x exponential backoff on network errors only. `showRecoverableError()` (SnackBar), `showBlockingError()` (Dialog). Auth errors redirect to login. |
| `AdService` | AdMob banners/interstitials for free-tier users. Checks RevenueCat premium status. **Never show ads on GPS tracking or chat screens.** |
| `AnalyticsService` | PostHog event tracking. All calls wrapped in try/catch. Call `identify()` on sign-in, `reset()` on sign-out. |
| `RealtimeManager` | Auto-reconnects Supabase Realtime channels. Falls back to REST polling every 10s on disconnect. |
| `RoleService` | Detects user role (owner/walker/both) by querying `walkers` table. Exposes `role` and `activeRole` ValueNotifiers. Call `switchRole()` to toggle, `refresh()` after application approval, `reset()` on sign-out. |

### Key Patterns

**Supabase queries**:
- FK joins: `select('..., users(full_name, avatar_url)')` — accessed as `row['users']['field']`
- Disambiguate multiple FKs to same table: `users!bookings_owner_id_fkey(full_name, avatar_url)`
- Realtime UPDATE payloads don't include joined data — preserve existing joined fields when merging updates
- Edge Function responses: assign `res.data` to a local var before `?[]` null-aware access in ternary expressions

**Auth**:
- `_AuthGate` widget in main.dart listens to `onAuthStateChange` and handles redirect
- Sign-in/sign-up screens should NOT redirect to login on auth errors (user is already there)
- Walker detection: compare `auth.currentUser.id` to `booking['walkers']['user_id']` (walker profile user_id, not walker.id)

**Chat**:
- Status updates use `media_type: 'status_update'` with content text — rendered as centered pill badges
- Realtime INSERT only gives new record without joins — fetch full message separately

### Theme (`lib/theme/app_theme.dart`)

- Brand colors: `AppColors.cacaoBrown` (#4A2C2A), `AppColors.warmCaramel` (#C07D4D), `AppColors.goldenPaw` (#F4A832)
- Spacing tokens: `AppSpacing.xs/sm/md/lg/xl` (4/8/16/24/32) — use instead of hardcoded values
- Dark mode: `AppTheme.darkTheme` auto-switches by device setting
- Font: Nunito (weights 400/600/700/800)
- All buttons enforce 48px minimum tap targets

### Platform Config

- **iOS**: Info.plist has location permission descriptions and `UIBackgroundModes` with location
- **Android**: AndroidManifest.xml has `ACCESS_FINE_LOCATION`, `ACCESS_BACKGROUND_LOCATION`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`
- **Google Maps**: Requires API keys in iOS AppDelegate and Android AndroidManifest.xml (not needed for `flutter analyze`, only runtime)

### Business Logic

- 18% commission on bookings (calculated server-side in create-booking Edge Function)
- RevenueCat for payments; confirm-payment Edge Function validates webhook
- Insurance claim caps: veterinary $5000, liability $4000, property $4000 MXN

## CI

GitHub Actions (`.github/workflows/ci.yml`): `flutter analyze` + `flutter test`. Triggers on PRs to main.

## Git

- Development branch: `ralph/dog-walking-app-v1`
