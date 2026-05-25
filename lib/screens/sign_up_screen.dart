import 'package:flutter/material.dart';
import 'package:pawgo/config/legal.dart';
import 'package:pawgo/config/legal_placeholder.dart';
import 'package:pawgo/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pawgo/services/analytics_service.dart';
import 'package:pawgo/services/error_handler.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pawgo/widgets/paw_progress_indicator.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _obscurePassword = true;
  bool _legalAccepted = false;

  /// Role passed in from /welcome. Falls back to 'owner' if missing (when
  /// the user arrives at /signup through legacy code paths that don't pass
  /// the role arg yet).
  String _role = 'owner';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['role'] is String) {
      _role = args['role'] as String;
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    final fullName = _fullNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (fullName.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please fill in all fields');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }
    if (!_legalAccepted) {
      // Should be unreachable because the button is disabled, but keep this
      // as a safety net in case of widget-tree edge cases.
      setState(() => _error =
          'Please accept the Terms of Use and Privacy Policy to continue');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName},
      );

      if (!mounted) return;

      // Persist legal acceptance metadata as soon as we have a user row.
      // The auto-create trigger has already inserted into public.users; we
      // just stamp the accepted versions + timestamps. If there's no
      // session yet (email confirmation required), this still runs because
      // the session-less response still carries the user id and the user
      // is authenticated by virtue of the signUp call from the client.
      final userId = response.user?.id;
      if (userId != null) {
        await _writeLegalAcceptance(userId);
      }

      if (!mounted) return;

      if (response.user != null && response.session != null) {
        AnalyticsService.instance.userSignedUp();
        // Hand control to the permissions-priming screen, which then
        // routes to /walker-application or /dog-onboarding based on role.
        Navigator.pushReplacementNamed(
          context,
          '/permissions',
          arguments: {'role': _role},
        );
      } else if (response.user != null && response.session == null) {
        AnalyticsService.instance.userSignedUp();
        // Email confirmation required
        _showConfirmationDialog();
      }
    } on AuthException catch (e) {
      final appError = AppError.from(e);
      setState(() => _error = appError.message);
      AnalyticsService.instance.errorOccurred(
        errorCode: appError.code,
        message: appError.message,
        screen: 'sign_up',
      );
    } catch (e) {
      final appError = AppError.from(e);
      setState(() => _error = appError.isNetworkError
          ? appError.message
          : 'An unexpected error occurred. Please try again.');
      AnalyticsService.instance.errorOccurred(
        errorCode: appError.code,
        message: appError.message,
        screen: 'sign_up',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Stamps `users.terms_*` and `users.privacy_*` with the current versions
  /// and acceptance timestamp. Safe to call even when there's no session
  /// (the row exists thanks to the auto-create trigger on auth.users; we
  /// can update it because the signUp call set the auth context).
  Future<void> _writeLegalAcceptance(String userId) async {
    final now = DateTime.now().toUtc().toIso8601String();
    try {
      await Supabase.instance.client
          .from('users')
          .update({
            'terms_version': kTermsVersion,
            'terms_accepted_at': now,
            'privacy_version': kPrivacyVersion,
            'privacy_accepted_at': now,
          })
          .eq('id', userId);
    } catch (e) {
      // Don't fail the sign-up flow if the legal write fails — log only.
      // The user can be re-prompted on next launch once the columns NULL.
      debugPrint('Failed to persist legal acceptance: $e');
    }
  }

  void _openLegal(BuildContext context, LegalDoc doc) {
    final route = doc == LegalDoc.terms ? '/legal/terms' : '/legal/privacy';
    Navigator.pushNamed(context, route);
  }

  void _showConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Check your email',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'We sent a confirmation link to ${_emailController.text.trim()}. Please verify your email to sign in.',
          style: GoogleFonts.nunito(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // close dialog
              Navigator.pop(context); // back to sign in
            },
            child: Text(
              'OK',
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.w700,
                color: AppColors.orange500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.orange50, AppColors.background],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 48),
                  // Header
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Icon(PhosphorIcons.arrowLeft(),
                              color: AppColors.textPrimary),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Create Account',
                        style: GoogleFonts.nunito(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 60),
                    child: Text(
                      'Join Pawgo and find trusted walkers for your furry friend.',
                      style: GoogleFonts.nunito(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Form fields
                  _buildTextField(
                    controller: _fullNameController,
                    label: 'Full Name',
                    hint: 'Juan Pérez',
                    keyboardType: TextInputType.name,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _emailController,
                    label: 'Email',
                    hint: 'you@example.com',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _passwordController,
                    label: 'Password',
                    hint: 'At least 6 characters',
                    obscureText: _obscurePassword,
                    suffixIcon: GestureDetector(
                      onTap: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      child: Icon(
                        _obscurePassword
                            ? PhosphorIcons.eyeSlash()
                            : PhosphorIcons.eye(),
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.red500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  // Terms / Privacy acceptance — submit is disabled until on.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 32,
                        child: Checkbox(
                          key: const Key('signUpLegalCheckbox'),
                          value: _legalAccepted,
                          onChanged: (v) =>
                              setState(() => _legalAccepted = v ?? false),
                          activeColor: AppColors.orange500,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _buildLegalRichText(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Sign Up Button — disabled until legal box is on.
                  GestureDetector(
                    key: const Key('signUpSubmitButton'),
                    onTap: (_loading || !_legalAccepted) ? null : _signUp,
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: !_legalAccepted
                            ? AppColors.border
                            : (_loading
                                ? AppColors.orange400
                                : AppColors.orange500),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.orange500.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: _loading
                            ? const PawProgressIndicator(size: 24, strokeWidth: 2.5, color: Colors.white)
                            : Text(
                                'Create Account',
                                style: GoogleFonts.nunito(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Sign in link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: GoogleFonts.nunito(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Text(
                          'Sign In',
                          style: GoogleFonts.nunito(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.orange500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Bilingual T&C/Privacy acceptance line with inline tappable links.
  /// Each link span gets a stable [Key] (via [WidgetSpan]) so widget tests
  /// can locate it without relying on visible substrings.
  Widget _buildLegalRichText(BuildContext context) {
    final linkStyle = GoogleFonts.nunito(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: AppColors.orange500,
      decoration: TextDecoration.underline,
    );
    final baseStyle = GoogleFonts.nunito(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: AppColors.textSecondary,
      height: 1.4,
    );

    return RichText(
      text: TextSpan(
        style: baseStyle,
        children: [
          const TextSpan(
            text:
                'Acepto los / I accept the ',
          ),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: InkWell(
              key: const Key('signUpLegalTermsLink'),
              onTap: () => _openLegal(context, LegalDoc.terms),
              child: Text('Términos de Uso / Terms of Use', style: linkStyle),
            ),
          ),
          const TextSpan(text: ' y la / and the '),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: InkWell(
              key: const Key('signUpLegalPrivacyLink'),
              onTap: () => _openLegal(context, LegalDoc.privacy),
              child: Text('Política de Privacidad / Privacy Policy',
                  style: linkStyle),
            ),
          ),
          const TextSpan(text: '.'),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          style: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
            ),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: AppColors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: AppColors.orange500, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
