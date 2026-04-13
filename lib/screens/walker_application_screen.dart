import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pawgo/theme/app_theme.dart';
import 'package:pawgo/services/error_handler.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class WalkerApplicationScreen extends StatefulWidget {
  const WalkerApplicationScreen({super.key});

  @override
  State<WalkerApplicationScreen> createState() =>
      _WalkerApplicationScreenState();
}

class _WalkerApplicationScreenState extends State<WalkerApplicationScreen> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _bioController = TextEditingController();

  File? _pickedPhoto;
  bool _saving = false;
  String? _existingApplicationId;

  static const int _bioMaxLength = 500;

  @override
  void initState() {
    super.initState();
    _loadExistingDraft();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingDraft() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final rows = await withRetry(() => _supabase
          .from('walker_applications')
          .select()
          .eq('user_id', userId)
          .eq('status', 'pending')
          .limit(1));

      if (rows.isNotEmpty) {
        final app = rows[0];
        _existingApplicationId = app['id'] as String?;
        _nameController.text = app['full_name'] as String? ?? '';
        _phoneController.text = app['phone_number'] as String? ?? '';
        _bioController.text = app['bio'] as String? ?? '';
        if (mounted) setState(() {});
      }
    } catch (e) {
      // Silently continue — user can still fill form fresh
    }
  }

  Future<void> _pickPhoto() async {
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
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() => _pickedPhoto = File(picked.path));
    }
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    final cleaned = value.trim().replaceAll(RegExp(r'[\s\-\(\)]'), '');
    // Accept +52 followed by 10 digits
    if (!RegExp(r'^\+52\d{10}$').hasMatch(cleaned)) {
      return 'Enter a valid Mexico phone (+52 followed by 10 digits)';
    }
    return null;
  }

  Future<String?> _uploadPhoto(String applicationId) async {
    if (_pickedPhoto == null) return null;

    final userId = _supabase.auth.currentUser!.id;
    final bytes = await _pickedPhoto!.readAsBytes();
    final ext = _pickedPhoto!.path.split('.').last.toLowerCase();
    final path = '$userId/$applicationId/profile.$ext';

    await _supabase.storage.from('walker-applications').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );

    return _supabase.storage
        .from('walker-applications')
        .getPublicUrl(path);
  }

  Future<void> _saveAndNext() async {
    if (!_formKey.currentState!.validate()) return;

    if (_pickedPhoto == null && _existingApplicationId == null) {
      ErrorHandler.instance
          .showRecoverableError(context, 'Please add a profile photo');
      return;
    }

    setState(() => _saving = true);

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        ErrorHandler.instance.navigatorKey.currentState
            ?.pushNamedAndRemoveUntil('/', (route) => false);
        return;
      }

      final record = {
        'user_id': userId,
        'full_name': _nameController.text.trim(),
        'phone_number': _phoneController.text.trim(),
        'bio': _bioController.text.trim(),
      };

      String applicationId;

      if (_existingApplicationId != null) {
        // Update existing draft
        applicationId = _existingApplicationId!;
        await withRetry(() => _supabase
            .from('walker_applications')
            .update(record..remove('user_id'))
            .eq('id', applicationId));
      } else {
        // Insert new application
        final result = await withRetry(() => _supabase
            .from('walker_applications')
            .insert(record)
            .select()
            .single());
        applicationId = result['id'] as String;
        _existingApplicationId = applicationId;
      }

      // Upload photo if picked
      if (_pickedPhoto != null) {
        final photoUrl = await _uploadPhoto(applicationId);
        if (photoUrl != null) {
          await _supabase
              .from('walker_applications')
              .update({'profile_photo_url': photoUrl}).eq('id', applicationId);
        }
      }

      if (mounted) {
        // Navigate to step 2 (will be built in US-004)
        Navigator.pushNamed(
          context,
          '/walker-application-step2',
          arguments: {'application_id': applicationId},
        );
      }
    } catch (e) {
      if (mounted) {
        final appError = AppError.from(e);
        if (appError.isAuthError) {
          ErrorHandler.instance.navigatorKey.currentState
              ?.pushNamedAndRemoveUntil('/', (route) => false);
        } else {
          ErrorHandler.instance.showRecoverableError(
              context, appError.message);
        }
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            _buildProgressIndicator(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Personal Information'),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Tell us a bit about yourself so pet owners can get to know you.',
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _buildPhotoSection(),
                      const SizedBox(height: AppSpacing.lg),
                      _buildTextField(
                        controller: _nameController,
                        label: 'Full Name',
                        hint: 'Enter your full legal name',
                        icon: PhosphorIcons.user(),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Full name is required'
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _buildTextField(
                        controller: _phoneController,
                        label: 'Phone Number',
                        hint: '+52 55 1234 5678',
                        icon: PhosphorIcons.phone(),
                        keyboardType: TextInputType.phone,
                        validator: _validatePhone,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _buildBioField(),
                      const SizedBox(height: AppSpacing.xl),
                      _buildNextButton(),
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
                'Step 1 of 4',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.warmCaramel,
                ),
              ),
              Text(
                'Personal Info',
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
              final isActive = index == 0;
              return Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(
                      right: index < 3 ? AppSpacing.xs : 0),
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

  Widget _buildPhotoSection() {
    return Center(
      child: GestureDetector(
        onTap: _pickPhoto,
        child: Column(
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.warmCaramel.withValues(alpha: 0.3),
                  width: 3,
                ),
                image: _pickedPhoto != null
                    ? DecorationImage(
                        image: FileImage(_pickedPhoto!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: _pickedPhoto == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(PhosphorIcons.camera(),
                            size: 32, color: AppColors.warmCaramel),
                        SizedBox(height: 4),
                        Text('Add Photo',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary)),
                      ],
                    )
                  : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _pickedPhoto != null ? 'Tap to change' : 'Profile photo *',
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _pickedPhoto != null
                    ? AppColors.textSecondary
                    : AppColors.warmCaramel,
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

  Widget _buildBioField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Bio',
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _bioController,
              builder: (_, value, __) {
                final count = value.text.length;
                return Text(
                  '$count / $_bioMaxLength',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: count > _bioMaxLength
                        ? AppColors.red500
                        : AppColors.textTertiary,
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: _bioController,
          maxLines: 4,
          maxLength: _bioMaxLength,
          buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
          validator: (v) => (v == null || v.trim().isEmpty)
              ? 'Please write a short bio'
              : null,
          style: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText:
                'Tell pet owners about yourself, your experience with dogs, and why you love walking them...',
            hintStyle: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
            ),
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
            contentPadding: const EdgeInsets.all(AppSpacing.md),
          ),
        ),
      ],
    );
  }

  Widget _buildNextButton() {
    return SizedBox(
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
    );
  }
}
