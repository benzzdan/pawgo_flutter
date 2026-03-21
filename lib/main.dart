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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const env = Env.local; // Switch to Env.production for release builds
  await Supabase.initialize(
    url: env.supabaseUrl,
    anonKey: env.supabaseAnonKey,
  );

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

    return MaterialApp(
      title: 'Pawgo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
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
        Navigator.pushReplacementNamed(context, '/home');
      } else if (event == AuthChangeEvent.signedOut) {
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const SignInScreen();
  }
}
