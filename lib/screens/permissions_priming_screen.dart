import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../services/gps_broadcast_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/permission_card.dart';

/// Permissions-priming screen shown right after sign-up.
///
/// Two cards explain WHY Pawgo needs each OS permission (location +
/// notifications) and let the user trigger each prompt. Continue routes by
/// role:
/// - `owner`  → `/dog-onboarding`
/// - `walker` → `/walker-application`
///
/// Either permission can be denied — the app degrades gracefully and
/// re-prompts at point-of-use, so we proceed regardless.
///
/// The two `request*` callbacks are injected so widget tests don't have to
/// mock Geolocator / Firebase Messaging. In production they default to the
/// real services.
class PermissionsPrimingScreen extends StatefulWidget {
  const PermissionsPrimingScreen({
    super.key,
    required this.role,
    Future<bool> Function()? requestLocation,
    Future<bool> Function()? requestNotifications,
  })  : _requestLocationOverride = requestLocation,
        _requestNotificationsOverride = requestNotifications;

  /// `'owner'` or `'walker'`. Drives where Continue routes the user.
  final String role;

  final Future<bool> Function()? _requestLocationOverride;
  final Future<bool> Function()? _requestNotificationsOverride;

  Future<bool> get requestLocation =>
      _requestLocationOverride?.call() ?? _defaultRequestLocation();

  Future<bool> get requestNotifications =>
      _requestNotificationsOverride?.call() ?? _defaultRequestNotifications();

  static Future<bool> _defaultRequestLocation() async {
    final result =
        await GpsBroadcastService.requestLocationPermissionInteractive();
    return result.granted;
  }

  static Future<bool> _defaultRequestNotifications() {
    return NotificationService.instance.requestPermission();
  }

  @override
  State<PermissionsPrimingScreen> createState() =>
      _PermissionsPrimingScreenState();
}

class _PermissionsPrimingScreenState extends State<PermissionsPrimingScreen> {
  PermissionCardStatus _locationStatus = PermissionCardStatus.notYet;
  PermissionCardStatus _notificationsStatus = PermissionCardStatus.notYet;

  bool _locationInFlight = false;
  bool _notificationsInFlight = false;

  Future<void> _onAllowLocation() async {
    if (_locationInFlight) return;
    setState(() => _locationInFlight = true);
    try {
      final granted = await widget.requestLocation;
      if (!mounted) return;
      setState(() {
        _locationStatus = granted
            ? PermissionCardStatus.granted
            : PermissionCardStatus.denied;
      });
    } finally {
      if (mounted) setState(() => _locationInFlight = false);
    }
  }

  Future<void> _onAllowNotifications() async {
    if (_notificationsInFlight) return;
    setState(() => _notificationsInFlight = true);
    try {
      final granted = await widget.requestNotifications;
      if (!mounted) return;
      setState(() {
        _notificationsStatus = granted
            ? PermissionCardStatus.granted
            : PermissionCardStatus.denied;
      });
    } finally {
      if (mounted) setState(() => _notificationsInFlight = false);
    }
  }

  void _onContinue() {
    final nextRoute =
        widget.role == 'walker' ? '/walker-application' : '/dog-onboarding';
    Navigator.pushReplacementNamed(context, nextRoute);
  }

  // -------------------------------------------------------------------------
  // Bilingual copy lives inline for now; will move to .arb in Task 11/14 once
  // sign-up wires the new strings together with the existing ARB pipeline.
  // -------------------------------------------------------------------------

  String get _title => 'Una última cosa / One last thing';
  String get _subtitle => widget.role == 'walker'
      ? 'Necesitamos dos permisos para que puedas trabajar con paseos. / '
          'We need two permissions so you can take walks.'
      : 'Necesitamos dos permisos para que la app funcione. / '
          'We need two permissions for the app to work.';
  String get _locationTitle => 'Ubicación / Location';
  String get _locationBody => widget.role == 'walker'
      ? 'Compartimos tu ubicación con el dueño sólo mientras un paseo está '
          'activo, para que pueda verte en vivo. / '
          'We share your location with the owner only while a walk is '
          'active, so they can see you live.'
      : 'Usamos tu ubicación para encontrar paseadores cerca y mostrarte el '
          'recorrido en tiempo real. / '
          'We use your location to find nearby walkers and show you the '
          'route in real time.';
  String get _notificationsTitle => 'Notificaciones / Notifications';
  String get _notificationsBody =>
      'Te avisamos cuando tu paseo empieza, termina, o cuando llega un '
      'mensaje. / We notify you when your walk starts, ends, or when a new '
      'message arrives.';
  String get _allowLocationLabel => 'Permitir ubicación / Allow location';
  String get _allowNotificationsLabel =>
      'Permitir notificaciones / Allow notifications';
  String get _continueLabel => 'Continuar / Continue';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _title,
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.cacaoBrown,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              PermissionCard(
                key: const Key('permissionsPriming_locationCard'),
                allowButtonKey:
                    const Key('permissionsPriming_allowLocation'),
                icon: PhosphorIcons.mapPin(),
                title: _locationTitle,
                body: _locationBody,
                status: _locationStatus,
                allowLabel: _allowLocationLabel,
                onAllow: _onAllowLocation,
              ),
              const SizedBox(height: AppSpacing.md),
              PermissionCard(
                key: const Key('permissionsPriming_notificationsCard'),
                allowButtonKey:
                    const Key('permissionsPriming_allowNotifications'),
                icon: PhosphorIcons.bell(),
                title: _notificationsTitle,
                body: _notificationsBody,
                status: _notificationsStatus,
                allowLabel: _allowNotificationsLabel,
                onAllow: _onAllowNotifications,
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  key: const Key('permissionsPriming_continue'),
                  onPressed: _onContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.orange500,
                    foregroundColor: AppColors.white,
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: Text(
                    _continueLabel,
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
