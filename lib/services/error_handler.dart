import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pawgo/services/analytics_service.dart';
import 'package:pawgo/theme/app_theme.dart';

/// Consistent error representation parsed from API/Supabase responses.
class AppError {
  final String code;
  final String message;
  final bool isAuthError;
  final bool isNetworkError;

  const AppError({
    required this.code,
    required this.message,
    this.isAuthError = false,
    this.isNetworkError = false,
  });

  /// Parse an error from any source into a consistent AppError.
  factory AppError.from(Object error) {
    if (error is AuthException) {
      return AppError(
        code: 'auth_error',
        message: error.message,
        isAuthError: true,
      );
    }

    if (error is PostgrestException) {
      final isAuth = error.code == '401' ||
          error.code == 'PGRST301' ||
          error.message.toLowerCase().contains('jwt');
      return AppError(
        code: error.code ?? 'db_error',
        message: error.message,
        isAuthError: isAuth,
      );
    }

    if (error is SocketException || error is TimeoutException) {
      return AppError(
        code: 'network_error',
        message: 'No internet connection. Please check your network.',
        isNetworkError: true,
      );
    }

    if (error is HandshakeException) {
      return AppError(
        code: 'ssl_error',
        message: 'Secure connection failed. Please try again.',
        isNetworkError: true,
      );
    }

    return AppError(
      code: 'unknown_error',
      message: error.toString(),
    );
  }

  /// Parse error from an Edge Function response.
  factory AppError.fromFunctionResponse(FunctionResponse response) {
    final data = response.data;
    if (data is Map) {
      final errorObj = data['error'];
      if (errorObj is Map) {
        return AppError(
          code: errorObj['code']?.toString() ?? 'function_error',
          message: errorObj['message']?.toString() ?? 'Request failed',
          isAuthError: response.status == 401,
        );
      }
    }
    return AppError(
      code: 'function_error_${response.status}',
      message: 'Request failed',
      isAuthError: response.status == 401,
    );
  }

  Map<String, Object> toJson() => {'code': code, 'message': message};
}

/// Global error handler for the app.
///
/// Provides consistent error display (SnackBar for recoverable,
/// Dialog for blocking), auth error redirect, and analytics tracking.
class ErrorHandler {
  ErrorHandler._();
  static final ErrorHandler instance = ErrorHandler._();

  /// Global navigator key for auth redirect when no context is available.
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Show a recoverable error as a SnackBar.
  void showRecoverableError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.nunito(color: Colors.white)),
        backgroundColor: AppColors.red500,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Show a blocking error as an AlertDialog.
  void showBlockingError(BuildContext context, String message, {String? title}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          title ?? 'Error',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
        ),
        content: Text(message, style: GoogleFonts.nunito()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'OK',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  /// Handle an error with appropriate UI feedback and analytics tracking.
  ///
  /// [blocking] - true for Dialog, false for SnackBar (default).
  /// [screen] - screen name for analytics.
  void handleError(
    BuildContext context,
    Object error, {
    String? screen,
    bool blocking = false,
    String? fallbackMessage,
  }) {
    final appError = error is AppError ? error : AppError.from(error);

    // Track in analytics
    AnalyticsService.instance.errorOccurred(
      errorCode: appError.code,
      message: appError.message,
      screen: screen,
    );

    // Handle auth errors by redirecting to login
    if (appError.isAuthError) {
      _redirectToLogin();
      return;
    }

    // Display user-friendly message
    final displayMessage = appError.isNetworkError
        ? appError.message
        : (fallbackMessage ?? appError.message);

    if (blocking) {
      showBlockingError(context, displayMessage);
    } else {
      showRecoverableError(context, displayMessage);
    }
  }

  /// Handle an Edge Function response that may contain an error.
  ///
  /// Returns true if the response was an error (and was handled).
  bool handleFunctionError(
    BuildContext context,
    FunctionResponse response, {
    String? screen,
    bool blocking = false,
    String? fallbackMessage,
  }) {
    if (response.status >= 200 && response.status < 300) return false;

    if (response.status == 401) {
      _redirectToLogin();
      return true;
    }

    final appError = AppError.fromFunctionResponse(response);
    handleError(
      context,
      appError,
      screen: screen,
      blocking: blocking,
      fallbackMessage: fallbackMessage,
    );
    return true;
  }

  void _redirectToLogin() {
    final nav = navigatorKey.currentState;
    if (nav != null) {
      nav.pushNamedAndRemoveUntil('/', (route) => false);
    }
  }
}

/// Execute an async operation with retry logic (exponential backoff).
///
/// Retries up to [maxRetries] times on network errors.
/// Non-network errors are thrown immediately.
Future<T> withRetry<T>(
  Future<T> Function() operation, {
  int maxRetries = 3,
}) async {
  int attempt = 0;
  while (true) {
    try {
      return await operation();
    } catch (e) {
      attempt++;
      final appError = AppError.from(e);

      // Only retry network errors
      if (!appError.isNetworkError || attempt >= maxRetries) {
        rethrow;
      }

      // Exponential backoff: 1s, 2s, 4s
      final delay = Duration(seconds: 1 << (attempt - 1));
      await Future.delayed(delay);
    }
  }
}
