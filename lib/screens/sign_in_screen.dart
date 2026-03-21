import 'package:flutter/material.dart';
import 'package:pawgo/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const Spacer(flex: 2),
                // Logo & Welcome
                _buildLogo(),
                const Spacer(flex: 2),
                // Sign In Options
                _buildSignInOptions(context),
                const Spacer(flex: 1),
                // Terms
                _buildTerms(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.orange500, AppColors.orange400],
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppColors.orange500.withValues(alpha: 0.3),
                blurRadius: 32,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Center(
            child: Text('\u{1F43E}', style: TextStyle(fontSize: 48)),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Pawgo',
          style: GoogleFonts.nunito(
            fontSize: 42,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Your trusted dog walking service',
          style: GoogleFonts.nunito(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildSignInOptions(BuildContext context) {
    return Column(
      children: [
        Text(
          'Welcome back!',
          style: GoogleFonts.nunito(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 24),
        // Google Sign In
        _SignInButton(
          onTap: () => Navigator.pushReplacementNamed(context, '/home'),
          backgroundColor: AppColors.white,
          textColor: AppColors.textPrimary,
          label: 'Continue with Google',
          icon: _buildGoogleIcon(),
          shadow: true,
        ),
        const SizedBox(height: 16),
        // Apple Sign In
        _SignInButton(
          onTap: () => Navigator.pushReplacementNamed(context, '/home'),
          backgroundColor: AppColors.textPrimary,
          textColor: AppColors.white,
          label: 'Continue with Apple',
          icon: const Icon(Icons.apple, color: Colors.white, size: 24),
        ),
        const SizedBox(height: 16),
        // Email Sign In
        _SignInButton(
          onTap: () => Navigator.pushReplacementNamed(context, '/home'),
          backgroundColor: AppColors.orange500,
          textColor: AppColors.white,
          label: 'Continue with Email',
          icon: const Icon(Icons.mail_outline, color: Colors.white, size: 24),
          orangeShadow: true,
        ),
        const SizedBox(height: 16),
        // Divider
        Row(
          children: [
            const Expanded(child: Divider(color: AppColors.divider)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'OR',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const Expanded(child: Divider(color: AppColors.divider)),
          ],
        ),
        const SizedBox(height: 16),
        // Phone Sign In
        _SignInButton(
          onTap: () => Navigator.pushReplacementNamed(context, '/home'),
          backgroundColor: AppColors.white,
          textColor: AppColors.textPrimary,
          label: 'Continue with Phone',
          icon: const Text('\u{1F4F1}', style: TextStyle(fontSize: 24)),
          border: true,
        ),
      ],
    );
  }

  Widget _buildGoogleIcon() {
    return SizedBox(
      width: 24,
      height: 24,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }

  Widget _buildTerms() {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: GoogleFonts.nunito(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textTertiary,
        ),
        children: [
          const TextSpan(text: "By continuing, you agree to Pawgo's "),
          TextSpan(
            text: 'Terms of Service',
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.orange500,
              decoration: TextDecoration.underline,
            ),
          ),
          const TextSpan(text: ' and '),
          TextSpan(
            text: 'Privacy Policy',
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.orange500,
              decoration: TextDecoration.underline,
            ),
          ),
        ],
      ),
    );
  }
}

class _SignInButton extends StatelessWidget {
  final VoidCallback onTap;
  final Color backgroundColor;
  final Color textColor;
  final String label;
  final Widget icon;
  final bool shadow;
  final bool orangeShadow;
  final bool border;

  const _SignInButton({
    required this.onTap,
    required this.backgroundColor,
    required this.textColor,
    required this.label,
    required this.icon,
    this.shadow = false,
    this.orangeShadow = false,
    this.border = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(18),
          border: border
              ? Border.all(color: AppColors.divider, width: 2)
              : null,
          boxShadow: [
            if (shadow)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            if (orangeShadow)
              BoxShadow(
                color: AppColors.orange500.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Blue
    final bluePaint = Paint()..color = const Color(0xFF4285F4);
    canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.45, bluePaint);

    // White center
    final whitePaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.3, whitePaint);

    // Colored arcs
    final redPaint = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.15;
    canvas.drawArc(
      Rect.fromCenter(
          center: Offset(w * 0.5, h * 0.5), width: w * 0.6, height: h * 0.6),
      -0.8,
      0.8,
      false,
      redPaint,
    );

    final greenPaint = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.15;
    canvas.drawArc(
      Rect.fromCenter(
          center: Offset(w * 0.5, h * 0.5), width: w * 0.6, height: h * 0.6),
      1.6,
      0.8,
      false,
      greenPaint,
    );

    final yellowPaint = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.15;
    canvas.drawArc(
      Rect.fromCenter(
          center: Offset(w * 0.5, h * 0.5), width: w * 0.6, height: h * 0.6),
      2.4,
      0.8,
      false,
      yellowPaint,
    );

    // Blue right bar
    canvas.drawRect(
      Rect.fromLTWH(w * 0.5, h * 0.4, w * 0.45, h * 0.2),
      bluePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
