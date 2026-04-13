import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pawgo/theme/app_theme.dart';
import 'package:pawgo/services/error_handler.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class WalkerApplicationStep2Screen extends StatefulWidget {
  const WalkerApplicationStep2Screen({super.key});

  @override
  State<WalkerApplicationStep2Screen> createState() =>
      _WalkerApplicationStep2ScreenState();
}

class _WalkerApplicationStep2ScreenState
    extends State<WalkerApplicationStep2Screen> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _serviceAreaController = TextEditingController();
  final _zipCodeController = TextEditingController();
  final _otherCertController = TextEditingController();
  final _yearsController = TextEditingController();

  String _experienceLevel = 'beginner';
  final List<String> _selectedCertifications = [];
  final List<String> _zipCodes = [];
  bool _saving = false;
  bool _loading = true;
  String? _applicationId;

  static const List<String> _experienceLevels = [
    'beginner',
    'intermediate',
    'expert',
  ];

  static const Map<String, String> _experienceLevelLabels = {
    'beginner': 'Beginner',
    'intermediate': 'Intermediate',
    'expert': 'Expert',
  };

  static const List<String> _certificationOptions = [
    'Pet First Aid',
    'Dog Training',
    'Veterinary Assistant',
  ];

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
    _serviceAreaController.dispose();
    _zipCodeController.dispose();
    _otherCertController.dispose();
    _yearsController.dispose();
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
        final level = app['experience_level'] as String?;
        if (level != null && _experienceLevels.contains(level)) {
          _experienceLevel = level;
        }
        final years = app['years_experience'];
        if (years != null) {
          _yearsController.text = years.toString();
        }
        final certs = app['certifications'];
        if (certs is List) {
          for (final c in certs) {
            _selectedCertifications.add(c.toString());
          }
        }
        _serviceAreaController.text =
            app['service_area_description'] as String? ?? '';
        final zips = app['service_zip_codes'];
        if (zips is List) {
          for (final z in zips) {
            _zipCodes.add(z.toString());
          }
        }
      }
    } catch (_) {
      // Continue with empty form
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveAndNext() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      if (_applicationId == null) {
        ErrorHandler.instance
            .showRecoverableError(context, 'Application not found');
        return;
      }

      final record = {
        'experience_level': _experienceLevel,
        'years_experience': int.tryParse(_yearsController.text.trim()) ?? 0,
        'certifications': _selectedCertifications,
        'service_area_description': _serviceAreaController.text.trim(),
        'service_zip_codes': _zipCodes,
      };

      await withRetry(() => _supabase
          .from('walker_applications')
          .update(record)
          .eq('id', _applicationId!));

      if (mounted) {
        Navigator.pushNamed(
          context,
          '/walker-application-step3',
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

  void _addZipCode() {
    final code = _zipCodeController.text.trim();
    if (code.isEmpty) return;

    // Mexican postal codes are 5 digits
    if (!RegExp(r'^\d{5}$').hasMatch(code)) {
      ErrorHandler.instance
          .showRecoverableError(context, 'Enter a valid 5-digit postal code');
      return;
    }

    if (_zipCodes.contains(code)) {
      ErrorHandler.instance
          .showRecoverableError(context, 'Postal code already added');
      return;
    }

    setState(() {
      _zipCodes.add(code);
      _zipCodeController.clear();
    });
  }

  void _toggleCertification(String cert) {
    setState(() {
      if (_selectedCertifications.contains(cert)) {
        _selectedCertifications.remove(cert);
      } else {
        _selectedCertifications.add(cert);
      }
    });
  }

  void _addOtherCertification() {
    final cert = _otherCertController.text.trim();
    if (cert.isEmpty) return;

    if (_selectedCertifications.contains(cert)) {
      ErrorHandler.instance
          .showRecoverableError(context, 'Certification already added');
      return;
    }

    setState(() {
      _selectedCertifications.add(cert);
      _otherCertController.clear();
    });
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
                        _buildSectionTitle('Experience & Qualifications'),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Help us understand your experience with dogs so we can match you with the right clients.',
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _buildExperienceLevelDropdown(),
                        const SizedBox(height: AppSpacing.md),
                        _buildYearsField(),
                        const SizedBox(height: AppSpacing.lg),
                        _buildCertificationsSection(),
                        const SizedBox(height: AppSpacing.lg),
                        _buildServiceAreaField(),
                        const SizedBox(height: AppSpacing.lg),
                        _buildZipCodesSection(),
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
                'Step 2 of 4',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.warmCaramel,
                ),
              ),
              Text(
                'Experience',
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
              final isActive = index <= 1;
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

  Widget _buildExperienceLevelDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Experience Level',
          style: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<String>(
          initialValue: _experienceLevel,
          onChanged: (value) {
            if (value != null) setState(() => _experienceLevel = value);
          },
          validator: (v) =>
              (v == null || v.isEmpty) ? 'Please select your experience level' : null,
          style: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          icon: Icon(PhosphorIcons.caretDown(),
              color: AppColors.warmCaramel),
          decoration: InputDecoration(
            prefixIcon: Icon(PhosphorIcons.trendUp(),
                size: 20, color: AppColors.warmCaramel),
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
            contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: 14),
          ),
          items: _experienceLevels.map((level) {
            return DropdownMenuItem(
              value: level,
              child: Text(_experienceLevelLabels[level] ?? level),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildYearsField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Years of Experience with Dogs',
          style: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: _yearsController,
          keyboardType: TextInputType.number,
          validator: (v) {
            if (v == null || v.trim().isEmpty) {
              return 'Years of experience is required';
            }
            final years = int.tryParse(v.trim());
            if (years == null || years < 0) {
              return 'Enter a valid number';
            }
            return null;
          },
          style: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: 'e.g. 3',
            hintStyle: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
            ),
            prefixIcon: Icon(PhosphorIcons.calendarBlank(),
                size: 20, color: AppColors.warmCaramel),
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

  Widget _buildCertificationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Certifications',
          style: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Select any certifications you hold (optional)',
          style: GoogleFonts.nunito(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            ..._certificationOptions.map((cert) => _buildCertChip(cert)),
            // Show custom certifications not in the default list
            ..._selectedCertifications
                .where((c) => !_certificationOptions.contains(c))
                .map((cert) => _buildCertChip(cert, isCustom: true)),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _otherCertController,
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Other certification...',
                  hintStyle: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textTertiary,
                  ),
                  filled: true,
                  fillColor: AppColors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: AppColors.borderLight),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: AppColors.borderLight),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                        color: AppColors.warmCaramel, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: 14),
                ),
                onFieldSubmitted: (_) => _addOtherCertification(),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            GestureDetector(
              onTap: _addOtherCertification,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.warmCaramel,
                  borderRadius: BorderRadius.circular(14),
                ),
                child:
                    Icon(PhosphorIcons.plus(PhosphorIconsStyle.bold), color: AppColors.white, size: 24),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCertChip(String cert, {bool isCustom = false}) {
    final isSelected = _selectedCertifications.contains(cert);
    return GestureDetector(
      onTap: () => _toggleCertification(cert),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.warmCaramel.withValues(alpha: 0.15)
              : AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.warmCaramel : AppColors.borderLight,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
                    size: 16, color: AppColors.warmCaramel),
              ),
            Text(
              cert,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? AppColors.warmCaramel
                    : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceAreaField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Service Area Description',
          style: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: _serviceAreaController,
          maxLines: 3,
          validator: (v) => (v == null || v.trim().isEmpty)
              ? 'Please describe your service area'
              : null,
          style: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText:
                'Describe the neighborhoods or areas where you can walk dogs (e.g., Colonia Roma, Condesa, Polanco)...',
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

  Widget _buildZipCodesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Service Postal Codes',
          style: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Add the Mexican postal codes where you can provide service',
          style: GoogleFonts.nunito(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _zipCodeController,
                keyboardType: TextInputType.number,
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'e.g. 06600',
                  hintStyle: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textTertiary,
                  ),
                  prefixIcon: Icon(PhosphorIcons.mapPin(PhosphorIconsStyle.fill),
                      size: 20, color: AppColors.warmCaramel),
                  filled: true,
                  fillColor: AppColors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: AppColors.borderLight),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: AppColors.borderLight),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                        color: AppColors.warmCaramel, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: 14),
                ),
                onFieldSubmitted: (_) => _addZipCode(),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            GestureDetector(
              onTap: _addZipCode,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.warmCaramel,
                  borderRadius: BorderRadius.circular(14),
                ),
                child:
                    Icon(PhosphorIcons.plus(PhosphorIconsStyle.bold), color: AppColors.white, size: 24),
              ),
            ),
          ],
        ),
        if (_zipCodes.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: _zipCodes.map((code) {
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                decoration: BoxDecoration(
                  color: AppColors.warmCaramel.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: AppColors.warmCaramel, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(PhosphorIcons.mapPin(PhosphorIconsStyle.fill),
                        size: 14, color: AppColors.warmCaramel),
                    const SizedBox(width: 4),
                    Text(
                      code,
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.warmCaramel,
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () =>
                          setState(() => _zipCodes.remove(code)),
                      child: Icon(PhosphorIcons.x(),
                          size: 16, color: AppColors.warmCaramel),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ],
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
