import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Centralized analytics service using PostHog.
///
/// Tracks key user events for product analytics.
/// Use [AnalyticsService.instance] singleton throughout the app.
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  bool _initialized = false;

  Future<void> initialize({
    required String apiKey,
    required String host,
  }) async {
    if (_initialized) return;
    try {
      final config = PostHogConfig(apiKey);
      config.host = host;
      config.debug = false;
      config.captureApplicationLifecycleEvents = true;
      await Posthog().setup(config);
      _initialized = true;

      // Identify user if already logged in
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await identify(user.id);
      }
    } catch (e) {
      // Analytics should never crash the app
    }
  }

  Future<void> identify(String userId) async {
    if (!_initialized) return;
    try {
      await Posthog().identify(userId: userId);
    } catch (_) {}
  }

  Future<void> reset() async {
    if (!_initialized) return;
    try {
      await Posthog().reset();
    } catch (_) {}
  }

  Future<void> capture(String eventName, [Map<String, Object>? properties]) async {
    if (!_initialized) return;
    try {
      await Posthog().capture(
        eventName: eventName,
        properties: properties,
      );
    } catch (_) {}
  }

  // ── User events ──

  Future<void> userSignedUp() => capture('user_signed_up');

  // ── Walker events ──

  Future<void> walkerProfileViewed(String walkerId) =>
      capture('walker_profile_viewed', {'walker_id': walkerId});

  // ── Booking events ──

  Future<void> bookingInitiated({required String walkerId}) =>
      capture('booking_initiated', {'walker_id': walkerId});

  Future<void> bookingCompleted({required String bookingId}) =>
      capture('booking_completed', {'booking_id': bookingId});

  Future<void> bookingCancelled({required String bookingId}) =>
      capture('booking_cancelled', {'booking_id': bookingId});

  // ── Walk events ──

  Future<void> walkStarted({required String bookingId}) =>
      capture('walk_started', {'booking_id': bookingId});

  Future<void> walkCompleted({required String bookingId}) =>
      capture('walk_completed', {'booking_id': bookingId});

  // ── Review events ──

  Future<void> reviewSubmitted({required String bookingId, required int rating}) =>
      capture('review_submitted', {
        'booking_id': bookingId,
        'rating': rating,
      });

  // ── Monetization events ──

  Future<void> premiumUpgradeTapped() => capture('premium_upgrade_tapped');

  Future<void> paymentFailed({required String bookingId, String? error}) {
    final props = <String, Object>{'booking_id': bookingId};
    if (error != null) props['error'] = error;
    return capture('payment_failed', props);
  }

  Future<void> adDismissed({required String adType}) =>
      capture('ad_dismissed', {'ad_type': adType});

  // ── Error tracking ──

  Future<void> errorOccurred({
    required String errorCode,
    required String message,
    String? screen,
  }) {
    final props = <String, Object>{
      'error_code': errorCode,
      'message': message,
    };
    if (screen != null) props['screen'] = screen;
    return capture('error_occurred', props);
  }
}
