import 'package:flutter/material.dart';
import 'package:pawgo/theme/app_theme.dart';
import 'package:pawgo/models/mock_data.dart';
import 'package:pawgo/services/walker_service.dart';
import 'package:google_fonts/google_fonts.dart';

class WalkerProfileScreen extends StatefulWidget {
  const WalkerProfileScreen({super.key});

  @override
  State<WalkerProfileScreen> createState() => _WalkerProfileScreenState();
}

class _WalkerProfileScreenState extends State<WalkerProfileScreen> {
  String? _selectedDate;
  String? _selectedTime;
  Walker? _walker;
  bool _isLoading = true;
  String? _error;

  final availableDates = [
    {'date': 'Today', 'day': 'Mar 6', 'available': true},
    {'date': 'Tomorrow', 'day': 'Mar 7', 'available': true},
    {'date': 'Fri', 'day': 'Mar 8', 'available': true},
    {'date': 'Sat', 'day': 'Mar 9', 'available': false},
    {'date': 'Sun', 'day': 'Mar 10', 'available': true},
  ];

  final availableTimes = [
    {'time': '9:00 AM', 'available': true},
    {'time': '11:00 AM', 'available': true},
    {'time': '2:00 PM', 'available': false},
    {'time': '4:00 PM', 'available': true},
    {'time': '6:00 PM', 'available': true},
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isLoading && _walker == null && _error == null) {
      _loadWalker();
    }
  }

  Future<void> _loadWalker() async {
    final walkerId = ModalRoute.of(context)?.settings.arguments as String?;
    if (walkerId == null) {
      setState(() {
        _error = 'Walker not found.';
        _isLoading = false;
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final walker = await WalkerService.fetchWalkerById(walkerId);
      if (mounted) {
        setState(() {
          _walker = walker;
          _isLoading = false;
          if (walker == null) _error = 'Walker not found.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Unable to load walker profile. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              color: AppColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                      child: const Icon(Icons.arrow_back,
                          size: 20, color: AppColors.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Walker Profile',
                    style: GoogleFonts.nunito(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.orange500),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: AppColors.gray400),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _loadWalker,
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

    final walker = _walker!;
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildProfileHeader(walker),
          const SizedBox(height: 12),
          _buildVerificationSection(walker),
          const SizedBox(height: 12),
          _buildAboutSection(walker),
          const SizedBox(height: 12),
          _buildQuickBookSection(walker),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(Walker walker) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.orange400, AppColors.orange500],
                      ),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: walker.avatarUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: Image.network(
                              walker.avatarUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Center(
                                child: Text('🚶',
                                    style: TextStyle(fontSize: 40)),
                              ),
                            ),
                          )
                        : const Center(
                            child:
                                Text('🚶', style: TextStyle(fontSize: 40)),
                          ),
                  ),
                  if (walker.backgroundChecked)
                    Positioned(
                      bottom: -4,
                      right: -4,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.blue500,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.shield,
                            color: Colors.white, size: 14),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      walker.name,
                      style: GoogleFonts.nunito(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star,
                            size: 16, color: AppColors.orange500),
                        const SizedBox(width: 4),
                        Text(
                          walker.displayRating,
                          style: GoogleFonts.nunito(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          ' (${walker.totalWalks} walks)',
                          style: GoogleFonts.nunito(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: walker.isEnabled
                            ? AppColors.green100
                            : AppColors.gray100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: walker.isEnabled
                                  ? AppColors.green500
                                  : AppColors.gray400,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            walker.isEnabled ? 'Available' : 'Unavailable',
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: walker.isEnabled
                                  ? AppColors.green700
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Price
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    walker.displayPrice,
                    style: GoogleFonts.nunito(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'per walk',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Quick Actions
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.orange500,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.orange500.withValues(alpha: 0.3),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.calendar_today,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Book Now',
                        style: GoogleFonts.nunito(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.green50,
                  borderRadius: BorderRadius.circular(16),
                ),
                child:
                    const Icon(Icons.phone, size: 20, color: AppColors.green600),
              ),
              const SizedBox(width: 8),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.blue50,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.chat_bubble,
                    size: 20, color: AppColors.blue600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationSection(Walker walker) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Verification & Trust',
            style: GoogleFonts.nunito(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (walker.backgroundChecked)
            _VerificationBadge(
              icon: Icons.shield,
              iconColor: Colors.white,
              bgColor: AppColors.green500,
              gradientColors: const [AppColors.green50, Color(0xFFECFDF5)],
              title: 'Background Check Verified',
              subtitle: 'Cleared',
              checkColor: AppColors.green600,
            ),
          const SizedBox(height: 16),
          // Stats
          Row(
            children: [
              _StatBox(value: '${walker.totalWalks}', label: 'Total Walks'),
              const SizedBox(width: 12),
              _StatBox(value: walker.displayExperience, label: 'Experience'),
              const SizedBox(width: 12),
              _StatBox(
                  value: walker.displayRating, label: 'Rating'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection(Walker walker) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About',
            style: GoogleFonts.nunito(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            walker.bio ?? 'No bio provided.',
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF666666),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickBookSection(Walker walker) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Book',
            style: GoogleFonts.nunito(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          // Date Selection
          Text(
            'Select Date',
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: availableDates.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final d = availableDates[index];
                final isAvailable = d['available'] as bool;
                final isSelected = _selectedDate == d['day'];
                return GestureDetector(
                  onTap: isAvailable
                      ? () => setState(() => _selectedDate = d['day'] as String)
                      : null,
                  child: Container(
                    width: 70,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.orange500
                          : isAvailable
                              ? AppColors.surface
                              : AppColors.gray100,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color:
                                    AppColors.orange500.withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          d['date'] as String,
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? Colors.white
                                : isAvailable
                                    ? AppColors.textPrimary
                                    : AppColors.gray400,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          d['day'] as String,
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: isSelected
                                ? Colors.white
                                : isAvailable
                                    ? AppColors.textPrimary
                                    : AppColors.gray400,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          // Time Selection
          Text(
            'Select Time',
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 2.5,
            children: availableTimes.map((t) {
              final isAvailable = t['available'] as bool;
              final isSelected = _selectedTime == t['time'];
              return GestureDetector(
                onTap: isAvailable
                    ? () =>
                        setState(() => _selectedTime = t['time'] as String)
                    : null,
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.orange500
                        : isAvailable
                            ? AppColors.surface
                            : AppColors.gray100,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color:
                                  AppColors.orange500.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      t['time'] as String,
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? Colors.white
                            : isAvailable
                                ? AppColors.textPrimary
                                : AppColors.gray400,
                        decoration: !isAvailable
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          // Book Button
          GestureDetector(
            onTap: (_selectedDate != null && _selectedTime != null)
                ? () {
                    // Booking action
                  }
                : null,
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: (_selectedDate != null && _selectedTime != null)
                    ? AppColors.orange500
                    : const Color(0xFFE5E5E5),
                borderRadius: BorderRadius.circular(16),
                boxShadow: (_selectedDate != null && _selectedTime != null)
                    ? [
                        BoxShadow(
                          color: AppColors.orange500.withValues(alpha: 0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  (_selectedDate != null && _selectedTime != null)
                      ? 'Confirm Booking - ${walker.displayPrice}'
                      : 'Select Date & Time',
                  style: GoogleFonts.nunito(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: (_selectedDate != null && _selectedTime != null)
                        ? Colors.white
                        : AppColors.gray400,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerificationBadge extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final List<Color> gradientColors;
  final String title;
  final String subtitle;
  final Color checkColor;

  const _VerificationBadge({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.gradientColors,
    required this.title,
    required this.subtitle,
    required this.checkColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradientColors),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF666666),
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.check, color: checkColor, size: 20),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String value;
  final String label;

  const _StatBox({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.nunito(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
