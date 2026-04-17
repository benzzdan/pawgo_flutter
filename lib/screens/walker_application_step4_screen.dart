import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pawgo/theme/app_theme.dart';
import 'package:pawgo/services/error_handler.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class WalkerApplicationStep4Screen extends StatefulWidget {
  const WalkerApplicationStep4Screen({super.key});

  @override
  State<WalkerApplicationStep4Screen> createState() =>
      _WalkerApplicationStep4ScreenState();
}

class _WalkerApplicationStep4ScreenState
    extends State<WalkerApplicationStep4Screen> {
  final _supabase = Supabase.instance.client;

  bool _loading = true;
  bool _submitting = false;
  bool _submitted = false;
  String? _applicationId;
  Map<String, dynamic> _applicationData = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_applicationId == null) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      _applicationId = args?['application_id'] as String?;
      if (_applicationId != null) {
        _loadApplicationData();
      }
    }
  }

  Future<void> _loadApplicationData() async {
    try {
      final rows = await withRetry(() => _supabase
          .from('walker_applications')
          .select()
          .eq('id', _applicationId!)
          .limit(1));

      if (rows.isNotEmpty && mounted) {
        setState(() {
          _applicationData = rows[0];
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      final appError = AppError.from(e);
      if (appError.isAuthError) {
        ErrorHandler.instance.navigatorKey.currentState
            ?.pushNamedAndRemoveUntil('/', (route) => false);
      } else {
        ErrorHandler.instance.showRecoverableError(context, appError.message);
      }
      setState(() => _loading = false);
    }
  }

  Future<void> _submitApplication() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Submit Application',
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          'Your application will be reviewed. You will be notified when a decision is made.',
          style: GoogleFonts.nunito(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.nunito(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warmCaramel,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text(
              'Submit',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _submitting = true);

    try {
      await withRetry(() => _supabase
          .from('walker_applications')
          .update({
            'status': 'pending',
            'created_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', _applicationId!));

      if (mounted) {
        setState(() => _submitted = true);
      }
    } catch (e) {
      if (!mounted) return;
      final appError = AppError.from(e);
      if (appError.isAuthError) {
        ErrorHandler.instance.navigatorKey.currentState
            ?.pushNamedAndRemoveUntil('/', (route) => false);
      } else {
        ErrorHandler.instance.showRecoverableError(context, appError.message);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _navigateToStep(String route) {
    Navigator.pushNamed(
      context,
      route,
      arguments: {'application_id': _applicationId},
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) {
      return _buildSubmittedScreen();
    }

    return Scaffold(
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.warmCaramel,
                ),
              )
            : Column(
                children: [
                  _buildAppBar(),
                  _buildProgressIndicator(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Review Your Application',
                            style: GoogleFonts.nunito(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Please review all your information before submitting.',
                            style: GoogleFonts.nunito(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _buildPersonalInfoSection(),
                          const SizedBox(height: AppSpacing.md),
                          _buildExperienceSection(),
                          const SizedBox(height: AppSpacing.md),
                          _buildVerificationSection(),
                          const SizedBox(height: AppSpacing.xl),
                        ],
                      ),
                    ),
                  ),
                  _buildSubmitButton(),
                ],
              ),
      ),
    );
  }

  Widget _buildSubmittedScreen() {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: AppColors.green500.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  PhosphorIcons.checkCircle(),
                  size: 56,
                  color: AppColors.green500,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Application Submitted!',
                style: GoogleFonts.nunito(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Thank you for applying to become a Pawgo walker. '
                'We will review your application and get back to you '
                'within 3-5 business days.',
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'You can check your application status from your Profile screen.',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  color: AppColors.textTertiary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/home',
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warmCaramel,
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Back to Home',
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
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

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(PhosphorIcons.arrowLeft(),
                  size: 20, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'Become a Walker',
              style: GoogleFonts.nunito(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Step 4 of 4',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                'Review & Submit',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.warmCaramel,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: List.generate(4, (index) {
              return Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: index < 3 ? 4 : 0),
                  decoration: BoxDecoration(
                    color: AppColors.warmCaramel,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoSection() {
    final name = _applicationData['full_name'] ?? '';
    final phone = _applicationData['phone_number'] ?? '';
    final bio = _applicationData['bio'] ?? '';
    final photoUrl = _applicationData['profile_photo_url'] as String?;

    return _buildSection(
      title: 'Personal Information',
      editRoute: '/walker-application',
      children: [
        if (photoUrl != null && photoUrl.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  photoUrl,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(PhosphorIcons.user(),
                        size: 40, color: AppColors.textTertiary),
                  ),
                ),
              ),
            ),
          ),
        _buildField('Full Name', name),
        _buildField('Phone', phone),
        _buildField('Bio', bio),
      ],
    );
  }

  Widget _buildExperienceSection() {
    final level = _applicationData['experience_level'] ?? '';
    final years = _applicationData['years_experience']?.toString() ?? '0';
    final certs =
        (_applicationData['certifications'] as List<dynamic>?)?.cast<String>() ?? [];
    final serviceArea = _applicationData['service_area_description'] ?? '';
    final zipCodes =
        (_applicationData['service_zip_codes'] as List<dynamic>?)?.cast<String>() ?? [];

    return _buildSection(
      title: 'Experience & Qualifications',
      editRoute: '/walker-application-step2',
      children: [
        _buildField('Experience Level', _capitalize(level)),
        _buildField('Years of Experience', years),
        _buildField(
            'Certifications', certs.isNotEmpty ? certs.join(', ') : 'None'),
        _buildField('Service Area', serviceArea),
        _buildField(
            'Service Zip Codes', zipCodes.isNotEmpty ? zipCodes.join(', ') : 'None'),
      ],
    );
  }

  Widget _buildVerificationSection() {
    final emergencyName = _applicationData['emergency_contact_name'] ?? '';
    final emergencyPhone = _applicationData['emergency_contact_phone'] ?? '';
    final consent = _applicationData['background_check_consent'] == true;
    final hasId = (_applicationData['government_id_url'] as String?)?.isNotEmpty ?? false;

    return _buildSection(
      title: 'Identity & Verification',
      editRoute: '/walker-application-step3',
      children: [
        _buildField('Emergency Contact', emergencyName),
        _buildField('Emergency Phone', emergencyPhone),
        _buildField('Government ID', hasId ? 'Uploaded' : 'Not uploaded'),
        _buildField(
            'Background Check Consent', consent ? 'Agreed' : 'Not agreed'),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required String editRoute,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              GestureDetector(
                onTap: () => _navigateToStep(editRoute),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warmCaramel.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Edit',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.warmCaramel,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ...children,
        ],
      ),
    );
  }

  Widget _buildField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : '—',
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: _submitting ? null : _submitApplication,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.warmCaramel,
            foregroundColor: AppColors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          child: _submitting
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.white),
                  ),
                )
              : Text(
                  'Submit Application',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
      ),
    );
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}
