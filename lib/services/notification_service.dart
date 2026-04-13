import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Lightweight DTO extracted from [RemoteMessage] for testability.
class NotificationData {
  final String? title;
  final String? body;
  final String? type;
  final String? bookingId;

  const NotificationData({this.title, this.body, this.type, this.bookingId});

  factory NotificationData.fromRemoteMessage(RemoteMessage message) {
    return NotificationData(
      title: message.notification?.title,
      body: message.notification?.body,
      type: message.data['type'] as String?,
      bookingId: message.data['booking_id'] as String?,
    );
  }

  /// Encode type and bookingId as a JSON string for local notification payload.
  String toPayload() => jsonEncode({'type': type, 'booking_id': bookingId});

  /// Decode a local notification payload back into [NotificationData].
  factory NotificationData.fromPayload(String payload) {
    final map = jsonDecode(payload) as Map<String, dynamic>;
    return NotificationData(
      type: map['type'] as String?,
      bookingId: map['booking_id'] as String?,
    );
  }
}

/// Result of [NotificationRouter.routeFor] — the route and optional args.
class NotificationNavigation {
  final String route;
  final String? tab;
  final Map<String, dynamic>? arguments;

  const NotificationNavigation({
    required this.route,
    this.tab,
    this.arguments,
  });
}

/// Maps notification types to in-app navigation routes.
class NotificationRouter {
  static NotificationNavigation? routeFor({
    required String? type,
    String? bookingId,
  }) {
    switch (type) {
      case 'booking_confirmed':
        return const NotificationNavigation(route: '/home', tab: 'upcoming');
      case 'new_message':
        return NotificationNavigation(
          route: '/chat',
          arguments: {'booking_id': bookingId},
        );
      case 'walk_started':
        return NotificationNavigation(
          route: '/active-walk',
          arguments:
              bookingId != null ? {'booking_id': bookingId} : null,
        );
      case 'walk_completed':
        return const NotificationNavigation(route: '/home', tab: 'past');
      case 'walk_request':
        return NotificationNavigation(
          route: '/walk-request',
          arguments: bookingId != null ? {'booking_id': bookingId} : null,
        );
      default:
        return null;
    }
  }
}

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

  /// Foreground messages stream.
  Stream<NotificationData> get onMessage =>
      FirebaseMessaging.onMessage.map(NotificationData.fromRemoteMessage);

  /// Background notification tap stream.
  Stream<NotificationData> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp
          .map(NotificationData.fromRemoteMessage);

  /// Notification that launched the app from terminated state.
  Future<NotificationData?> getInitialMessage() async {
    final message = await _messaging.getInitialMessage();
    return message != null
        ? NotificationData.fromRemoteMessage(message)
        : null;
  }
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

/// Thin wrapper around [FlutterLocalNotificationsPlugin] for testability.
class LocalNotificationsWrapper {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Callback invoked when user taps a local notification.
  void Function(String? payload)? onTap;

  Future<void> initialize() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    final initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        onTap?.call(response.payload);
      },
    );
  }

  Future<void> show({
    required String? title,
    required String? body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'pawgo_default',
      'Pawgo Notifications',
      channelDescription: 'Pawgo app notifications',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }
}

/// Manages FCM token registration, permission requests, message handling,
/// foreground notifications, and deep-link navigation.
class NotificationService {
  NotificationService._({
    FirebaseMessagingWrapper? messaging,
    SupabaseAuthWrapper? auth,
    LocalNotificationsWrapper? localNotifications,
    void Function(NotificationNavigation)? onNotificationTap,
  })  : _messagingOverride = messaging,
        _authOverride = auth,
        _localNotificationsOverride = localNotifications,
        _onNotificationTap = onNotificationTap;

  static final NotificationService instance = NotificationService._();

  final FirebaseMessagingWrapper? _messagingOverride;
  final SupabaseAuthWrapper? _authOverride;
  final LocalNotificationsWrapper? _localNotificationsOverride;
  void Function(NotificationNavigation)? _onNotificationTap;

  // Lazy initialization to avoid accessing FirebaseMessaging.instance before
  // Firebase.initializeApp().
  late final FirebaseMessagingWrapper _messaging =
      _messagingOverride ?? FirebaseMessagingWrapper();
  late final SupabaseAuthWrapper _auth =
      _authOverride ?? SupabaseAuthWrapper();
  late final LocalNotificationsWrapper _localNotifications =
      _localNotificationsOverride ?? LocalNotificationsWrapper();

  /// Create an instance with injected dependencies for testing.
  factory NotificationService.forTesting({
    required FirebaseMessagingWrapper messaging,
    required SupabaseAuthWrapper auth,
    LocalNotificationsWrapper? localNotifications,
    void Function(NotificationNavigation)? onNotificationTap,
  }) =>
      NotificationService._(
        messaging: messaging,
        auth: auth,
        localNotifications: localNotifications,
        onNotificationTap: onNotificationTap,
      );

  /// Set the navigation callback. Called from main.dart once navigator is ready.
  set onNotificationTap(void Function(NotificationNavigation) callback) {
    _onNotificationTap = callback;
  }

  String? _currentToken;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<NotificationData>? _foregroundSub;
  StreamSubscription<NotificationData>? _backgroundTapSub;

  /// Request notification permissions, get FCM token, store it, set up message
  /// handlers, and listen for token refreshes.
  Future<void> initialize() async {
    // Initialize local notifications for foreground display
    _localNotifications.onTap = _handleLocalNotificationTap;
    await _localNotifications.initialize();

    final granted = await _messaging.requestPermission();
    if (!granted) {
      _listenForTokenRefresh();
      _setupMessageHandlers();
      return;
    }

    final token = await _messaging.getToken();
    if (token != null) {
      _currentToken = token;
      await _registerToken(token);
    }

    _listenForTokenRefresh();
    _setupMessageHandlers();
  }

  /// Remove the current device's FCM token from the user's metadata.
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
    _foregroundSub?.cancel();
    _foregroundSub = null;
    _backgroundTapSub?.cancel();
    _backgroundTapSub = null;
  }

  void _setupMessageHandlers() {
    // Foreground: show local notification
    _foregroundSub?.cancel();
    _foregroundSub = _messaging.onMessage.listen(_showForegroundNotification);

    // Background tap: navigate
    _backgroundTapSub?.cancel();
    _backgroundTapSub =
        _messaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Terminated-state tap: navigate
    _messaging.getInitialMessage().then((data) {
      if (data != null) _handleNotificationTap(data);
    });
  }

  void _showForegroundNotification(NotificationData data) {
    _localNotifications.show(
      title: data.title,
      body: data.body,
      payload: data.toPayload(),
    );
  }

  void _handleNotificationTap(NotificationData data) {
    final nav = NotificationRouter.routeFor(
      type: data.type,
      bookingId: data.bookingId,
    );
    if (nav != null) {
      _onNotificationTap?.call(nav);
    }
  }

  void _handleLocalNotificationTap(String? payload) {
    if (payload == null) return;
    try {
      final data = NotificationData.fromPayload(payload);
      _handleNotificationTap(data);
    } catch (e) {
      debugPrint('NotificationService: Failed to parse payload: $e');
    }
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
