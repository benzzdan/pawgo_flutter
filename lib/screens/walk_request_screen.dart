import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pawgo/theme/app_theme.dart';
import 'package:pawgo/services/error_handler.dart';
import 'package:pawgo/services/analytics_service.dart';
import 'package:pawgo/services/booking_status_service.dart';
import 'package:pawgo/utils/walk_request_cancellation.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pawgo/widgets/paw_progress_indicator.dart';

/// Walk request detail screen where walkers can accept or decline a booking.
///
/// Receives route arguments:
///   - `booking_id` (String, required)
///   - `_test_booking` (Map, optional) — injected booking data for widget tests
class WalkRequestScreen extends StatefulWidget {
  const WalkRequestScreen({super.key});

  @override
  State<WalkRequestScreen> createState() => _WalkRequestScreenState();
}

class _WalkRequestScreenState extends State<WalkRequestScreen> {
  SupabaseClient get _supabase => Supabase.instance.client;
  Map<String, dynamic>? _booking;
  bool _isLoading = true;
  String? _error;
  bool _isResponding = false;
  bool _isExpired = false;
  bool _cancelled = false;
  Timer? _countdownTimer;
  Duration _timeRemaining = Duration.zero;
  BookingStatusService? _statusService;
  StreamSubscription<BookingStatusUpdate>? _statusSub;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_booking == null && _isLoading) {
      _initBooking();
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _statusSub?.cancel();
    _statusService?.dispose();
    super.dispose();
  }

  void _initBooking() {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final testBooking = args?['_test_booking'] as Map<String, dynamic>?;

    if (testBooking != null) {
      // Test mode: use injected data, skip Realtime subscription
      setState(() {
        _booking = testBooking;
        _isLoading = false;
      });
      _startCountdown();
    } else {
      final bookingId = args?['booking_id'] as String?;
      if (bookingId == null) {
        setState(() {
          _isLoading = false;
          _error = 'No booking ID provided';
        });
        return;
      }
      _fetchBooking(bookingId);
    }
  }

  Future<void> _fetchBooking(String bookingId) async {
    try {
      final booking = await withRetry(() => _supabase
          .from('bookings')
          .select(
              '*, dogs(name, breed, photo_url), users!bookings_owner_id_fkey(full_name, avatar_url), walkers(user_id, hourly_rate_mxn)')
          .eq('id', bookingId)
          .single());

      if (!mounted) return;
      setState(() {
        _booking = booking;
        _isLoading = false;
      });
      _startCountdown();
      _subscribeToCancellation(bookingId);
    } catch (e) {
      if (!mounted) return;
      final appError = AppError.from(e);
      if (appError.isAuthError) {
        ErrorHandler.instance.navigatorKey.currentState
            ?.pushNamedAndRemoveUntil('/', (route) => false);
        return;
      }
      setState(() {
        _isLoading = false;
        _error = appError.isNetworkError
            ? 'No internet connection. Please check your network.'
            : 'Failed to load walk request';
      });
    }
  }

  void _subscribeToCancellation(String? bookingId) {
    if (bookingId == null) return;
    _statusService = BookingStatusService();
    _statusService!.subscribeToBooking(bookingId);
    _statusSub = _statusService!.statusStream.listen(_onBookingStatusUpdate);
  }

  void _onBookingStatusUpdate(BookingStatusUpdate update) {
    if (!mounted) return;
    if (shouldAutoExitOnCancellation(
      newStatus: update.newStatus,
      isWalkerScreen: true,
      alreadyCancelled: _cancelled,
    )) {
      _cancelled = true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'The owner canceled this walk request',
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          backgroundColor: AppColors.red500,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(AppSpacing.md),
          duration: const Duration(seconds: 3),
        ),
      );
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
    }
  }

  void _startCountdown() {
    final deadlineStr = _booking?['acceptance_deadline'] as String?;
    if (deadlineStr == null) return;

    final deadline = DateTime.tryParse(deadlineStr);
    if (deadline == null) return;

    _updateTimeRemaining(deadline);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateTimeRemaining(deadline);
    });
  }

  void _updateTimeRemaining(DateTime deadline) {
    final now = DateTime.now().toUtc();
    final remaining = deadline.difference(now);

    if (remaining.isNegative) {
      _countdownTimer?.cancel();
      if (mounted) {
        setState(() {
          _isExpired = true;
          _timeRemaining = Duration.zero;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _timeRemaining = remaining;
          _isExpired = false;
        });
      }
    }
  }

  Future<void> _respondToBooking(String action) async {
    final bookingId = _booking?['id'] as String?;
    if (bookingId == null) return;

    if (action == 'decline') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            'Decline Request?',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
          ),
          content: Text(
            'Are you sure you want to decline this walk request?',
            style: GoogleFonts.nunito(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.red500,
              ),
              child: Text('Decline',
                  style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    setState(() => _isResponding = true);

    try {
      final res = await withRetry(() => _supabase.functions.invoke(
            'respond-to-booking',
            body: {'booking_id': bookingId, 'action': action},
          ));

      if (!mounted) return;

      final data = res.data;
      if (res.status != 200) {
        setState(() => _isResponding = false);
        ErrorHandler.instance.handleFunctionError(
          context,
          res,
          screen: 'walk_request',
          fallbackMessage: 'Failed to $action walk request',
        );
        return;
      }

      final success = data is Map ? data['success'] == true : false;
      if (success) {
        if (action == 'accept') {
          AnalyticsService.instance.capture('walk_request_accepted',
              {'booking_id': bookingId});
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Walk request accepted!',
                  style: GoogleFonts.nunito(color: Colors.white)),
              backgroundColor: AppColors.green600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(AppSpacing.md),
            ),
          );
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/home',
            (route) => false,
          );
        } else {
          AnalyticsService.instance.capture('walk_request_declined',
              {'booking_id': bookingId});
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Walk request declined',
                  style: GoogleFonts.nunito(color: Colors.white)),
              backgroundColor: AppColors.textSecondary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(AppSpacing.md),
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isResponding = false);
      ErrorHandler.instance.handleError(
        context,
        e,
        screen: 'walk_request',
        fallbackMessage: 'Failed to respond to walk request. Please try again.',
      );
    }
  }

  String _formatCountdown(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(String? isoString) {
    if (isoString == null) return 'Not scheduled';
    final dt = DateTime.tryParse(isoString);
    if (dt == null) return isoString;
    final local = dt.toLocal();
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hour =
        local.hour > 12 ? local.hour - 12 : (local.hour == 0 ? 12 : local.hour);
    final amPm = local.hour >= 12 ? 'PM' : 'AM';
    final min = local.minute.toString().padLeft(2, '0');
    return '${months[local.month - 1]} ${local.day}, ${local.year} at $hour:$min $amPm';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text(
          'Walk Request',
          style: GoogleFonts.nunito(
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child:
                  PawProgressIndicator(color: AppColors.orange500))
          : _error != null
              ? _buildErrorState()
              : _buildContent(theme),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(PhosphorIcons.warningCircle(),
                size: 48, color: AppColors.textSecondary),
            const SizedBox(height: AppSpacing.md),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style:
                  GoogleFonts.nunito(fontSize: 16, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(
              onPressed: () {
                final args = ModalRoute.of(context)?.settings.arguments
                    as Map<String, dynamic>?;
                final bookingId = args?['booking_id'] as String?;
                if (bookingId != null) {
                  setState(() {
                    _isLoading = true;
                    _error = null;
                  });
                  _fetchBooking(bookingId);
                }
              },
              child: Text('Retry',
                  style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    if (_booking == null) return const SizedBox.shrink();

    final dog = _booking!['dogs'] as Map<String, dynamic>?;
    final owner = _booking!['users'] as Map<String, dynamic>?;
    final walker = _booking!['walkers'] as Map<String, dynamic>?;
    final scheduledAt = _booking!['scheduled_at'] as String?;
    final durationMinutes = _booking!['duration_minutes'] as int?;
    final hourlyRate = (walker?['hourly_rate_mxn'] as num?)?.toDouble() ??
        (_booking!['hourly_rate_mxn'] as num?)?.toDouble() ??
        0;
    final estimatedEarnings =
        durationMinutes != null ? (hourlyRate * durationMinutes / 60).round() : 0;
    final pickupLocation = _booking!['pickup_location'] as String?;
    final dogPhotoUrl = dog?['photo_url'] as String?;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Countdown timer or expired badge
          _buildCountdownSection(),
          const SizedBox(height: AppSpacing.lg),

          // Owner info card
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(AppRadius.card),
              boxShadow: AppShadows.card,
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.orange50,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: owner?['avatar_url'] != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.network(
                            owner!['avatar_url'],
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(
                                PhosphorIcons.user(),
                                color: AppColors.orange500),
                          ),
                        )
                      : Icon(PhosphorIcons.user(),
                          color: AppColors.orange500),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        owner?['full_name'] ?? 'Dog Owner',
                        style: GoogleFonts.nunito(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Requesting a walk',
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Dog info card
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(AppRadius.card),
              boxShadow: AppShadows.card,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.orange50,
                  backgroundImage:
                      dogPhotoUrl != null ? NetworkImage(dogPhotoUrl) : null,
                  onBackgroundImageError:
                      dogPhotoUrl != null ? (_, __) {} : null,
                  child: dogPhotoUrl == null
                      ? Icon(PhosphorIcons.pawPrint(),
                          size: 28, color: AppColors.orange500)
                      : null,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dog?['name'] ?? 'Unknown Dog',
                        style: GoogleFonts.nunito(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (dog?['breed'] != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          dog!['breed'],
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Details card
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(AppRadius.card),
              boxShadow: AppShadows.card,
            ),
            child: Column(
              children: [
                _DetailRow(
                  icon: PhosphorIcons.calendarBlank(),
                  iconColor: AppColors.blue600,
                  bgColor: AppColors.blue50,
                  label: 'Scheduled',
                  value: _formatDateTime(scheduledAt),
                ),
                const SizedBox(height: AppSpacing.md),
                _DetailRow(
                  icon: PhosphorIcons.clock(),
                  iconColor: AppColors.purple600,
                  bgColor: AppColors.purple50,
                  label: 'Duration',
                  value:
                      durationMinutes != null ? '$durationMinutes min' : 'N/A',
                ),
                const SizedBox(height: AppSpacing.md),
                _DetailRow(
                  icon: PhosphorIcons.currencyDollar(),
                  iconColor: AppColors.green600,
                  bgColor: AppColors.green50,
                  label: 'Estimated Earnings',
                  value: '\$$estimatedEarnings MXN',
                ),
                if (pickupLocation != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  _DetailRow(
                    icon: PhosphorIcons.mapPin(),
                    iconColor: AppColors.orange500,
                    bgColor: AppColors.orange50,
                    label: 'Pickup Location',
                    value: pickupLocation,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Action buttons
          if (!_isExpired) ...[
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _isResponding ? null : () => _respondToBooking('accept'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green600,
                  disabledBackgroundColor:
                      AppColors.green600.withValues(alpha: 0.7),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.button)),
                ),
                child: _isResponding
                    ? const PawProgressIndicator(size: 20, strokeWidth: 2, color: Colors.white)
                    : Text(
                        'Accept',
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 56,
              child: OutlinedButton(
                onPressed: _isResponding ? null : () => _respondToBooking('decline'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.red500,
                  side: const BorderSide(color: AppColors.red500, width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.button)),
                ),
                child: Text(
                  'Decline',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ] else ...[
            // Expired state
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.red50,
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              child: Column(
                children: [
                  Icon(PhosphorIcons.clockCountdown(),
                      size: 48, color: AppColors.red500),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Request expired',
                    style: GoogleFonts.nunito(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.red500,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'This walk request has expired and is no longer available.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Go Back',
                          style: GoogleFonts.nunito(
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCountdownSection() {
    if (_isExpired) {
      return const SizedBox.shrink();
    }

    final urgencyColor = _timeRemaining.inMinutes < 1
        ? AppColors.red500
        : _timeRemaining.inMinutes < 2
            ? AppColors.orange500
            : AppColors.amber500;

    return Container(
      padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.sm, horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: urgencyColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: urgencyColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(PhosphorIcons.timer(), size: 20, color: urgencyColor),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'Time remaining: ${_formatCountdown(_timeRemaining)}',
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: urgencyColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: iconColor),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
