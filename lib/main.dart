import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pawgo/l10n/app_localizations.dart';
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
import 'package:pawgo/screens/walk_request_screen.dart';
import 'package:pawgo/screens/notification_preferences_screen.dart';
import 'package:pawgo/screens/alternative_walkers_screen.dart';
import 'package:pawgo/screens/dog_profile_form_screen.dart';
import 'package:pawgo/models/dog.dart';
import 'package:pawgo/services/gps_broadcast_service.dart';
import 'package:pawgo/services/ad_service.dart';
import 'package:pawgo/services/analytics_service.dart';
import 'package:pawgo/services/error_handler.dart';
import 'package:pawgo/services/role_service.dart';
import 'package:pawgo/services/theme_service.dart';
import 'package:pawgo/services/auth_service.dart';
import 'package:pawgo/services/notification_service.dart';
import 'package:pawgo/screens/bookings_screen.dart';
import 'package:pawgo/widgets/review_bottom_sheet.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (DefaultFirebaseOptions.isConfigured) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } else {
    debugPrint('Firebase: skipping init — placeholder config detected. '
        'Run flutterfire configure to set up real Firebase.');
  }

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
  if (nav.route == 'review_sheet') {
    _showReviewSheetFromNav(nav);
    return;
  }

  final navigator = ErrorHandler.instance.navigatorKey.currentState;
  if (navigator == null) return;

  if (nav.tab != null) {
    BookingsScreen.pendingInitialTab = nav.tab;
  }

  navigator.pushNamedAndRemoveUntil(
    nav.route,
    (route) => route.settings.name == '/home' || route.isFirst,
    arguments: nav.arguments,
  );
}

/// Shows [ReviewBottomSheet] using the global navigator key.
/// Precondition: [ErrorHandler.instance.navigatorKey] must be mounted (non-null currentContext).
void _showReviewSheetFromNav(NotificationNavigation nav) {
  final context = ErrorHandler.instance.navigatorKey.currentContext;
  if (context == null) return;
  final args = nav.arguments;
  if (args == null) return;
  final bookingId = args['booking_id'] as String?;
  final walkerId = args['walker_id'] as String?;
  if (bookingId == null || walkerId == null) return;

  ReviewBottomSheet.shownThisSession = true;
  showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => ReviewBottomSheet(
      bookingId: bookingId,
      walkerId: walkerId,
      walkerName: args['walker_name'] as String? ?? 'your walker',
    ),
  ).then((submitted) {
    // Only navigate to past bookings when the review was actually submitted.
    // If skipped, leave the user on the current screen.
    if (submitted == true) {
      BookingsScreen.pendingInitialTab = 'past';
      ErrorHandler.instance.navigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/home',
        (route) => false,
        arguments: {'tab': 2},
      );
    }
  });
}

class PawgoApp extends StatelessWidget {
  const PawgoApp({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    final initialRoute = session != null ? '/home' : '/';

    // Wire notification deep-link navigation using the global navigator key
    if (DefaultFirebaseOptions.isConfigured) {
      NotificationService.instance.onNotificationTap = _handleNotificationTap;
    }

    // Initialize role detection and resume GPS broadcast on app restart
    if (session != null) {
      RoleService.instance.initialize();
      GpsBroadcastService.instance.resumeIfActiveWalk();
      if (DefaultFirebaseOptions.isConfigured) {
        NotificationService.instance.initialize();
      }
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
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
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
              '/walker-bookings': (context) {
                final args = ModalRoute.of(context)?.settings.arguments;
                int initialTab = 0;
                if (args is Map<String, dynamic>) {
                  initialTab = (args['initialTab'] as int?) ?? 0;
                }
                return WalkerBookingsScreen(initialTab: initialTab);
              },
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
              '/walk-request': (context) => const WalkRequestScreen(),
              '/notification-preferences': (context) =>
                  const NotificationPreferencesScreen(),
              '/alternative-walkers': (context) =>
                  const AlternativeWalkersScreen(),
              '/dog-profile-form': (context) {
                final args = ModalRoute.of(context)?.settings.arguments;
                return DogProfileFormScreen(
                  initial: args is Dog ? args : null,
                );
              },
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
  StreamSubscription<AuthState>? _authSub;
  // Prevents scheduling multiple concurrent pending-review checks when
  // both signedIn and tokenRefreshed fire in quick succession.
  bool _reviewCheckScheduled = false;

  @override
  void initState() {
    super.initState();
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((authState) {
      if (!mounted) return;
      final event = authState.event;
      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.tokenRefreshed) {
        final userId = authState.session?.user.id;
        if (userId != null) {
          AnalyticsService.instance.identify(userId);
        }
        RoleService.instance.initialize();
        if (DefaultFirebaseOptions.isConfigured) {
          NotificationService.instance.initialize();
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/home');
            // After navigation settles, check for an unreviewed completed walk.
            // Guard prevents multiple concurrent checks if both signedIn and
            // tokenRefreshed fire before the first check runs.
            if (!_reviewCheckScheduled) {
              _reviewCheckScheduled = true;
              Future.delayed(
                const Duration(milliseconds: 500),
                _checkPendingReviewOnStartup,
              );
            }
          }
        });
        // Resume GPS broadcast if walker has an active walk
        GpsBroadcastService.instance.resumeIfActiveWalk();
      } else if (event == AuthChangeEvent.signedOut) {
        ReviewBottomSheet.shownThisSession = false; // reset for next session
        _reviewCheckScheduled = false;
        AnalyticsService.instance.reset();
        RoleService.instance.reset();
        GpsBroadcastService.instance.stopBroadcasting();
        if (DefaultFirebaseOptions.isConfigured) {
          NotificationService.instance.removeToken();
          NotificationService.instance.dispose();
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && ModalRoute.of(context)?.settings.name != '/') {
            Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _checkPendingReviewOnStartup() async {
    _reviewCheckScheduled = false;
    if (ReviewBottomSheet.shownThisSession) return;
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return; // covers both "never logged in" and "signed out during startup delay"

      final data = await supabase
          .from('bookings')
          .select('id, walker_id, walkers!bookings_walker_id_fkey(users(full_name))')
          .eq('owner_id', userId)
          .eq('status', 'walk_completed')
          .order('updated_at', ascending: false)
          .limit(5);

      for (final booking in (data as List<dynamic>)) {
        final bookingId = booking['id'] as String;
        final reviews = await supabase
            .from('reviews')
            .select('id')
            .eq('booking_id', bookingId)
            .limit(1);
        if ((reviews as List<dynamic>).isEmpty) {
          final walkerData = booking['walkers'] as Map<String, dynamic>?;
          final userMap = walkerData?['users'] as Map<String, dynamic>?;
          final walkerId = booking['walker_id'] as String;
          final walkerName = userMap?['full_name'] as String? ?? 'your walker';
          _showReviewSheetFromNav(NotificationNavigation(
            route: 'review_sheet',
            arguments: {
              'booking_id': bookingId,
              'walker_id': walkerId,
              'walker_name': walkerName,
            },
          ));
          break;
        }
      }
    } catch (_) {
      // Non-critical: silently ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    return const SignInScreen();
  }
}
