import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Centralized auth state management.
///
/// Listens to Supabase auth state changes and redirects to the login screen
/// when the session expires or is missing.
class AuthService {
  AuthService._();
  static final instance = AuthService._();

  /// Global navigator key — must be attached to MaterialApp.
  final navigatorKey = GlobalKey<NavigatorState>();

  StreamSubscription<AuthState>? _authSub;
  bool _hasActiveSession = false;

  /// Start listening to auth state changes.
  /// Call once after Supabase.initialize().
  void initialize() {
    _hasActiveSession =
        Supabase.instance.client.auth.currentSession != null;

    _authSub?.cancel();
    _authSub =
        Supabase.instance.client.auth.onAuthStateChange.listen(_onAuthChange);
  }

  void _onAuthChange(AuthState state) {
    final event = state.event;

    if (event == AuthChangeEvent.signedIn ||
        event == AuthChangeEvent.tokenRefreshed) {
      _hasActiveSession = true;
      return;
    }

    if (event == AuthChangeEvent.signedOut) {
      // Only redirect if user previously had a session (expired/revoked).
      if (_hasActiveSession) {
        _hasActiveSession = false;
        _redirectToLogin('Session expired. Please sign in again.');
      }
      return;
    }
  }

  /// Check whether the current user has a valid session.
  /// Returns true if session exists, false if missing (redirects to login).
  bool ensureAuthenticated() {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      _redirectToLogin('Please sign in to continue.');
      return false;
    }
    return true;
  }

  /// Handle an auth-related error from a Supabase call.
  /// Returns true if the error was an auth error and was handled.
  bool handleAuthError(Object error) {
    if (error is AuthException) {
      _redirectToLogin('Session expired. Please sign in again.');
      return true;
    }
    // Supabase REST calls return PostgrestException with code for JWT issues.
    if (error is PostgrestException) {
      final code = error.code;
      // PGRST301 = JWT expired, 401/403-class errors
      if (code == 'PGRST301' || code == '401' || code == '403') {
        _redirectToLogin('Session expired. Please sign in again.');
        return true;
      }
    }
    return false;
  }

  void _redirectToLogin(String message) {
    final nav = navigatorKey.currentState;
    if (nav == null) return;

    nav.pushNamedAndRemoveUntil('/', (route) => false);

    // Show message after navigation completes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = nav.context;
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text(message),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  /// Clean up subscription.
  void dispose() {
    _authSub?.cancel();
    _authSub = null;
  }
}
