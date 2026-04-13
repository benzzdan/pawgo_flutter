import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:pawgo/theme/app_theme.dart';
import 'package:pawgo/services/error_handler.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class ApplicationStatusScreen extends StatefulWidget {
  const ApplicationStatusScreen({super.key});

  @override
  State<ApplicationStatusScreen> createState() =>
      _ApplicationStatusScreenState();
}

class _ApplicationStatusScreenState extends State<ApplicationStatusScreen> {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _application;
  bool _isLoading = true;
  String? _error;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _fetchApplication();
    _subscribeToUpdates();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _fetchApplication() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        ErrorHandler.instance.navigatorKey.currentState
            ?.pushNamedAndRemoveUntil('/', (route) => false);
        return;
      }

      final rows = await withRetry(() => _supabase
          .from('walker_applications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(1));

      if (!mounted) return;
      setState(() {
        _application = rows.isNotEmpty
            ? Map<String, dynamic>.from(rows[0])
            : null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final appError = AppError.from(e);
      if (appError.isAuthError) {
        ErrorHandler.instance.navigatorKey.currentState
            ?.pushNamedAndRemoveUntil('/', (route) => false);
        return;
      }
      setState(() {
        _error = appError.message;
        _isLoading = false;
      });
    }
  }

  void _subscribeToUpdates() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    _channel = _supabase.channel('walker_app_status_$userId');
    _channel!.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'walker_applications',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: userId,
      ),
      callback: (payload) {
        final updated = payload.newRecord;
        if (!mounted) return;
        setState(() {
          _application = Map<String, dynamic>.from(updated);
        });
      },
    );
    _channel!.subscribe();
  }

  String get _status => _application?['status'] as String? ?? 'pending';

  String get _backgroundCheckStatus =>
      _application?['background_check_status'] as String? ?? '';

  String? get _rejectionReason =>
      _application?['rejection_reason'] as String?;

  DateTime? get _createdAt {
    final raw = _application?['created_at'] as String?;
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  DateTime? get _reviewedAt {
    final raw = _application?['reviewed_at'] as String?;
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  bool get _canReapply {
    if (_status != 'rejected') return false;
    final reviewed = _reviewedAt;
    if (reviewed == null) return true;
    return DateTime.now().difference(reviewed).inDays >= 30;
  }

  int get _daysUntilReapply {
    final reviewed = _reviewedAt;
    if (reviewed == null) return 0;
    final eligible = reviewed.add(const Duration(days: 30));
    final remaining = eligible.difference(DateTime.now()).inDays;
    return remaining > 0 ? remaining : 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _application == null
                  ? _buildNoApplication()
                  : _buildContent(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(PhosphorIcons.warningCircle(), size: 48, color: AppColors.red500),
            const SizedBox(height: AppSpacing.md),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            GestureDetector(
              onTap: _fetchApplication,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.warmCaramel,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Retry',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoApplication() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(PhosphorIcons.fileText(),
                size: 48, color: AppColors.textTertiary),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No application found',
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Start your walker application to begin.',
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusCard(),
                const SizedBox(height: AppSpacing.lg),
                _buildTimeline(),
                if (_status == 'rejected') ...[
                  const SizedBox(height: AppSpacing.lg),
                  _buildRejectionInfo(),
                ],
                if (_status == 'background_check_in_progress') ...[
                  const SizedBox(height: AppSpacing.lg),
                  _buildBackgroundCheckInfo(),
                ],
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _statusHeaderColor(),
            _statusHeaderColor().withValues(alpha: 0.8),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xl),
          child: Column(
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(PhosphorIcons.arrowLeft(),
                          size: 20, color: Colors.white),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Application Status',
                    style: GoogleFonts.nunito(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 40),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(_statusIcon(), size: 32, color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                _statusLabel(),
                style: GoogleFonts.nunito(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _statusSubtitle(),
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Application Details',
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _buildDetailRow(
            'Full Name',
            _application?['full_name'] as String? ?? '-',
          ),
          _buildDetailRow(
            'Submitted',
            _createdAt != null
                ? DateFormat('MMM d, yyyy').format(_createdAt!)
                : '-',
          ),
          _buildDetailRow(
            'Status',
            _statusLabel(),
          ),
          if (_reviewedAt != null)
            _buildDetailRow(
              'Reviewed',
              DateFormat('MMM d, yyyy').format(_reviewedAt!),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    final steps = <_TimelineStep>[
      _TimelineStep(
        title: 'Application Submitted',
        subtitle: _createdAt != null
            ? DateFormat('MMM d, yyyy – h:mm a').format(_createdAt!)
            : null,
        isComplete: true,
      ),
      _TimelineStep(
        title: 'Under Review',
        subtitle: _status == 'pending'
            ? 'Your application is being reviewed'
            : null,
        isComplete: _status != 'pending',
        isActive: _status == 'pending',
      ),
      _TimelineStep(
        title: 'Background Check',
        subtitle: _status == 'background_check_in_progress'
            ? 'Estimated 3-5 business days'
            : _backgroundCheckStatus == 'passed'
                ? 'Passed'
                : _backgroundCheckStatus == 'failed'
                    ? 'Did not pass'
                    : null,
        isComplete: _backgroundCheckStatus == 'passed' ||
            _status == 'approved',
        isActive: _status == 'background_check_in_progress',
        isFailed: _backgroundCheckStatus == 'failed',
      ),
      _TimelineStep(
        title: 'Decision',
        subtitle: _status == 'approved'
            ? 'Approved! Welcome to the team.'
            : _status == 'rejected'
                ? 'Unfortunately, your application was not approved.'
                : null,
        isComplete: _status == 'approved',
        isFailed: _status == 'rejected',
        isActive: false,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Progress',
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ...steps.asMap().entries.map((entry) {
            final index = entry.key;
            final step = entry.value;
            final isLast = index == steps.length - 1;
            return _buildTimelineStep(step, isLast);
          }),
        ],
      ),
    );
  }

  Widget _buildTimelineStep(_TimelineStep step, bool isLast) {
    Color circleColor;
    IconData? circleIcon;

    if (step.isFailed) {
      circleColor = AppColors.red500;
      circleIcon = PhosphorIcons.x();
    } else if (step.isComplete) {
      circleColor = AppColors.green600;
      circleIcon = PhosphorIcons.check();
    } else if (step.isActive) {
      circleColor = AppColors.warmCaramel;
      circleIcon = null;
    } else {
      circleColor = AppColors.gray300;
      circleIcon = null;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: circleColor,
                  shape: BoxShape.circle,
                  boxShadow: step.isActive
                      ? [
                          BoxShadow(
                            color: circleColor.withValues(alpha: 0.4),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
                child: circleIcon != null
                    ? Icon(circleIcon, size: 16, color: Colors.white)
                    : step.isActive
                        ? Center(
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                          )
                        : null,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: step.isComplete
                        ? AppColors.green600
                        : AppColors.gray300,
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.title,
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: step.isActive || step.isComplete || step.isFailed
                          ? AppColors.textPrimary
                          : AppColors.textTertiary,
                    ),
                  ),
                  if (step.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      step.subtitle!,
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: step.isFailed
                            ? AppColors.red500
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRejectionInfo() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.red50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.red500.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(PhosphorIcons.info(), size: 20, color: AppColors.red500),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Application Not Approved',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppColors.red500,
                ),
              ),
            ],
          ),
          if (_rejectionReason != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _rejectionReason!,
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          if (_canReapply)
            GestureDetector(
              onTap: () =>
                  Navigator.pushNamed(context, '/walker-application'),
              child: Container(
                width: double.infinity,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.warmCaramel,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    'Re-apply',
                    style: GoogleFonts.nunito(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            )
          else
            Text(
              'You can re-apply in $_daysUntilReapply day${_daysUntilReapply == 1 ? '' : 's'}.',
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBackgroundCheckInfo() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.blue50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.blue500.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(PhosphorIcons.shieldCheck(),
                  size: 20, color: AppColors.blue600),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Background Check In Progress',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppColors.blue600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Your identity verification is being processed. This typically takes 3-5 business days. '
            'You will be notified when it is complete.',
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Color _statusHeaderColor() {
    switch (_status) {
      case 'approved':
        return AppColors.green600;
      case 'rejected':
        return AppColors.red500;
      case 'background_check_in_progress':
        return AppColors.blue600;
      default:
        return AppColors.warmCaramel;
    }
  }

  IconData _statusIcon() {
    switch (_status) {
      case 'approved':
        return PhosphorIcons.checkCircle();
      case 'rejected':
        return PhosphorIcons.xCircle();
      case 'background_check_in_progress':
        return PhosphorIcons.shieldCheck();
      default:
        return PhosphorIcons.hourglass();
    }
  }

  String _statusLabel() {
    switch (_status) {
      case 'pending':
        return 'Pending Review';
      case 'background_check_in_progress':
        return 'Background Check In Progress';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      default:
        return _status;
    }
  }

  String _statusSubtitle() {
    switch (_status) {
      case 'pending':
        return 'Your application is being reviewed by our team.\nWe\'ll notify you when there\'s an update.';
      case 'background_check_in_progress':
        return 'Your identity is being verified.\nEstimated completion: 3-5 business days.';
      case 'approved':
        return 'Congratulations! You\'re now a Pawgo Walker.\nSwitch to walker mode from your Profile.';
      case 'rejected':
        return 'We were unable to approve your application at this time.';
      default:
        return '';
    }
  }
}

class _TimelineStep {
  final String title;
  final String? subtitle;
  final bool isComplete;
  final bool isActive;
  final bool isFailed;

  const _TimelineStep({
    required this.title,
    this.subtitle,
    this.isComplete = false,
    this.isActive = false,
    this.isFailed = false,
  });
}
