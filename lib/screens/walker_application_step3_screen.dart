import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pawgo/theme/app_theme.dart';
import 'package:pawgo/services/error_handler.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class WalkerApplicationStep3Screen extends StatefulWidget {
  const WalkerApplicationStep3Screen({super.key});

  @override
  State<WalkerApplicationStep3Screen> createState() =>
      _WalkerApplicationStep3ScreenState();
}

class _WalkerApplicationStep3ScreenState
    extends State<WalkerApplicationStep3Screen> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();

  File? _idFrontPhoto;
  File? _idBackPhoto;
  bool _backgroundCheckConsent = false;
  bool _saving = false;
  bool _loading = true;
  String? _applicationId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      _applicationId = args?['application_id'] as String?;
      _loadExistingData();
    });
  }

  @override
  void dispose() {
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingData() async {
    if (_applicationId == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final rows = await withRetry(() => _supabase
          .from('walker_applications')
          .select()
          .eq('id', _applicationId!)
          .limit(1));

      if (rows.isNotEmpty) {
        final app = rows[0];
        _emergencyNameController.text =
            app['emergency_contact_name'] as String? ?? '';
        _emergencyPhoneController.text =
            app['emergency_contact_phone'] as String? ?? '';
        _backgroundCheckConsent =
            app['background_check_consent'] as bool? ?? false;
      }
    } catch (_) {
      // Continue with empty form
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickIdPhoto({required bool isFront}) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(PhosphorIcons.camera(),
                    color: AppColors.warmCaramel),
                title: Text('Take Photo',
                    style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: Icon(PhosphorIcons.images(),
                    color: AppColors.warmCaramel),
                title: Text('Choose from Gallery',
                    style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() {
        if (isFront) {
          _idFrontPhoto = File(picked.path);
        } else {
          _idBackPhoto = File(picked.path);
        }
      });
    }
  }

  Future<String?> _uploadIdPhoto(
      String applicationId, File photo, String side) async {
    final userId = _supabase.auth.currentUser!.id;
    final bytes = await photo.readAsBytes();
    final ext = photo.path.split('.').last.toLowerCase();
    final path = '$userId/$applicationId/id_$side.$ext';

    await _supabase.storage.from('walker-ids').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );

    // Return the path (not public URL since this is a private bucket)
    return path;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Emergency contact phone is required';
    }
    final cleaned = value.trim().replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (!RegExp(r'^\+52\d{10}$').hasMatch(cleaned)) {
      return 'Enter a valid Mexico phone (+52 followed by 10 digits)';
    }
    return null;
  }

  Future<void> _saveAndNext() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate ID photos
    if (_idFrontPhoto == null) {
      ErrorHandler.instance
          .showRecoverableError(context, 'Please add your INE front photo');
      return;
    }
    if (_idBackPhoto == null) {
      ErrorHandler.instance
          .showRecoverableError(context, 'Please add your INE back photo');
      return;
    }

    // Validate consent
    if (!_backgroundCheckConsent) {
      ErrorHandler.instance.showRecoverableError(
          context, 'You must consent to the background check to proceed');
      return;
    }

    setState(() => _saving = true);

    try {
      if (_applicationId == null) {
        ErrorHandler.instance
            .showRecoverableError(context, 'Application not found');
        return;
      }

      // Upload ID photos to private bucket
      final frontPath =
          await _uploadIdPhoto(_applicationId!, _idFrontPhoto!, 'front');
      final backPath =
          await _uploadIdPhoto(_applicationId!, _idBackPhoto!, 'back');

      // Store both paths as a combined reference
      final idUrl = '$frontPath|$backPath';

      final record = {
        'emergency_contact_name': _emergencyNameController.text.trim(),
        'emergency_contact_phone': _emergencyPhoneController.text.trim(),
        'background_check_consent': true,
        'government_id_url': idUrl,
      };

      await withRetry(() => _supabase
          .from('walker_applications')
          .update(record)
          .eq('id', _applicationId!));

      if (mounted) {
        Navigator.pushNamed(
          context,
          '/walker-application-step4',
          arguments: {'application_id': _applicationId},
        );
      }
    } catch (e) {
      if (mounted) {
        final appError = AppError.from(e);
        if (appError.isAuthError) {
          ErrorHandler.instance.navigatorKey.currentState
              ?.pushNamedAndRemoveUntil('/', (route) => false);
        } else {
          ErrorHandler.instance
              .showRecoverableError(context, appError.message);
        }
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            _buildProgressIndicator(),
            if (_loading)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.warmCaramel,
                  ),
                ),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('Identity Verification'),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'We need to verify your identity to ensure the safety of pets and their owners. Your documents are stored securely and only accessible by our team.',
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _buildIdPhotoSection(),
                        const SizedBox(height: AppSpacing.lg),
                        _buildSectionTitle('Emergency Contact'),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Someone we can contact in case of an emergency during a walk.',
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _buildTextField(
                          controller: _emergencyNameController,
                          label: 'Emergency Contact Name',
                          hint: 'Full name of your emergency contact',
                          icon: PhosphorIcons.user(),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Emergency contact name is required'
                              : null,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _buildTextField(
                          controller: _emergencyPhoneController,
                          label: 'Emergency Contact Phone',
                          hint: '+52 55 1234 5678',
                          icon: PhosphorIcons.phone(),
                          keyboardType: TextInputType.phone,
                          validator: _validatePhone,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _buildBackgroundCheckConsent(),
                        const SizedBox(height: AppSpacing.xl),
                        _buildButtons(),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                    ),
                  ),
                ),
              ),
          ],
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
                'Step 3 of 4',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.warmCaramel,
                ),
              ),
              Text(
                'Verification',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: List.generate(4, (index) {
              final isActive = index <= 2;
              return Expanded(
                child: Container(
                  height: 4,
                  margin:
                      EdgeInsets.only(right: index < 3 ? AppSpacing.xs : 0),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.warmCaramel
                        : AppColors.borderLight,
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

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.nunito(
        fontSize: 18,
        fontWeight: FontWeight.w900,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildIdPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Government ID (INE)',
          style: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Take or upload clear photos of the front and back of your INE (credencial para votar)',
          style: GoogleFonts.nunito(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _buildIdPhotoCard(
                label: 'INE Front',
                photo: _idFrontPhoto,
                onTap: () => _pickIdPhoto(isFront: true),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildIdPhotoCard(
                label: 'INE Back',
                photo: _idBackPhoto,
                onTap: () => _pickIdPhoto(isFront: false),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildIdPhotoCard({
    required String label,
    required File? photo,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: photo != null
                ? AppColors.warmCaramel
                : AppColors.borderLight,
            width: photo != null ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: photo != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(photo, fit: BoxFit.cover),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.xs),
                      color: AppColors.cacaoBrown.withValues(alpha: 0.7),
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: AppSpacing.xs,
                    right: AppSpacing.xs,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        color: AppColors.warmCaramel,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(PhosphorIcons.check(),
                          size: 16, color: AppColors.white),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(PhosphorIcons.identificationCard(),
                      size: 32, color: AppColors.warmCaramel),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    label,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tap to add',
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
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
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          style: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
            ),
            prefixIcon: Icon(icon, size: 20, color: AppColors.warmCaramel),
            filled: true,
            fillColor: AppColors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.borderLight),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.borderLight),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: AppColors.warmCaramel, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.red500),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: AppColors.red500, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildBackgroundCheckConsent() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _backgroundCheckConsent
              ? AppColors.warmCaramel
              : AppColors.borderLight,
          width: _backgroundCheckConsent ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(PhosphorIcons.shieldCheck(PhosphorIconsStyle.fill),
                  size: 20, color: AppColors.warmCaramel),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Background Check Consent',
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'By checking this box, you consent to a background check that may include:',
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildCheckItem('Criminal history search'),
          _buildCheckItem('Identity verification (INE/CURP)'),
          _buildCheckItem('Address verification'),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Your information is handled securely and in compliance with Mexican data protection laws (LFPDPPP).',
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: _backgroundCheckConsent,
                  onChanged: (value) {
                    setState(
                        () => _backgroundCheckConsent = value ?? false);
                  },
                  activeColor: AppColors.warmCaramel,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() =>
                      _backgroundCheckConsent = !_backgroundCheckConsent),
                  child: Text(
                    'I consent to a background check and agree to the Privacy Policy and Terms of Service',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCheckItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Icon(PhosphorIcons.checkCircle(),
              size: 16, color: AppColors.warmCaramel),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _saving ? null : _saveAndNext,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warmCaramel,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: _saving
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
                    'Next',
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              'Back',
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
