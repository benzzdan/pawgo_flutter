import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pawgo/utils/gps_broadcast_helpers.dart';

/// Service that broadcasts the walker's GPS coordinates to Supabase
/// every 5 seconds during an active walk.
class GpsBroadcastService {
  GpsBroadcastService._();
  static final GpsBroadcastService instance = GpsBroadcastService._();

  Timer? _broadcastTimer;
  String? _activeBookingId;
  bool _isBroadcasting = false;
  Position? _lastPosition;

  /// Injected client for testing. Falls back to Supabase.instance.client.
  @visibleForTesting
  SupabaseClient? testClient;

  SupabaseClient get _client => testClient ?? Supabase.instance.client;

  /// Reset all state for testing.
  @visibleForTesting
  void resetForTesting() {
    stopBroadcasting();
    _lastPosition = null;
    positionNotifier.value = null;
    lastPermissionError = null;
    testClient = null;
  }

  /// Whether GPS broadcasting is currently active.
  bool get isBroadcasting => _isBroadcasting;

  /// Notifier for broadcasting state changes (UI can listen).
  ValueNotifier<bool> broadcastingNotifier = ValueNotifier(false);

  /// Reason for last permission failure (null if no failure).
  String? lastPermissionError;

  /// The booking ID currently being tracked.
  String? get activeBookingId => _activeBookingId;

  /// Last known position.
  Position? get lastPosition => _lastPosition;

  /// Callback for position updates (UI can listen to this).
  ValueNotifier<Position?> positionNotifier = ValueNotifier(null);

  /// Start broadcasting GPS for a given booking.
  /// Returns true if started successfully, false otherwise.
  Future<bool> startBroadcasting(String bookingId) async {
    if (_isBroadcasting && _activeBookingId == bookingId) return true;

    // Stop any existing broadcast
    stopBroadcasting();

    // Check and request permissions
    final hasPermission = await _ensureLocationPermission();
    if (!hasPermission) return false;

    _activeBookingId = bookingId;
    _isBroadcasting = true;
    broadcastingNotifier.value = true;

    // Send initial position immediately
    await _captureAndSendPosition();

    // Set up periodic broadcast every 15 seconds
    _broadcastTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _captureAndSendPosition(),
    );

    debugPrint('GPS broadcast started for booking: $bookingId');
    return true;
  }

  /// Stop broadcasting GPS.
  void stopBroadcasting() {
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    _isBroadcasting = false;
    _activeBookingId = null;
    broadcastingNotifier.value = false;
    debugPrint('GPS broadcast stopped');
  }

  /// Resume broadcasting for an active walk after app restart.
  /// Checks if there's an active walk for the current walker and resumes.
  Future<bool> resumeIfActiveWalk() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return false;

      // Find walker profile
      final walkerData = await _client
          .from('walkers')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

      if (walkerData == null) return false;
      final walkerId = walkerData['id'] as String;

      // Find active booking in any GPS-broadcast phase
      final booking = await _client
          .from('bookings')
          .select('id')
          .eq('walker_id', walkerId)
          .inFilter('status', gpsBroadcastActiveStatuses)
          .maybeSingle();

      if (booking == null) return false;

      final bookingId = booking['id'] as String;
      debugPrint('Resuming GPS broadcast for booking: $bookingId');

      // Load last known position from DB
      final lastLoc = await _client
          .from('walk_locations')
          .select('lat, lng, accuracy_m, recorded_at')
          .eq('booking_id', bookingId)
          .order('recorded_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (lastLoc != null) {
        debugPrint(
            'Resuming from last known position: ${lastLoc['lat']}, ${lastLoc['lng']}');
      }

      return await startBroadcasting(bookingId);
    } catch (e) {
      debugPrint('Error resuming GPS broadcast: $e');
      return false;
    }
  }

  Future<bool> _ensureLocationPermission() async {
    final result = await requestLocationPermissionInteractive();
    lastPermissionError = result.errorMessage;
    return result.granted;
  }

  /// Drives the OS location-permission flow without starting a broadcast.
  ///
  /// Use this from any screen that needs to prime / re-check location access
  /// (e.g. the permissions-priming screen the new welcome flow shows after
  /// sign-up). Returns a [LocationPermissionResult] with:
  /// - [LocationPermissionResult.granted] — whether the app currently has
  ///   permission to read coarse / fine location, and
  /// - [LocationPermissionResult.errorMessage] — a user-facing reason when
  ///   `granted == false` (services disabled, denied, denied-forever).
  ///
  /// Side effects: may trigger the OS permission dialog via
  /// `Geolocator.requestPermission()`. Does not start GPS broadcasting.
  static Future<LocationPermissionResult>
      requestLocationPermissionInteractive() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      const msg = 'Location services are disabled. Please enable GPS in your device settings.';
      debugPrint('Location services are disabled');
      return const LocationPermissionResult(granted: false, errorMessage: msg);
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        const msg = 'Location permission is required to broadcast your GPS position during walks.';
        debugPrint('Location permission denied');
        return const LocationPermissionResult(
            granted: false, errorMessage: msg);
      }
    }

    if (permission == LocationPermission.deniedForever) {
      const msg = 'Location permission was permanently denied. Please enable it in Settings > Pawgo > Location.';
      debugPrint('Location permission permanently denied');
      return const LocationPermissionResult(granted: false, errorMessage: msg);
    }

    return const LocationPermissionResult(granted: true, errorMessage: null);
  }

  Future<void> _captureAndSendPosition() async {
    if (!_isBroadcasting || _activeBookingId == null) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        ),
      );

      _lastPosition = position;
      positionNotifier.value = position;

      await _client.from('walk_locations').insert({
        'booking_id': _activeBookingId,
        'lat': position.latitude,
        'lng': position.longitude,
        'accuracy_m': position.accuracy,
        'recorded_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error capturing/sending GPS position: $e');
    }
  }
}

/// Outcome of [GpsBroadcastService.requestLocationPermissionInteractive].
///
/// [errorMessage] is non-null whenever [granted] is false, carrying a
/// user-facing reason (services disabled, denied, denied-forever).
class LocationPermissionResult {
  const LocationPermissionResult({
    required this.granted,
    required this.errorMessage,
  });

  final bool granted;
  final String? errorMessage;
}
