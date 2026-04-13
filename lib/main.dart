import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pawgo/config/env.dart';
import 'package:pawgo/config/firebase_options.dart';
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
import 'package:pawgo/screens/walker_application_screen.dart';
import 'package:pawgo/screens/walker_application_step2_screen.dart';
import 'package:pawgo/screens/walker_application_step3_screen.dart';
import 'package:pawgo/screens/walker_application_step4_screen.dart';
import 'package:pawgo/screens/application_status_screen.dart';
import 'package:pawgo/screens/walker_chat_list_screen.dart';
import 'package:pawgo/screens/earnings_screen.dart';
import 'package:pawgo/services/gps_broadcast_service.dart';
import 'package:pawgo/services/ad_service.dart';
import 'package:pawgo/services/analytics_service.dart';
import 'package:pawgo/services/error_handler.dart';
import 'package:pawgo/services/role_service.dart';
import 'package:pawgo/services/theme_service.dart';
import 'package:pawgo/services/auth_service.dart';
import 'package:pawgo/services/notification_service.dart';
import 'package:pawgo/screens/bookings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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

  AuthService.instance.initialize();
  await ThemeService.instance.initialize();

  // Set initial status bar style and update when theme changes
  void updateStatusBar(ThemeMode mode) {
    final brightness = mode == ThemeMode.dark ? Brightness.light : Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: brightness,
      ),
    );
  }
  updateStatusBar(ThemeService.instance.themeMode.value);
  ThemeService.instance.themeMode.addListener(() {
    updateStatusBar(ThemeService.instance.themeMode.value);
  });

  runApp(const PawgoApp());
}

/// Handles notification tap deep-linking via the global navigator key.
void _handleNotificationTap(NotificationNavigation nav) {
  final navigator = ErrorHandler.instance.navigatorKey.currentState;
  if (navigator == null) return;

  // Set pending tab for bookings-related routes
  if (nav.tab != null) {
    BookingsScreen.pendingInitialTab = nav.tab;
  }

  navigator.pushNamedAndRemoveUntil(
    nav.route,
    (route) => route.settings.name == '/home' || route.isFirst,
    arguments: nav.arguments,
  );
}

class PawgoApp extends StatelessWidget {
  const PawgoApp({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    final initialRoute = session != null ? '/home' : '/';

    // Wire notification deep-link navigation using the global navigator key
    NotificationService.instance.onNotificationTap = _handleNotificationTap;

    // Initialize role detection and resume GPS broadcast on app restart
    if (session != null) {
      RoleService.instance.initialize();
      GpsBroadcastService.instance.resumeIfActiveWalk();
      NotificationService.instance.initialize();
    }

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.instance.themeMode,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'Pawgo',
          navigatorKey: ErrorHandler.instance.navigatorKey,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.theme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          initialRoute: initialRoute,
          onGenerateRoute: (settings) {
            final routes = <String, WidgetBuilder>{
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
              '/walker-application': (context) =>
                  const WalkerApplicationScreen(),
              '/walker-application-step2': (context) =>
                  const WalkerApplicationStep2Screen(),
              '/walker-application-step3': (context) =>
                  const WalkerApplicationStep3Screen(),
              '/walker-application-step4': (context) =>
                  const WalkerApplicationStep4Screen(),
              '/walker-application-status': (context) =>
                  const ApplicationStatusScreen(),
              '/walker-chat-list': (context) => const WalkerChatListScreen(),
              '/earnings': (context) => const EarningsScreen(),
            };
            final builder = routes[settings.name];
            if (builder != null) {
              return PawgoPageRoute(
                builder: builder,
                settings: settings,
              );
            }
            return null;
          },
        );
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
        RoleService.instance.initialize();
        NotificationService.instance.initialize();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/home');
          }
        });
        // Resume GPS broadcast if walker has an active walk
        GpsBroadcastService.instance.resumeIfActiveWalk();
      } else if (event == AuthChangeEvent.signedOut) {
        AnalyticsService.instance.reset();
        RoleService.instance.reset();
        GpsBroadcastService.instance.stopBroadcasting();
        NotificationService.instance.removeToken();
        NotificationService.instance.dispose();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && ModalRoute.of(context)?.settings.name != '/') {
            Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const SignInScreen();
  }
}
