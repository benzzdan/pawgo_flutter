import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pawgo/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  String _selectedTab = 'upcoming';
  List<Map<String, dynamic>> _bookings = [];
  bool _isLoading = true;
  String? _error;
  RealtimeChannel? _channel;

  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _fetchBookings();
    _subscribeToUpdates();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _fetchBookings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userId = _supabase.auth.currentUser!.id;
      final data = await _supabase
          .from('bookings')
          .select(
              '*, walkers(id, user_id, users(full_name, avatar_url)), dogs(name, breed, photo_url)')
          .eq('owner_id', userId)
          .order('scheduled_at', ascending: false);

      if (!mounted) return;
      setState(() {
        _bookings = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _subscribeToUpdates() {
    final userId = _supabase.auth.currentUser!.id;
    _channel = _supabase.channel('bookings_owner_$userId');
    _channel!.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'bookings',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'owner_id',
        value: userId,
      ),
      callback: (payload) {
        final updated = payload.newRecord;
        if (!mounted) return;
        setState(() {
          final idx =
              _bookings.indexWhere((b) => b['id'] == updated['id']);
          if (idx != -1) {
            // Preserve joined data, update scalar fields
            final existing = _bookings[idx];
            _bookings[idx] = {
              ...existing,
              ...updated,
              'walkers': existing['walkers'],
              'dogs': existing['dogs'],
            };
          }
        });
      },
    );
    _channel!.subscribe();
  }

  List<Map<String, dynamic>> get _filteredBookings {
    switch (_selectedTab) {
      case 'upcoming':
        return _bookings.where((b) {
          final status = b['status'] as String;
          return [
            'pending',
            'confirmed',
            'walker_en_route',
            'walk_started'
          ].contains(status);
        }).toList();
      case 'past':
        return _bookings
            .where((b) => b['status'] == 'walk_completed')
            .toList();
      case 'cancelled':
        return _bookings.where((b) {
          final status = b['status'] as String;
          return ['cancelled', 'disputed'].contains(status);
        }).toList();
      default:
        return _bookings;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My Bookings',
                style: GoogleFonts.nunito(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Manage your upcoming walks',
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        // Filter Tabs
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              _TabChip(
                label: 'Upcoming',
                isSelected: _selectedTab == 'upcoming',
                onTap: () => setState(() => _selectedTab = 'upcoming'),
              ),
              const SizedBox(width: 8),
              _TabChip(
                label: 'Past',
                isSelected: _selectedTab == 'past',
                onTap: () => setState(() => _selectedTab = 'past'),
              ),
              const SizedBox(width: 8),
              _TabChip(
                label: 'Cancelled',
                isSelected: _selectedTab == 'cancelled',
                onTap: () => setState(() => _selectedTab = 'cancelled'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Content
        Expanded(child: _buildContent()),
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: AppColors.red500),
              const SizedBox(height: 12),
              Text(
                'Failed to load bookings',
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _fetchBookings,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.orange500,
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

    final filtered = _filteredBookings;

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('📋', style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              _selectedTab == 'upcoming'
                  ? 'No upcoming bookings'
                  : _selectedTab == 'past'
                      ? 'No past walks yet'
                      : 'No cancelled bookings',
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchBookings,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          return _BookingCard(
            booking: filtered[index],
            onTap: () => _openBookingDetail(filtered[index]),
          );
        },
      ),
    );
  }

  void _openBookingDetail(Map<String, dynamic> booking) {
    final status = booking['status'] as String;
    final walkerData = booking['walkers'] as Map<String, dynamic>?;
    final walkerUser = walkerData?['users'] as Map<String, dynamic>?;
    final dogData = booking['dogs'] as Map<String, dynamic>?;
    final walkerName = walkerUser?['full_name'] ?? 'Walker';
    final dogName = dogData?['name'] ?? 'Dog';

    if (status == 'walk_started') {
      // Navigate to active walk / GPS tracking
      Navigator.pushNamed(context, '/active-walk', arguments: {
        'booking_id': booking['id'],
        'walker_name': walkerName,
        'dog_name': dogName,
      });
    } else if (status == 'walk_completed') {
      // Show walk summary dialog
      _showBookingDetail(booking);
    } else {
      // Show booking detail dialog for other statuses
      _showBookingDetail(booking);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchClaims(String bookingId) async {
    try {
      final data = await _supabase
          .from('insurance_claims')
          .select('id, claim_type, status, amount_mxn')
          .eq('booking_id', bookingId);
      return List<Map<String, dynamic>>.from(data);
    } catch (_) {
      return [];
    }
  }

  void _showBookingDetail(Map<String, dynamic> booking) {
    final walkerData = booking['walkers'] as Map<String, dynamic>?;
    final walkerUser = walkerData?['users'] as Map<String, dynamic>?;
    final dogData = booking['dogs'] as Map<String, dynamic>?;
    final walkerName = walkerUser?['full_name'] ?? 'Unknown';
    final dogName = dogData?['name'] ?? 'Unknown';
    final dogBreed = dogData?['breed'] ?? '';
    final status = booking['status'] as String;
    final scheduledAt = booking['scheduled_at'] != null
        ? DateTime.tryParse(booking['scheduled_at'])
        : null;
    final duration = booking['duration_minutes'] as int?;
    final price = (booking['total_price_mxn'] as num?)?.toDouble();
    final startedAt = booking['started_at'] != null
        ? DateTime.tryParse(booking['started_at'])
        : null;
    final completedAt = booking['completed_at'] != null
        ? DateTime.tryParse(booking['completed_at'])
        : null;

    // Pre-fetch claims for completed/disputed bookings
    final claimsFuture = (status == 'walk_completed' || status == 'disputed')
        ? _fetchClaims(booking['id'])
        : Future.value(<Map<String, dynamic>>[]);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        expand: false,
        builder: (ctx, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.gray300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Status badge
              _StatusBadge(status: status),
              const SizedBox(height: 16),
              // Walker
              Text('Walker',
                  style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Text(walkerName,
                  style: GoogleFonts.nunito(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 16),
              // Dog
              Text('Dog',
                  style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Text('$dogName${dogBreed.isNotEmpty ? ' ($dogBreed)' : ''}',
                  style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 16),
              // Scheduled time
              if (scheduledAt != null) ...[
                _DetailRow(
                  icon: Icons.calendar_today,
                  iconColor: AppColors.blue600,
                  bgColor: AppColors.blue50,
                  text: DateFormat('MMM d, yyyy').format(scheduledAt),
                ),
                const SizedBox(height: 10),
                _DetailRow(
                  icon: Icons.access_time,
                  iconColor: AppColors.purple600,
                  bgColor: AppColors.purple50,
                  text: DateFormat('h:mm a').format(scheduledAt),
                ),
                const SizedBox(height: 10),
              ],
              // Duration
              if (duration != null)
                _DetailRow(
                  icon: Icons.timer,
                  iconColor: AppColors.green600,
                  bgColor: AppColors.green50,
                  text: '$duration min',
                ),
              if (duration != null) const SizedBox(height: 10),
              // Started / Completed times
              if (startedAt != null) ...[
                _DetailRow(
                  icon: Icons.play_arrow,
                  iconColor: AppColors.green600,
                  bgColor: AppColors.green50,
                  text:
                      'Started: ${DateFormat('h:mm a').format(startedAt.toLocal())}',
                ),
                const SizedBox(height: 10),
              ],
              if (completedAt != null) ...[
                _DetailRow(
                  icon: Icons.check_circle,
                  iconColor: AppColors.green600,
                  bgColor: AppColors.green50,
                  text:
                      'Completed: ${DateFormat('h:mm a').format(completedAt.toLocal())}',
                ),
                const SizedBox(height: 10),
              ],
              // Price
              if (price != null) ...[
                _DetailRow(
                  icon: Icons.attach_money,
                  iconColor: AppColors.orange500,
                  bgColor: AppColors.orange50,
                  text: '\$${price.toStringAsFixed(2)} MXN',
                ),
                const SizedBox(height: 16),
              ],
              // Insurance claims section
              if (status == 'walk_completed' || status == 'disputed')
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: claimsFuture,
                  builder: (context, snapshot) {
                    final claims = snapshot.data;
                    if (claims == null || claims.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        Text('Insurance Claims',
                            style: GoogleFonts.nunito(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary)),
                        const SizedBox(height: 8),
                        ...claims.map((claim) {
                          final claimType = claim['claim_type'] as String? ?? '';
                          final claimStatus = claim['status'] as String? ?? '';
                          final amount = (claim['amount_mxn'] as num?)?.toDouble();
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _claimStatusBg(claimStatus),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.shield,
                                      size: 18,
                                      color: _claimStatusColor(claimStatus)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '${claimType[0].toUpperCase()}${claimType.substring(1)}${amount != null ? ' — \$${amount.toStringAsFixed(2)} MXN' : ''}',
                                      style: GoogleFonts.nunito(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: _claimStatusColor(claimStatus)
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      claimStatus.toUpperCase(),
                                      style: GoogleFonts.nunito(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color:
                                              _claimStatusColor(claimStatus)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 6),
                      ],
                    );
                  },
                ),
              // Action buttons based on status
              if (status == 'walk_started' || status == 'confirmed') ...[
                Row(
                  children: [
                    if (status == 'walk_started')
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.pop(ctx);
                            Navigator.pushNamed(context, '/active-walk',
                                arguments: {
                                  'booking_id': booking['id'],
                                  'walker_name': walkerName,
                                  'dog_name': dogName,
                                });
                          },
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.blue600,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text('Track Walk',
                                  style: GoogleFonts.nunito(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white)),
                            ),
                          ),
                        ),
                      ),
                    if (status == 'walk_started') const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pop(ctx);
                          Navigator.pushNamed(context, '/chat', arguments: {
                            'booking_id': booking['id'],
                            'other_party_name': walkerName,
                          });
                        },
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                AppColors.orange500,
                                AppColors.orange400
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text('Chat',
                                style: GoogleFonts.nunito(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              // Insurance claim button for completed or disputed walks
              if (status == 'walk_completed' || status == 'disputed') ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.pushNamed(context, '/insurance-claim',
                          arguments: {
                            'booking_id': booking['id'],
                          });
                    },
                    icon: const Icon(Icons.shield, size: 18),
                    label: Text('File Insurance Claim',
                        style: GoogleFonts.nunito(
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.orange500,
                      side: const BorderSide(
                          color: AppColors.orange500, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Color _claimStatusColor(String status) {
  switch (status) {
    case 'open':
      return AppColors.blue600;
    case 'reviewing':
      return AppColors.amber500;
    case 'approved':
      return AppColors.green600;
    case 'rejected':
      return AppColors.red500;
    default:
      return AppColors.textSecondary;
  }
}

Color _claimStatusBg(String status) {
  switch (status) {
    case 'open':
      return AppColors.blue50;
    case 'reviewing':
      return AppColors.amber50;
    case 'approved':
      return AppColors.green50;
    case 'rejected':
      return AppColors.red50;
    default:
      return AppColors.gray100;
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.orange500 : AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? null
              : Border.all(color: AppColors.border, width: 2),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.orange500.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final config = _statusConfig(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: config.bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        config.label,
        style: GoogleFonts.nunito(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: config.textColor,
        ),
      ),
    );
  }
}

class _StatusConfig {
  final String label;
  final Color bgColor;
  final Color textColor;
  const _StatusConfig(this.label, this.bgColor, this.textColor);
}

_StatusConfig _statusConfig(String status) {
  switch (status) {
    case 'pending':
      return _StatusConfig('Pending', AppColors.amber50, AppColors.yellow800);
    case 'confirmed':
      return _StatusConfig('Confirmed', AppColors.green50, AppColors.green600);
    case 'walker_en_route':
      return _StatusConfig('En Route', AppColors.blue50, AppColors.blue600);
    case 'walk_started':
      return _StatusConfig(
          'Walk In Progress', AppColors.blue50, AppColors.blue700);
    case 'walk_completed':
      return _StatusConfig('Completed', AppColors.green50, AppColors.green700);
    case 'cancelled':
      return _StatusConfig('Cancelled', AppColors.red50, AppColors.red500);
    case 'disputed':
      return _StatusConfig(
          'Disputed', AppColors.purple50, AppColors.purple600);
    default:
      return _StatusConfig(
          status, AppColors.gray100, AppColors.textSecondary);
  }
}

class _BookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final VoidCallback onTap;

  const _BookingCard({required this.booking, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final walkerData = booking['walkers'] as Map<String, dynamic>?;
    final walkerUser = walkerData?['users'] as Map<String, dynamic>?;
    final dogData = booking['dogs'] as Map<String, dynamic>?;
    final walkerName = walkerUser?['full_name'] ?? 'Unknown Walker';
    final dogName = dogData?['name'] ?? 'Unknown Dog';
    final status = booking['status'] as String;
    final scheduledAt = booking['scheduled_at'] != null
        ? DateTime.tryParse(booking['scheduled_at'])
        : null;
    final duration = booking['duration_minutes'] as int?;
    final price = (booking['total_price_mxn'] as num?)?.toDouble();

    return GestureDetector(
      onTap: onTap,
      child: Container(
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
          children: [
            // Walker Info + Status
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.orange400, AppColors.orange500],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: walkerUser?['avatar_url'] != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            walkerUser!['avatar_url'],
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(
                              child: Text(
                                walkerName.isNotEmpty
                                    ? walkerName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                    fontSize: 24, color: Colors.white),
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            walkerName.isNotEmpty
                                ? walkerName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                fontSize: 24, color: Colors.white),
                          ),
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        walkerName,
                        style: GoogleFonts.nunito(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _StatusBadge(status: status),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    color: AppColors.textTertiary, size: 24),
              ],
            ),
            const SizedBox(height: 16),
            // Dog name
            _DetailRow(
              icon: Icons.pets,
              iconColor: AppColors.orange500,
              bgColor: AppColors.orange50,
              text: dogName,
            ),
            const SizedBox(height: 10),
            // Date
            if (scheduledAt != null) ...[
              _DetailRow(
                icon: Icons.calendar_today,
                iconColor: AppColors.blue600,
                bgColor: AppColors.blue50,
                text: DateFormat('MMM d, yyyy').format(scheduledAt),
              ),
              const SizedBox(height: 10),
              _DetailRow(
                icon: Icons.access_time,
                iconColor: AppColors.purple600,
                bgColor: AppColors.purple50,
                text:
                    '${DateFormat('h:mm a').format(scheduledAt)}${duration != null ? ' · $duration min' : ''}',
              ),
            ],
            // Price
            if (price != null) ...[
              const SizedBox(height: 10),
              _DetailRow(
                icon: Icons.attach_money,
                iconColor: AppColors.green600,
                bgColor: AppColors.green50,
                text: '\$${price.toStringAsFixed(2)} MXN',
              ),
            ],
          ],
        ),
      ),
    );
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
