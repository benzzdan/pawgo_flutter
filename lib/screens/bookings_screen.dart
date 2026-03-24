import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pawgo/models/mock_data.dart';
import 'package:pawgo/theme/app_theme.dart';
import 'package:pawgo/widgets/pawgo_button.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  String _selectedTab = 'upcoming';

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

    // Subtle floating idle animation (2px, 3s loop) unless reduce-motion
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

    // FadeIn + scaleUp entrance animation unless reduce-motion
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

  @override
  Widget build(BuildContext context) {
    final bookings = MockData.bookings;

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
        // Bookings List or Empty State
        Expanded(
          child: bookings.isEmpty
              ? _buildEmptyState(context)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  itemCount: bookings.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final booking = bookings[index];
                    return _BookingCard(booking: booking);
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
                child: Center(
                  child:
                      Text(booking.image, style: const TextStyle(fontSize: 24)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.walker,
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
                        color: AppColors.green50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Confirmed',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.green600,
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
            text: booking.date,
          ),
          const SizedBox(height: 10),
          _DetailRow(
            icon: Icons.access_time,
            iconColor: AppColors.purple600,
            bgColor: AppColors.purple50,
            text: '${booking.time} \u{2022} ${booking.duration}',
          ),
          const SizedBox(height: 10),
          _DetailRow(
            icon: Icons.location_on,
            iconColor: AppColors.orange500,
            bgColor: AppColors.orange50,
            text: booking.location,
          ),
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
