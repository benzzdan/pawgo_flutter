import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pawgo/config/env.dart';
import 'package:pawgo/theme/app_theme.dart';
import 'package:pawgo/screens/sign_in_screen.dart';
import 'package:pawgo/screens/sign_up_screen.dart';
import 'package:pawgo/screens/main_shell.dart';
import 'package:pawgo/screens/walker_profile_screen.dart';
import 'package:pawgo/screens/active_walk_screen.dart';
import 'package:pawgo/screens/walker_chat_screen.dart';
import 'package:pawgo/screens/profile_screen.dart';
import 'package:pawgo/screens/booking_screen.dart';
import 'package:pawgo/screens/payment_screen.dart';
import 'package:pawgo/screens/walker_bookings_screen.dart';
import 'package:pawgo/screens/review_screen.dart';
import 'package:pawgo/screens/walker_earnings_screen.dart';
import 'package:pawgo/screens/insurance_claim_screen.dart';
import 'package:pawgo/services/gps_broadcast_service.dart';
import 'package:pawgo/services/ad_service.dart';
import 'package:pawgo/services/analytics_service.dart';
import 'package:pawgo/services/error_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const env = Env.local; // Switch to Env.production for release builds
  await Supabase.initialize(
    url: env.supabaseUrl,
    anonKey: env.supabaseAnonKey,
  );

  await AdService.instance.initialize();

  await AnalyticsService.instance.initialize(
    apiKey: env.posthogApiKey,
    host: env.posthogHost,
  );

  // Global Flutter framework error handler
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    AnalyticsService.instance.errorOccurred(
      errorCode: 'flutter_error',
      message: details.exceptionAsString(),
    );
  };

  // Global async error handler
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Unhandled error: $error\n$stack');
    AnalyticsService.instance.errorOccurred(
      errorCode: 'unhandled_error',
      message: error.toString(),
    );
    return true;
  };

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const PawgoApp());
}

class PawgoApp extends StatelessWidget {
  const PawgoApp({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    final initialRoute = session != null ? '/home' : '/';

    // Resume GPS broadcast if walker has an active walk on app restart
    if (session != null) {
      GpsBroadcastService.instance.resumeIfActiveWalk();
    }

    return MaterialApp(
      title: 'Pawgo',
      navigatorKey: ErrorHandler.instance.navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      darkTheme: AppTheme.darkTheme,
      initialRoute: initialRoute,
      routes: {
        '/': (context) => const _AuthGate(),
        '/signup': (context) => const SignUpScreen(),
        '/home': (context) => const MainShell(),
        '/walker': (context) => const WalkerProfileScreen(),
        '/active-walk': (context) => const ActiveWalkScreen(),
        '/chat': (context) => const WalkerChatScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/booking': (context) => const BookingScreen(),
        '/payment': (context) => const PaymentScreen(),
        '/walker-bookings': (context) => const WalkerBookingsScreen(),
        '/review': (context) => const ReviewScreen(),
        '/walker-earnings': (context) => const WalkerEarningsScreen(),
        '/insurance-claim': (context) => const InsuranceClaimScreen(),
      },
    );
  }
}

/// Listens to auth state changes and redirects accordingly.
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  late final Stream<AuthState> _authStream;

  @override
  void initState() {
    super.initState();
    _authStream = Supabase.instance.client.auth.onAuthStateChange;
    _authStream.listen((authState) {
      if (!mounted) return;
      final event = authState.event;
      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.tokenRefreshed) {
        final userId = authState.session?.user.id;
        if (userId != null) {
          AnalyticsService.instance.identify(userId);
        }
        Navigator.pushReplacementNamed(context, '/home');
        // Resume GPS broadcast if walker has an active walk
        GpsBroadcastService.instance.resumeIfActiveWalk();
      } else if (event == AuthChangeEvent.signedOut) {
        AnalyticsService.instance.reset();
        GpsBroadcastService.instance.stopBroadcasting();
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const SignInScreen();
  }
}
