import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pawgo/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pawgo/services/analytics_service.dart';
import 'package:pawgo/services/error_handler.dart';

class WalkerBookingsScreen extends StatefulWidget {
  const WalkerBookingsScreen({super.key});

  @override
  State<WalkerBookingsScreen> createState() => _WalkerBookingsScreenState();
}

class _WalkerBookingsScreenState extends State<WalkerBookingsScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _bookings = [];
  bool _isLoading = true;
  String? _error;
  String? _walkerId;
  RealtimeChannel? _bookingChannel;
  int _selectedTab = 0; // 0=Upcoming, 1=Active, 2=Completed

  static const _upcomingStatuses = ['confirmed', 'walker_en_route'];
  static const _activeStatuses = ['walk_started'];
  static const _completedStatuses = ['walk_completed'];

  List<Map<String, dynamic>> get _filteredBookings {
    final statuses = switch (_selectedTab) {
      0 => _upcomingStatuses,
      1 => _activeStatuses,
      2 => _completedStatuses,
      _ => _upcomingStatuses,
    };
    return _bookings
        .where((b) => statuses.contains(b['status']))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _loadWalkerBookings();
  }

  @override
  void dispose() {
    _bookingChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadWalkerBookings() async {
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

      // Get walker profile for current user
      final walkerRes = await withRetry(() => _supabase
          .from('walkers')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle());

      if (walkerRes == null) {
        setState(() {
          _isLoading = false;
          _error = 'No walker profile found. You need a walker account to view this screen.';
        });
        return;
      }

      _walkerId = walkerRes['id'] as String;

      // Fetch all bookings assigned to this walker
      final bookings = await withRetry(() => _supabase
          .from('bookings')
          .select('*, dogs(name, breed), users!bookings_owner_id_fkey(full_name, avatar_url)')
          .eq('walker_id', _walkerId!)
          .inFilter('status', ['confirmed', 'walker_en_route', 'walk_started', 'walk_completed'])
          .order('scheduled_at', ascending: true));

      setState(() {
        _bookings = List<Map<String, dynamic>>.from(bookings);
        _isLoading = false;
      });

      _subscribeToBookings();
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
            : 'Failed to load bookings';
      });
    }
  }

  void _subscribeToBookings() {
    if (_walkerId == null) return;
    _bookingChannel?.unsubscribe();

    _bookingChannel = _supabase
        .channel('walker-bookings-$_walkerId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'bookings',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'walker_id',
            value: _walkerId!,
          ),
          callback: (payload) {
            final updated = payload.newRecord;
            setState(() {
              final idx = _bookings.indexWhere((b) => b['id'] == updated['id']);
              if (idx >= 0) {
                final status = updated['status'] as String?;
                // Remove cancelled bookings
                if (status == 'cancelled') {
                  _bookings.removeAt(idx);
                } else {
                  // Preserve joined data, update booking fields
                  _bookings[idx] = {
                    ..._bookings[idx],
                    ...updated,
                    'dogs': _bookings[idx]['dogs'],
                    'users': _bookings[idx]['users'],
                  };
                }
              }
            });
          },
        )
        .subscribe();
  }

  Future<void> _startWalk(String bookingId) async {
    try {
      final res = await withRetry(() => _supabase.functions.invoke(
        'start-walk',
        body: {'booking_id': bookingId},
      ));

      if (!mounted) return;
      if (res.status != 200) {
        ErrorHandler.instance.handleFunctionError(
          context,
          res,
          screen: 'walker_bookings',
          fallbackMessage: 'Failed to start walk',
        );
      } else {
        AnalyticsService.instance.walkStarted(bookingId: bookingId);
      }
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.instance.handleError(
        context,
        e,
        screen: 'walker_bookings',
        fallbackMessage: 'Failed to start walk. Please try again.',
      );
    }
  }

  Future<void> _endWalk(String bookingId) async {
    // Confirm before ending
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('End Walk?', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        content: Text('Are you sure you want to end this walk?', style: GoogleFonts.nunito()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange500),
            child: Text('End Walk', style: GoogleFonts.nunito(fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await withRetry(() => _supabase.functions.invoke(
        'end-walk',
        body: {'booking_id': bookingId},
      ));

      if (!mounted) return;
      if (res.status != 200) {
        ErrorHandler.instance.handleFunctionError(
          context,
          res,
          screen: 'walker_bookings',
          fallbackMessage: 'Failed to end walk',
        );
      } else {
        AnalyticsService.instance.walkCompleted(bookingId: bookingId);
        ErrorHandler.instance.showRecoverableError(context, 'Walk completed!');
      }
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.instance.handleError(
        context,
        e,
        screen: 'walker_bookings',
        fallbackMessage: 'Failed to end walk. Please try again.',
      );
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed':
        return AppColors.blue600;
      case 'walker_en_route':
        return AppColors.orange500;
      case 'walk_started':
        return AppColors.green600;
      default:
        return AppColors.textSecondary;
    }
  }

  Color _statusBgColor(String status) {
    switch (status) {
      case 'confirmed':
        return AppColors.blue50;
      case 'walker_en_route':
        return AppColors.orange50;
      case 'walk_started':
        return AppColors.green50;
      default:
        return AppColors.surface;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'confirmed':
        return 'Confirmed';
      case 'walker_en_route':
        return 'En Route';
      case 'walk_started':
        return 'In Progress';
      default:
        return status;
    }
  }

  String _formatDateTime(String? isoString) {
    if (isoString == null) return 'Not scheduled';
    final dt = DateTime.tryParse(isoString);
    if (dt == null) return isoString;
    final local = dt.toLocal();
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = local.hour > 12 ? local.hour - 12 : (local.hour == 0 ? 12 : local.hour);
    final amPm = local.hour >= 12 ? 'PM' : 'AM';
    final min = local.minute.toString().padLeft(2, '0');
    return '${months[local.month - 1]} ${local.day}, ${local.year} at $hour:$min $amPm';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          'My Walk Sessions',
          style: GoogleFonts.nunito(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.orange500))
          : _error != null
              ? _buildErrorState()
              : Column(
                  children: [
                    _buildFilterTabs(),
                    Expanded(
                      child: _filteredBookings.isEmpty
                          ? _buildEmptyState()
                          : RefreshIndicator(
                              onRefresh: _loadWalkerBookings,
                              color: AppColors.orange500,
                              child: ListView.separated(
                                padding: const EdgeInsets.all(24),
                                itemCount: _filteredBookings.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 16),
                                itemBuilder: (context, index) => _buildBookingCard(_filteredBookings[index]),
                              ),
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildFilterTabs() {
    final tabs = ['Upcoming', 'Active', 'Completed'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isSelected = _selectedTab == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = index),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.cacaoBrown : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    tabs[index],
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(fontSize: 16, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadWalkerBookings,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange500),
              child: Text('Retry', style: GoogleFonts.nunito(fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.directions_walk, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              _selectedTab == 2 ? 'No Completed Walks' : 'No Walks Assigned Yet',
              style: GoogleFonts.nunito(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedTab == 0
                  ? 'You don\'t have any upcoming walks right now.'
                  : _selectedTab == 1
                      ? 'No walks are currently in progress.'
                      : 'You haven\'t completed any walks yet.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(fontSize: 15, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final status = booking['status'] as String? ?? 'confirmed';
    final dog = booking['dogs'] as Map<String, dynamic>?;
    final owner = booking['users'] as Map<String, dynamic>?;
    final bookingId = booking['id'] as String;
    final scheduledAt = booking['scheduled_at'] as String?;
    final durationMinutes = booking['duration_minutes'];
    final totalPrice = booking['total_price_mxn'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Owner and status row
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.orange50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: owner?['avatar_url'] != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          owner!['avatar_url'],
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.person, color: AppColors.orange500),
                        ),
                      )
                    : const Icon(Icons.person, color: AppColors.orange500),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      owner?['full_name'] ?? 'Dog Owner',
                      style: GoogleFonts.nunito(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _statusBgColor(status),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _statusLabel(status),
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _statusColor(status),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Dog info
          if (dog != null) ...[
            _DetailRow(
              icon: Icons.pets,
              iconColor: AppColors.orange500,
              bgColor: AppColors.orange50,
              text: '${dog['name'] ?? 'Unknown'} (${dog['breed'] ?? 'Unknown breed'})',
            ),
            const SizedBox(height: 10),
          ],
          // Scheduled time
          _DetailRow(
            icon: Icons.calendar_today,
            iconColor: AppColors.blue600,
            bgColor: AppColors.blue50,
            text: _formatDateTime(scheduledAt),
          ),
          // Duration & price
          if (durationMinutes != null || totalPrice != null) ...[
            const SizedBox(height: 10),
            _DetailRow(
              icon: Icons.access_time,
              iconColor: AppColors.purple600,
              bgColor: AppColors.purple50,
              text: [
                if (durationMinutes != null) '${durationMinutes} min',
                if (totalPrice != null) '\$${(totalPrice as num).toStringAsFixed(0)} MXN',
              ].join(' · '),
            ),
          ],
          const SizedBox(height: 16),
          // Action buttons
          _buildActionButtons(bookingId, status),
        ],
      ),
    );
  }

  Widget _buildActionButtons(String bookingId, String status) {
    if (status == 'confirmed') {
      return Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => _startWalk(bookingId),
                icon: const Icon(Icons.play_arrow, color: Colors.white),
                label: Text(
                  'Start Walk',
                  style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green600,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 48,
            width: 48,
            child: IconButton(
              onPressed: () {
                Navigator.pushNamed(context, '/chat', arguments: {
                  'booking_id': bookingId,
                  'other_party_name': _bookings.firstWhere((b) => b['id'] == bookingId)['users']?['full_name'] ?? 'Owner',
                });
              },
              icon: const Icon(Icons.chat_bubble_outline, color: AppColors.orange500),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.orange50,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      );
    } else if (status == 'walk_started') {
      return Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => _endWalk(bookingId),
                icon: const Icon(Icons.stop, color: Colors.white),
                label: Text(
                  'End Walk',
                  style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 48,
            width: 48,
            child: IconButton(
              onPressed: () {
                Navigator.pushNamed(context, '/active-walk', arguments: {
                  'booking_id': bookingId,
                });
              },
              icon: const Icon(Icons.map, color: AppColors.blue600),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.blue50,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 48,
            width: 48,
            child: IconButton(
              onPressed: () {
                Navigator.pushNamed(context, '/chat', arguments: {
                  'booking_id': bookingId,
                  'other_party_name': _bookings.firstWhere((b) => b['id'] == bookingId)['users']?['full_name'] ?? 'Owner',
                });
              },
              icon: const Icon(Icons.chat_bubble_outline, color: AppColors.orange500),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.orange50,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      );
    } else {
      // walker_en_route or other transitional states
      return SizedBox(
        height: 48,
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: null,
          icon: const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textSecondary),
          ),
          label: Text(
            'Updating...',
            style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );
    }
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String text;

  const _DetailRow({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.nunito(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
