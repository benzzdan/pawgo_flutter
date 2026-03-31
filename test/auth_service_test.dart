import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pawgo/services/auth_service.dart';

void main() {
  group('AuthService', () {
    testWidgets('redirects to login on AuthException (expired JWT)',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: AuthService.instance.navigatorKey,
          initialRoute: '/home',
          routes: {
            '/': (context) => const Scaffold(body: Text('Sign In')),
            '/home': (context) => const Scaffold(body: Text('Home')),
          },
        ),
      );

      expect(find.text('Home'), findsOneWidget);

      // Simulate expired JWT error from a Supabase call.
      final handled = AuthService.instance.handleAuthError(
        AuthException('JWT expired'),
      );

      expect(handled, isTrue);
      await tester.pumpAndSettle();

      // Should have navigated to sign-in screen.
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Home'), findsNothing);

      // Snackbar should show session expired message.
      expect(
        find.text('Session expired. Please sign in again.'),
        findsOneWidget,
      );
    });

    testWidgets('redirects to login on PostgrestException PGRST301 (JWT expired)',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: AuthService.instance.navigatorKey,
          initialRoute: '/home',
          routes: {
            '/': (context) => const Scaffold(body: Text('Sign In')),
            '/home': (context) => const Scaffold(body: Text('Home')),
          },
        ),
      );

      expect(find.text('Home'), findsOneWidget);

      final handled = AuthService.instance.handleAuthError(
        PostgrestException(message: 'JWT expired', code: 'PGRST301'),
      );

      expect(handled, isTrue);
      await tester.pumpAndSettle();

      expect(find.text('Sign In'), findsOneWidget);
      expect(
        find.text('Session expired. Please sign in again.'),
        findsOneWidget,
      );
    });

    testWidgets('does not handle non-auth errors', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: AuthService.instance.navigatorKey,
          initialRoute: '/home',
          routes: {
            '/': (context) => const Scaffold(body: Text('Sign In')),
            '/home': (context) => const Scaffold(body: Text('Home')),
          },
        ),
      );

      final handled = AuthService.instance.handleAuthError(
        Exception('Network error'),
      );

      expect(handled, isFalse);
      await tester.pumpAndSettle();

      // Should stay on home screen.
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('does not handle regular PostgrestException',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: AuthService.instance.navigatorKey,
          initialRoute: '/home',
          routes: {
            '/': (context) => const Scaffold(body: Text('Sign In')),
            '/home': (context) => const Scaffold(body: Text('Home')),
          },
        ),
      );

      final handled = AuthService.instance.handleAuthError(
        PostgrestException(message: 'Not found', code: '404'),
      );

      expect(handled, isFalse);
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('shows snackbar with message after redirect',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: AuthService.instance.navigatorKey,
          initialRoute: '/home',
          routes: {
            '/': (context) => const Scaffold(body: Text('Sign In')),
            '/home': (context) => const Scaffold(body: Text('Home')),
          },
        ),
      );

      AuthService.instance.handleAuthError(
        AuthException('JWT expired'),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('Session expired. Please sign in again.'),
        findsOneWidget,
      );
    });
  });
}
