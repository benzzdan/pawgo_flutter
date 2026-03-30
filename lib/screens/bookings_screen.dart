import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pawgo/models/mock_data.dart';
import 'package:pawgo/services/booking_service.dart';
import 'package:pawgo/theme/app_theme.dart';
import 'package:pawgo/widgets/pawgo_button.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  String _selectedTab = 'upcoming';
  late Future<List<Booking>> _bookingsFuture;

  @override
  void initState() {
    super.initState();
    _bookingsFuture = BookingService.fetchBookings();
  }

  void _retry() {
    setState(() {
      _bookingsFuture = BookingService.fetchBookings();
    });
  }

  List<Booking> _filterBookings(List<Booking> bookings) {
    switch (_selectedTab) {
      case 'upcoming':
        return bookings.where((b) => b.isUpcoming).toList();
      case 'past':
        return bookings.where((b) => b.isPast).toList();
      case 'cancelled':
        return bookings.where((b) => b.isCancelled).toList();
      default:
        return bookings;
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).accessibleNavigation;

    Widget illustration = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.asset(
        'assets/illustrations/corgi_sitting.png',
        width: 150,
        fit: BoxFit.contain,
      ),
    );

    if (!reduceMotion) {
      illustration = illustration
          .animate(onPlay: (controller) => controller.repeat(reverse: true))
          .moveY(
              begin: 0, end: -2, duration: 3000.ms, curve: Curves.easeInOut);
    }

    Widget content = Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            illustration,
            const SizedBox(height: 24),
            Text(
              'No walks planned',
              style: GoogleFonts.nunito(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Book a walk and your pup will thank you',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );

    if (!reduceMotion) {
      content = content
          .animate()
          .fadeIn(duration: 400.ms, curve: Curves.easeOut)
          .scale(
            begin: const Offset(0.95, 0.95),
            end: const Offset(1.0, 1.0),
            duration: 400.ms,
            curve: Curves.easeOut,
          );
    }

    return content;
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              'Could not load bookings',
              style: GoogleFonts.nunito(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please check your connection and try again.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 140,
              height: 44,
              child: PawgoButton(
                label: 'Retry',
                variant: PawgoButtonVariant.primary,
                onPressed: _retry,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(),
    );
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
        // Bookings List, Loading, Error, or Empty State
        Expanded(
          child: FutureBuilder<List<Booking>>(
            future: _bookingsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildLoadingState();
              }
              if (snapshot.hasError) {
                return _buildErrorState(snapshot.error!);
              }
              final allBookings = snapshot.data ?? [];
              final filtered = _filterBookings(allBookings);
              if (filtered.isEmpty) {
                return _buildEmptyState(context);
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final booking = filtered[index];
                  return _BookingCard(booking: booking);
                },
              );
            },
          ),
        ),
      ],
    );
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

class _BookingCard extends StatelessWidget {
  final Booking booking;

  const _BookingCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');
    final dateStr = dateFormat.format(booking.scheduledAt.toLocal());
    final timeStr = timeFormat.format(booking.scheduledAt.toLocal());
    final durationStr = booking.durationMinutes != null
        ? '${booking.durationMinutes} min'
        : '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          // Walker Info
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
                child: booking.walkerAvatarUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          booking.walkerAvatarUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Text(
                              booking.walkerName.isNotEmpty
                                  ? booking.walkerName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                  fontSize: 24, color: Colors.white),
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          booking.walkerName.isNotEmpty
                              ? booking.walkerName[0].toUpperCase()
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
                      booking.walkerName,
                      style: GoogleFonts.nunito(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: booking.statusBgColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        booking.displayStatus,
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: booking.statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Details
          _DetailRow(
            icon: Icons.calendar_today,
            iconColor: AppColors.blue600,
            bgColor: AppColors.blue50,
            text: dateStr,
          ),
          const SizedBox(height: 10),
          _DetailRow(
            icon: Icons.access_time,
            iconColor: AppColors.purple600,
            bgColor: AppColors.purple50,
            text: durationStr.isNotEmpty
                ? '$timeStr \u{2022} $durationStr'
                : timeStr,
          ),
          if (booking.dogName.isNotEmpty) ...[
            const SizedBox(height: 10),
            _DetailRow(
              icon: Icons.pets,
              iconColor: AppColors.orange500,
              bgColor: AppColors.orange50,
              text: booking.dogName,
            ),
          ],
          if (booking.totalPriceMxn > 0) ...[
            const SizedBox(height: 10),
            _DetailRow(
              icon: Icons.attach_money,
              iconColor: AppColors.green600,
              bgColor: AppColors.green50,
              text: booking.displayPrice,
            ),
          ],
          if (booking.isUpcoming) ...[
            const SizedBox(height: 16),
            // Buttons
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: PawgoButton(
                      label: 'Cancel',
                      variant: PawgoButtonVariant.secondary,
                      onPressed: () {},
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: PawgoButton(
                      label: 'Reschedule',
                      variant: PawgoButtonVariant.primary,
                      onPressed: () {},
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
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
        Text(
          text,
          style: GoogleFonts.nunito(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
