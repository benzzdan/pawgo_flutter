import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin wrapper around [FirebaseMessaging] for testability.
class FirebaseMessagingWrapper {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  Future<String?> getToken() => _messaging.getToken();

  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;
}

/// Thin wrapper around Supabase auth for FCM token storage.
class SupabaseAuthWrapper {
  String? getCurrentUserId() =>
      Supabase.instance.client.auth.currentUser?.id;

  Future<List<String>> getFcmTokens() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return [];
    final metadata = user.userMetadata;
    if (metadata == null) return [];
    final tokens = metadata['fcm_tokens'];
    if (tokens is List) {
      return tokens.cast<String>();
    }
    return [];
  }

  Future<void> updateFcmTokens(List<String> tokens) async {
    await Supabase.instance.client.auth.updateUser(
      UserAttributes(data: {'fcm_tokens': tokens}),
    );
  }
}

/// Manages FCM token registration, permission requests, and token lifecycle.
class NotificationService {
  NotificationService._({
    FirebaseMessagingWrapper? messaging,
    SupabaseAuthWrapper? auth,
  })  : _messagingOverride = messaging,
        _authOverride = auth;

  static final NotificationService instance = NotificationService._();

  final FirebaseMessagingWrapper? _messagingOverride;
  final SupabaseAuthWrapper? _authOverride;

  // Lazy initialization to avoid accessing FirebaseMessaging.instance before
  // Firebase.initializeApp().
  late final FirebaseMessagingWrapper _messaging =
      _messagingOverride ?? FirebaseMessagingWrapper();
  late final SupabaseAuthWrapper _auth =
      _authOverride ?? SupabaseAuthWrapper();

  /// Create an instance with injected dependencies for testing.
  factory NotificationService.forTesting({
    required FirebaseMessagingWrapper messaging,
    required SupabaseAuthWrapper auth,
  }) =>
      NotificationService._(messaging: messaging, auth: auth);

  String? _currentToken;
  StreamSubscription<String>? _tokenRefreshSub;

  /// Request notification permissions, get FCM token, store it, and listen
  /// for token refreshes.
  Future<void> initialize() async {
    final granted = await _messaging.requestPermission();
    if (!granted) {
      // Still listen for token refresh in case user enables later
      _listenForTokenRefresh();
      return;
    }

    final token = await _messaging.getToken();
    if (token != null) {
      _currentToken = token;
      await _registerToken(token);
    }

    _listenForTokenRefresh();
  }

  /// Remove the current device's FCM token from the user's metadata.
  /// Call this on sign-out.
  Future<void> removeToken() async {
    if (_currentToken == null) return;

    try {
      final existingTokens = await _auth.getFcmTokens();
      final updatedTokens =
          existingTokens.where((t) => t != _currentToken).toList();
      await _auth.updateFcmTokens(updatedTokens);
    } catch (e) {
      debugPrint('NotificationService: Failed to remove token: $e');
    }
    _currentToken = null;
  }

  /// Cancel subscriptions.
  void dispose() {
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
  }

  void _listenForTokenRefresh() {
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = _messaging.onTokenRefresh.listen((newToken) async {
      _currentToken = newToken;
      await _registerToken(newToken);
    });
  }

  Future<void> _registerToken(String token) async {
    try {
      final userId = _auth.getCurrentUserId();
      if (userId == null) return;

      final existingTokens = await _auth.getFcmTokens();
      if (existingTokens.contains(token)) return;

      final updatedTokens = [...existingTokens, token];
      await _auth.updateFcmTokens(updatedTokens);
    } catch (e) {
      debugPrint('NotificationService: Failed to register token: $e');
    }
  }
}
